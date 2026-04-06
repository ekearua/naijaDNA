from datetime import datetime, timedelta
from typing import Dict

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.text import plain_text_excerpt
from app.db.models import (
    CategoryRecord,
    FeedEventRecord,
    NewsArticleRecord,
    UserHiddenItemRecord,
    UserInterestProfileRecord,
    UserRecord,
    UserTopicFollowRecord,
)
from app.integrations.news_sources.image_extraction import extract_first_image_from_html
from app.schemas.news import NewsArticle
from app.schemas.personalization import (
    FeedEventRequest,
    FeedEventResponse,
    FeedFeedbackRequest,
    FeedFeedbackResponse,
    FollowedTopic,
    PersonalizedFeedResponse,
    PersonalizedInterest,
    PersonalizationProfileResponse,
    SetInterestsRequest,
)


class MissingUserContextError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class CategoryNotFoundError(Exception):
    pass


class InvalidEventPayloadError(Exception):
    pass


class InvalidFeedbackPayloadError(Exception):
    pass


class PersonalizationService:
    """Hybrid feed personalization for explicit + behavioral preference signals."""

    _EVENT_IMPLICIT_DELTA: dict[str, float] = {
        "impression": 0.02,
        "click": 0.20,
        "save": 0.60,
        "share": 0.50,
        "discuss": 0.70,
        "hide": -0.80,
        "report": -1.00,
    }
    _TREND_EVENT_TYPES = ("click", "save", "share", "discuss", "dwell")
    _MAX_IMPLICIT_WEIGHT = 3.0
    _MIN_IMPLICIT_WEIGHT = -3.0
    _CATEGORY_ALIASES = {
        "breaking": "breaking-news",
        "breaking news": "breaking-news",
        "tech": "technology",
    }

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def get_profile(self, *, user_id: str) -> PersonalizationProfileResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            return await self._build_profile(session, normalized_user_id)

    async def set_interests(
        self,
        *,
        user_id: str,
        payload: SetInterestsRequest,
    ) -> PersonalizationProfileResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        now = datetime.utcnow()

        desired_interests: dict[str, float] = {}
        for item in payload.interests:
            category_id = self._normalize_category_id(item.category_id)
            desired_interests[category_id] = float(item.weight)

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            if desired_interests:
                await self._assert_categories_exist(session, list(desired_interests.keys()))

            existing_result = await session.execute(
                select(UserInterestProfileRecord).where(
                    UserInterestProfileRecord.user_id == normalized_user_id
                )
            )
            existing_by_category = {
                row.category_id: row for row in existing_result.scalars().all()
            }

            if payload.replace_existing:
                for category_id, row in existing_by_category.items():
                    if category_id not in desired_interests:
                        await session.delete(row)

            for category_id, explicit_weight in desired_interests.items():
                row = existing_by_category.get(category_id)
                if row is None:
                    session.add(
                        UserInterestProfileRecord(
                            user_id=normalized_user_id,
                            category_id=category_id,
                            explicit_weight=explicit_weight,
                            implicit_weight=0.0,
                            created_at=now,
                            updated_at=now,
                        )
                    )
                else:
                    row.explicit_weight = explicit_weight
                    row.updated_at = now

            if payload.topics is not None:
                await self._replace_followed_topics(
                    session,
                    user_id=normalized_user_id,
                    topics=payload.topics,
                    now=now,
                )

            await session.commit()
            return await self._build_profile(session, normalized_user_id)

    async def record_feed_event(
        self,
        *,
        user_id: str,
        payload: FeedEventRequest,
    ) -> FeedEventResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        if not payload.article_id:
            raise InvalidEventPayloadError("article_id is required for feed events.")

        normalized_article_id = payload.article_id.strip()
        idempotency_key = (payload.idempotency_key or "").strip() or None
        now = datetime.utcnow()

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)

            if idempotency_key:
                existing_event_result = await session.execute(
                    select(FeedEventRecord).where(
                        FeedEventRecord.idempotency_key == idempotency_key
                    )
                )
                existing_event = existing_event_result.scalar_one_or_none()
                if existing_event is not None:
                    return FeedEventResponse(
                        status="idempotent",
                        event_type=payload.event_type,
                    )

            article_result = await session.execute(
                select(NewsArticleRecord).where(NewsArticleRecord.id == normalized_article_id)
            )
            article = article_result.scalar_one_or_none()
            if article is None:
                raise InvalidEventPayloadError(
                    f"Article '{normalized_article_id}' does not exist."
                )

            category_id = await self._resolve_category_id_from_name(
                session,
                article.category,
            )

            session.add(
                FeedEventRecord(
                    user_id=normalized_user_id,
                    article_id=article.id,
                    category_id=category_id,
                    source=article.source,
                    event_type=payload.event_type,
                    dwell_ms=payload.dwell_ms,
                    idempotency_key=idempotency_key,
                    created_at=now,
                )
            )

            updated_interest: PersonalizedInterest | None = None
            implicit_delta = self._implicit_delta(
                event_type=payload.event_type,
                dwell_ms=payload.dwell_ms,
            )
            if category_id is not None and implicit_delta != 0:
                profile_row = await self._upsert_interest_delta(
                    session,
                    user_id=normalized_user_id,
                    category_id=category_id,
                    delta=implicit_delta,
                    now=now,
                )
                category = await session.get(CategoryRecord, category_id)
                if category is not None:
                    updated_interest = self._to_interest_schema(profile_row, category)

            if payload.event_type == "hide":
                await self._ensure_hidden_item(
                    session,
                    user_id=normalized_user_id,
                    article_id=article.id,
                    source=None,
                    category_id=None,
                    now=now,
                )

            await session.commit()
            return FeedEventResponse(
                status="recorded",
                event_type=payload.event_type,
                updated_interest=updated_interest,
            )

    async def apply_feedback(
        self,
        *,
        user_id: str,
        payload: FeedFeedbackRequest,
    ) -> FeedFeedbackResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        now = datetime.utcnow()

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            action = payload.action

            if action in ("more_like_this", "less_like_this"):
                category_id = payload.category_id
                source = payload.source

                if payload.article_id:
                    article_result = await session.execute(
                        select(NewsArticleRecord).where(
                            NewsArticleRecord.id == payload.article_id.strip()
                        )
                    )
                    article = article_result.scalar_one_or_none()
                    if article is None:
                        raise InvalidFeedbackPayloadError(
                            f"Article '{payload.article_id}' does not exist."
                        )
                    category_id = category_id or await self._resolve_category_id_from_name(
                        session,
                        article.category,
                    )
                    source = source or article.source

                normalized_category_id = (
                    self._normalize_category_id(category_id) if category_id else None
                )
                if normalized_category_id is None:
                    raise InvalidFeedbackPayloadError(
                        "more_like_this/less_like_this requires article_id or category_id."
                    )
                await self._assert_categories_exist(session, [normalized_category_id])

                delta = 0.80 if action == "more_like_this" else -0.80
                await self._upsert_interest_delta(
                    session,
                    user_id=normalized_user_id,
                    category_id=normalized_category_id,
                    delta=delta,
                    now=now,
                )
                if action == "less_like_this" and source:
                    await self._ensure_hidden_item(
                        session,
                        user_id=normalized_user_id,
                        article_id=None,
                        source=source,
                        category_id=None,
                        now=now,
                    )

            elif action == "hide_article":
                if not payload.article_id:
                    raise InvalidFeedbackPayloadError("hide_article requires article_id.")
                await self._ensure_hidden_item(
                    session,
                    user_id=normalized_user_id,
                    article_id=payload.article_id.strip(),
                    source=None,
                    category_id=None,
                    now=now,
                )

            elif action == "hide_source":
                source = (payload.source or "").strip()
                if not source and payload.article_id:
                    article_result = await session.execute(
                        select(NewsArticleRecord).where(
                            NewsArticleRecord.id == payload.article_id.strip()
                        )
                    )
                    article = article_result.scalar_one_or_none()
                    source = article.source if article else ""
                if not source:
                    raise InvalidFeedbackPayloadError(
                        "hide_source requires source or article_id."
                    )
                await self._ensure_hidden_item(
                    session,
                    user_id=normalized_user_id,
                    article_id=None,
                    source=source,
                    category_id=None,
                    now=now,
                )

            elif action == "hide_category":
                category_id = payload.category_id
                if not category_id and payload.article_id:
                    article_result = await session.execute(
                        select(NewsArticleRecord).where(
                            NewsArticleRecord.id == payload.article_id.strip()
                        )
                    )
                    article = article_result.scalar_one_or_none()
                    if article is not None:
                        category_id = await self._resolve_category_id_from_name(
                            session,
                            article.category,
                        )
                normalized_category_id = (
                    self._normalize_category_id(category_id) if category_id else None
                )
                if normalized_category_id is None:
                    raise InvalidFeedbackPayloadError(
                        "hide_category requires category_id or article_id."
                    )
                await self._assert_categories_exist(session, [normalized_category_id])
                await self._ensure_hidden_item(
                    session,
                    user_id=normalized_user_id,
                    article_id=None,
                    source=None,
                    category_id=normalized_category_id,
                    now=now,
                )

            elif action == "follow_topic":
                topic = self._normalize_topic(payload.topic)
                if topic is None:
                    raise InvalidFeedbackPayloadError("follow_topic requires topic.")
                await self._ensure_topic_followed(
                    session,
                    user_id=normalized_user_id,
                    topic=topic,
                    now=now,
                )

            elif action == "unfollow_topic":
                topic = self._normalize_topic(payload.topic)
                if topic is None:
                    raise InvalidFeedbackPayloadError("unfollow_topic requires topic.")
                await self._ensure_topic_unfollowed(
                    session,
                    user_id=normalized_user_id,
                    topic=topic,
                )

            else:
                raise InvalidFeedbackPayloadError(f"Unsupported feedback action '{action}'.")

            await session.commit()
            return FeedFeedbackResponse(status="applied", action=payload.action)

    async def get_personalized_feed(
        self,
        *,
        user_id: str,
        limit: int = 20,
        category: str | None = None,
        cursor: datetime | None = None,
    ) -> PersonalizedFeedResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        now = datetime.utcnow()
        candidate_limit = max(limit * 10, 200)

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)

            category_lookup = await self._category_lookup(session)
            interest_scores = await self._interest_score_map(session, normalized_user_id)
            hidden_articles, hidden_sources, hidden_categories = await self._hidden_sets(
                session,
                normalized_user_id,
            )
            seen_articles = await self._seen_article_ids(session, normalized_user_id)
            trend_counts = await self._trend_counts(session)
            max_trend = max(trend_counts.values()) if trend_counts else 0

            statement = (
                select(NewsArticleRecord)
                .where(NewsArticleRecord.status == "published")
                .order_by(NewsArticleRecord.published_at.desc())
                .limit(candidate_limit)
            )
            if cursor is not None:
                statement = statement.where(NewsArticleRecord.published_at < cursor)

            category_filter = self._normalize_category_filter(category)
            if category_filter:
                statement = statement.where(
                    func.lower(NewsArticleRecord.category).in_(category_filter)
                )

            result = await session.execute(statement)
            candidates = result.scalars().all()

            scored_rows: list[tuple[float, NewsArticleRecord]] = []
            for row in candidates:
                if row.id in hidden_articles:
                    continue
                source_key = (row.source or "").strip().lower()
                if source_key and source_key in hidden_sources:
                    continue

                category_id = self._resolve_category_id_in_lookup(
                    category_lookup,
                    row.category,
                )
                if category_id and category_id in hidden_categories:
                    continue

                preference_score = interest_scores.get(category_id or "", 0.0)
                freshness_score = self._freshness_score(now, row.published_at)
                trend_score = 0.0
                if max_trend > 0:
                    trend_score = (trend_counts.get(row.id, 0) / max_trend) * 0.8
                seen_penalty = -0.7 if row.id in seen_articles else 0.0

                final_score = preference_score + freshness_score + trend_score + seen_penalty
                scored_rows.append((final_score, row))

            scored_rows.sort(
                key=lambda item: (
                    item[0],
                    item[1].published_at,
                ),
                reverse=True,
            )

            selected_rows = [row for _, row in scored_rows[:limit]]
            items = [self._to_news_schema(row) for row in selected_rows]
            return PersonalizedFeedResponse(
                items=items,
                total=len(scored_rows),
                strategy="hybrid_v1",
            )

    async def _assert_user_exists(self, session: AsyncSession, user_id: str) -> None:
        result = await session.execute(select(UserRecord).where(UserRecord.id == user_id))
        if result.scalar_one_or_none() is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")

    async def _assert_categories_exist(
        self,
        session: AsyncSession,
        category_ids: list[str],
    ) -> None:
        result = await session.execute(
            select(CategoryRecord.id).where(CategoryRecord.id.in_(category_ids))
        )
        found = set(result.scalars().all())
        missing = sorted(set(category_ids) - found)
        if missing:
            raise CategoryNotFoundError(f"Unknown categories: {', '.join(missing)}")

    async def _replace_followed_topics(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        topics: list[str],
        now: datetime,
    ) -> None:
        desired_topics = self._normalize_topics(topics)
        existing_result = await session.execute(
            select(UserTopicFollowRecord).where(UserTopicFollowRecord.user_id == user_id)
        )
        existing_rows = existing_result.scalars().all()
        existing_map = {row.topic.lower(): row for row in existing_rows}

        desired_key_map = {topic.lower(): topic for topic in desired_topics}
        for key, row in existing_map.items():
            if key not in desired_key_map:
                await session.delete(row)

        for key, topic in desired_key_map.items():
            if key in existing_map:
                continue
            session.add(
                UserTopicFollowRecord(
                    user_id=user_id,
                    topic=topic,
                    created_at=now,
                )
            )

    async def _ensure_topic_followed(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        topic: str,
        now: datetime,
    ) -> None:
        result = await session.execute(
            select(UserTopicFollowRecord).where(
                UserTopicFollowRecord.user_id == user_id,
                func.lower(UserTopicFollowRecord.topic) == topic.lower(),
            )
        )
        if result.scalar_one_or_none() is None:
            session.add(UserTopicFollowRecord(user_id=user_id, topic=topic, created_at=now))

    async def _ensure_topic_unfollowed(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        topic: str,
    ) -> None:
        result = await session.execute(
            select(UserTopicFollowRecord).where(
                UserTopicFollowRecord.user_id == user_id,
                func.lower(UserTopicFollowRecord.topic) == topic.lower(),
            )
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            await session.delete(existing)

    async def _upsert_interest_delta(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        category_id: str,
        delta: float,
        now: datetime,
    ) -> UserInterestProfileRecord:
        result = await session.execute(
            select(UserInterestProfileRecord).where(
                UserInterestProfileRecord.user_id == user_id,
                UserInterestProfileRecord.category_id == category_id,
            )
        )
        row = result.scalar_one_or_none()
        if row is None:
            row = UserInterestProfileRecord(
                user_id=user_id,
                category_id=category_id,
                explicit_weight=0.0,
                implicit_weight=0.0,
                created_at=now,
                updated_at=now,
            )
            session.add(row)

        next_weight = row.implicit_weight + delta
        row.implicit_weight = max(self._MIN_IMPLICIT_WEIGHT, min(self._MAX_IMPLICIT_WEIGHT, next_weight))
        row.updated_at = now
        return row

    async def _ensure_hidden_item(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        article_id: str | None,
        source: str | None,
        category_id: str | None,
        now: datetime,
    ) -> None:
        normalized_article_id = (article_id or "").strip() or None
        normalized_source = (source or "").strip() or None
        normalized_category_id = self._normalize_category_id(category_id) if category_id else None
        if not any([normalized_article_id, normalized_source, normalized_category_id]):
            raise InvalidFeedbackPayloadError(
                "One of article_id/source/category_id is required for hide actions."
            )

        statement = select(UserHiddenItemRecord).where(UserHiddenItemRecord.user_id == user_id)
        if normalized_article_id is not None:
            statement = statement.where(UserHiddenItemRecord.article_id == normalized_article_id)
        if normalized_source is not None:
            statement = statement.where(
                func.lower(UserHiddenItemRecord.source) == normalized_source.lower()
            )
        if normalized_category_id is not None:
            statement = statement.where(UserHiddenItemRecord.category_id == normalized_category_id)

        existing_result = await session.execute(statement)
        if existing_result.scalar_one_or_none() is None:
            session.add(
                UserHiddenItemRecord(
                    user_id=user_id,
                    article_id=normalized_article_id,
                    source=normalized_source,
                    category_id=normalized_category_id,
                    created_at=now,
                )
            )

    async def _build_profile(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> PersonalizationProfileResponse:
        interests_result = await session.execute(
            select(UserInterestProfileRecord, CategoryRecord)
            .join(CategoryRecord, UserInterestProfileRecord.category_id == CategoryRecord.id)
            .where(UserInterestProfileRecord.user_id == user_id)
            .order_by(
                (UserInterestProfileRecord.explicit_weight + UserInterestProfileRecord.implicit_weight).desc(),
                CategoryRecord.name.asc(),
            )
        )
        interests: list[PersonalizedInterest] = []
        for profile, category in interests_result.all():
            interests.append(self._to_interest_schema(profile, category))

        topics_result = await session.execute(
            select(UserTopicFollowRecord)
            .where(UserTopicFollowRecord.user_id == user_id)
            .order_by(UserTopicFollowRecord.created_at.desc(), UserTopicFollowRecord.topic.asc())
        )
        topics = [
            FollowedTopic(topic=row.topic, created_at=row.created_at)
            for row in topics_result.scalars().all()
        ]
        return PersonalizationProfileResponse(user_id=user_id, interests=interests, topics=topics)

    async def _interest_score_map(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> Dict[str, float]:
        result = await session.execute(
            select(UserInterestProfileRecord).where(
                UserInterestProfileRecord.user_id == user_id
            )
        )
        scores: dict[str, float] = {}
        for row in result.scalars().all():
            # Explicit preferences are primary. Implicit adds adaptive behavior.
            scores[row.category_id] = (row.explicit_weight * 2.0) + row.implicit_weight
        return scores

    async def _hidden_sets(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> tuple[set[str], set[str], set[str]]:
        result = await session.execute(
            select(UserHiddenItemRecord).where(UserHiddenItemRecord.user_id == user_id)
        )
        hidden_articles: set[str] = set()
        hidden_sources: set[str] = set()
        hidden_categories: set[str] = set()
        for row in result.scalars().all():
            if row.article_id:
                hidden_articles.add(row.article_id)
            if row.source:
                hidden_sources.add(row.source.strip().lower())
            if row.category_id:
                hidden_categories.add(row.category_id)
        return hidden_articles, hidden_sources, hidden_categories

    async def _seen_article_ids(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> set[str]:
        cutoff = datetime.utcnow() - timedelta(days=7)
        result = await session.execute(
            select(FeedEventRecord.article_id).where(
                FeedEventRecord.user_id == user_id,
                FeedEventRecord.article_id.is_not(None),
                FeedEventRecord.created_at >= cutoff,
            )
        )
        return {row for row in result.scalars().all() if row}

    async def _trend_counts(self, session: AsyncSession) -> Dict[str, int]:
        cutoff = datetime.utcnow() - timedelta(hours=24)
        result = await session.execute(
            select(FeedEventRecord.article_id, func.count(FeedEventRecord.id))
            .where(
                FeedEventRecord.article_id.is_not(None),
                FeedEventRecord.created_at >= cutoff,
                FeedEventRecord.event_type.in_(self._TREND_EVENT_TYPES),
            )
            .group_by(FeedEventRecord.article_id)
        )
        return {article_id: count for article_id, count in result.all() if article_id}

    async def _category_lookup(self, session: AsyncSession) -> dict[str, str]:
        result = await session.execute(select(CategoryRecord.id, CategoryRecord.name))
        lookup: dict[str, str] = {}
        for category_id, name in result.all():
            lookup[category_id] = category_id
            lookup[name.strip().lower()] = category_id
            lookup[self._slugify(name)] = category_id
        for alias, category_id in self._CATEGORY_ALIASES.items():
            lookup[alias] = category_id
        return lookup

    async def _resolve_category_id_from_name(
        self,
        session: AsyncSession,
        category_name: str | None,
    ) -> str | None:
        if not category_name:
            return None
        lookup = await self._category_lookup(session)
        return self._resolve_category_id_in_lookup(lookup, category_name)

    def _resolve_category_id_in_lookup(
        self,
        lookup: dict[str, str],
        category_name: str | None,
    ) -> str | None:
        if not category_name:
            return None
        normalized = category_name.strip().lower()
        if normalized in lookup:
            return lookup[normalized]
        slug = self._slugify(normalized)
        return lookup.get(slug)

    def _normalize_user_id(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if not normalized:
            raise MissingUserContextError("x-user-id header is required.")
        return normalized[:128]

    def _normalize_category_id(self, value: str | None) -> str:
        normalized = (value or "").strip().lower()
        normalized = self._CATEGORY_ALIASES.get(normalized, normalized)
        if not normalized:
            raise CategoryNotFoundError("category_id is required.")
        return normalized[:80]

    def _normalize_topic(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        return normalized[:120]

    def _normalize_topics(self, values: list[str]) -> list[str]:
        dedup: dict[str, str] = {}
        for raw in values:
            topic = self._normalize_topic(raw)
            if topic is None:
                continue
            dedup[topic.lower()] = topic
        return list(dedup.values())

    def _normalize_category_filter(self, value: str | None) -> list[str]:
        normalized = (value or "").strip().lower()
        if not normalized:
            return []
        variants = {normalized}
        if normalized in self._CATEGORY_ALIASES:
            mapped = self._CATEGORY_ALIASES[normalized]
            variants.add(mapped)
            variants.add(mapped.replace("-", " "))
        if normalized == "breaking-news":
            variants.add("breaking news")
            variants.add("breaking")
        if normalized == "technology":
            variants.add("tech")
        return list(variants)

    def _slugify(self, value: str) -> str:
        return "-".join(value.strip().lower().split())

    def _implicit_delta(self, *, event_type: str, dwell_ms: int | None) -> float:
        if event_type == "dwell":
            duration = dwell_ms or 0
            if duration >= 30_000:
                return 0.45
            if duration >= 10_000:
                return 0.20
            return 0.05
        return self._EVENT_IMPLICIT_DELTA.get(event_type, 0.0)

    def _freshness_score(self, now: datetime, published_at: datetime) -> float:
        age_hours = max(0.0, (now - published_at).total_seconds() / 3600)
        return max(0.0, 1.5 - min(age_hours, 72.0) / 48.0)

    def _to_interest_schema(
        self,
        profile: UserInterestProfileRecord,
        category: CategoryRecord,
    ) -> PersonalizedInterest:
        return PersonalizedInterest(
            category_id=category.id,
            category_name=category.name,
            color_hex=category.color_hex,
            explicit_weight=profile.explicit_weight,
            implicit_weight=profile.implicit_weight,
            updated_at=profile.updated_at,
        )

    def _to_news_schema(self, row: NewsArticleRecord) -> NewsArticle:
        image_url = row.image_url
        if image_url is None and row.summary:
            extracted = extract_first_image_from_html(row.summary, base_url=row.url)
            image_url = extracted or None

        return NewsArticle(
            id=row.id,
            title=row.title,
            source=row.source,
            category=row.category,
            tags=[
                tag.tag.strip()
                for tag in row.tags
                if tag.tag and tag.tag.strip()
            ]
            or [row.category],
            summary=plain_text_excerpt(row.summary),
            url=row.url,
            image_url=image_url,
            submitted_by=row.submitted_by,
            is_user_generated=row.is_user_generated,
            published_at=row.published_at,
            fact_checked=row.fact_checked,
        )
