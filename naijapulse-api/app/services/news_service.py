import asyncio
import hashlib
import re
from datetime import datetime, timedelta
from html import unescape
from typing import List, Optional, Tuple
from urllib.parse import urlparse
from uuid import uuid4

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings, get_settings
from app.core.text import plain_text_excerpt
from app.db.models import (
    ArticleTagRecord,
    ArticleWorkflowEventRecord,
    HomepageCategoryRecord,
    HomepageSettingsRecord,
    HomepageSecondaryChipRecord,
    HomepageStoryPlacementRecord,
    NewsArticleRecord,
    UserRecord,
)
from app.integrations.news_sources.image_extraction import extract_first_image_from_html
from app.schemas.news import (
    AdminCreateNewsArticleRequest,
    AdminUpdateNewsArticleRequest,
    CreateNewsArticleRequest,
    HomepageCategoryFeed,
    HomepageContentResponse,
    HomepageSecondaryChipFeed,
    NewsArticle,
)
from app.services.notifications_service import NotificationsService, PendingNotificationDelivery


class UserNotFoundError(Exception):
    pass


class DuplicateNewsArticleError(Exception):
    pass


class InvalidNewsPayloadError(Exception):
    pass


class NewsPermissionError(Exception):
    pass


class NewsStateError(Exception):
    pass


class NewsArticleNotFoundError(Exception):
    pass


class NewsService:
    """Stores and serves normalized articles with DB-backed deduplication."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        notifications_service: NotificationsService,
        settings: Settings | None = None,
    ) -> None:
        self._session_factory = session_factory
        self._notifications_service = notifications_service
        self._lock = asyncio.Lock()
        resolved_settings = settings or get_settings()
        self._homepage_latest_autofill_enabled = (
            resolved_settings.homepage_latest_autofill_enabled
        )
        self._homepage_latest_item_limit = max(
            1, resolved_settings.homepage_latest_item_limit
        )
        self._homepage_latest_window = timedelta(
            hours=max(1, resolved_settings.homepage_latest_window_hours)
        )
        self._homepage_latest_fallback_window = timedelta(
            hours=max(1, resolved_settings.homepage_latest_fallback_window_hours)
        )

    async def initialize_defaults(self) -> None:
        """No-op. News should only come from ingestion sources."""
        return

    async def get_top_stories(
        self,
        limit: int = 10,
        category: Optional[str] = None,
    ) -> List[NewsArticle]:
        return await self._query_top_stories_rss_first(limit=limit, category=category)

    async def get_latest_stories(
        self,
        limit: int = 20,
        category: Optional[str] = None,
        diversify_sources: bool = True,
    ) -> List[NewsArticle]:
        if diversify_sources:
            return await self._query_latest_stories_diversified(
                limit=limit,
                category=category,
            )
        return await self._query_stories(limit=limit, category=category)

    async def get_homepage_content(self) -> HomepageContentResponse:
        async with self._session_factory() as session:
            categories_result = await session.execute(
                select(HomepageCategoryRecord)
                .where(HomepageCategoryRecord.enabled.is_(True))
                .order_by(
                    HomepageCategoryRecord.position.asc(),
                    HomepageCategoryRecord.label.asc(),
                )
            )
            category_rows = categories_result.scalars().all()

            chip_result = await session.execute(
                select(HomepageSecondaryChipRecord)
                .where(HomepageSecondaryChipRecord.enabled.is_(True))
                .order_by(
                    HomepageSecondaryChipRecord.position.asc(),
                    HomepageSecondaryChipRecord.label.asc(),
                )
            )
            chip_rows = chip_result.scalars().all()

            placement_result = await session.execute(
                select(HomepageStoryPlacementRecord)
                .where(HomepageStoryPlacementRecord.enabled.is_(True))
                .order_by(
                    HomepageStoryPlacementRecord.section.asc(),
                    HomepageStoryPlacementRecord.target_key.asc(),
                    HomepageStoryPlacementRecord.position.asc(),
                    HomepageStoryPlacementRecord.id.asc(),
                )
            )
            placements = placement_result.scalars().all()

            homepage_settings = await session.get(HomepageSettingsRecord, 1)
            latest_autofill_enabled = (
                homepage_settings.latest_autofill_enabled
                if homepage_settings is not None
                else self._homepage_latest_autofill_enabled
            )
            latest_item_limit = max(
                1,
                homepage_settings.latest_item_limit
                if homepage_settings is not None
                else self._homepage_latest_item_limit,
            )
            latest_window = timedelta(
                hours=max(
                    1,
                    homepage_settings.latest_window_hours
                    if homepage_settings is not None
                    else int(self._homepage_latest_window.total_seconds() // 3600),
                )
            )
            latest_fallback_window = timedelta(
                hours=max(
                    1,
                    homepage_settings.latest_fallback_window_hours
                    if homepage_settings is not None
                    else int(
                        self._homepage_latest_fallback_window.total_seconds() // 3600
                    ),
                )
            )

            article_ids = list({item.article_id for item in placements})
            article_by_id: dict[str, NewsArticleRecord] = {}
            if article_ids:
                article_result = await session.execute(
                    select(NewsArticleRecord).where(
                        NewsArticleRecord.id.in_(article_ids),
                        NewsArticleRecord.status == "published",
                    )
                )
                article_by_id = {
                    row.id: row
                    for row in article_result.scalars().all()
                }

        grouped: dict[tuple[str, str | None], list[NewsArticle]] = {}
        for placement in placements:
            article = article_by_id.get(placement.article_id)
            if article is None:
                continue
            key = (placement.section, placement.target_key)
            grouped.setdefault(key, []).append(self._to_schema(article))

        categories = [
            HomepageCategoryFeed(
                key=row.id,
                label=row.label,
                color_hex=row.color_hex,
                position=row.position,
                items=grouped.get(("category", row.id), []),
            )
            for row in category_rows
        ]
        secondary_chips = [
            HomepageSecondaryChipFeed(
                key=row.id,
                label=row.label,
                chip_type=row.chip_type,
                color_hex=row.color_hex,
                position=row.position,
                items=grouped.get(("secondary_chip", row.id), []),
            )
            for row in chip_rows
        ]

        top_stories = grouped.get(("top", None), [])
        top_story_ids = {story.id for story in top_stories}
        latest_placement_stories = self._exclude_story_ids(
            grouped.get(("latest", None), []),
            excluded_ids=top_story_ids,
        )
        latest_stories = await self._build_homepage_latest_stories(
            pinned_latest=latest_placement_stories,
            excluded_ids=top_story_ids,
            limit=latest_item_limit,
            autofill_enabled=latest_autofill_enabled,
            recent_window=latest_window,
            fallback_window=latest_fallback_window,
        )

        return HomepageContentResponse(
            generated_at=datetime.utcnow(),
            top_stories=top_stories,
            latest_stories=latest_stories,
            categories=categories,
            secondary_chips=secondary_chips,
        )

    async def get_story(self, article_id: str) -> NewsArticle:
        async with self._session_factory() as session:
            result = await session.execute(
                select(NewsArticleRecord).where(
                    NewsArticleRecord.id == article_id,
                    NewsArticleRecord.status == "published",
                )
            )
            row = result.scalar_one_or_none()
            if row is None:
                raise NewsArticleNotFoundError(f"Article '{article_id}' does not exist.")
            return self._to_schema(row)

    async def search_stories(
        self,
        *,
        query: str,
        limit: int = 25,
        category: Optional[str] = None,
    ) -> List[NewsArticle]:
        normalized_query = query.strip().lower()
        if len(normalized_query) < 2:
            return []

        async with self._session_factory() as session:
            statement = (
                select(NewsArticleRecord)
                .where(
                    NewsArticleRecord.status == "published",
                    or_(
                        func.lower(NewsArticleRecord.title).contains(
                            normalized_query
                        ),
                        func.lower(NewsArticleRecord.source).contains(
                            normalized_query
                        ),
                        func.lower(
                            func.coalesce(NewsArticleRecord.summary, "")
                        ).contains(normalized_query),
                        self._tag_contains_condition(normalized_query),
                    )
                )
                .order_by(NewsArticleRecord.published_at.desc())
                .limit(limit)
            )
            if category:
                normalized = category.strip().lower()
                statement = statement.where(
                    func.lower(NewsArticleRecord.category) == normalized
                )

            result = await session.execute(statement)
            rows = result.scalars().all()
            fresh_rows = [row for row in rows if not self._is_row_stale(row)]
            return [self._to_schema(row) for row in fresh_rows[:limit]]

    async def ingest_articles(self, articles: List[NewsArticle]) -> Tuple[int, int]:
        """Ingest normalized articles and return `(inserted, deduped)` counters."""
        if not articles:
            return 0, 0

        inserted = 0
        deduped = 0
        fingerprints = [self._fingerprint(article) for article in articles]

        async with self._lock:
            async with self._session_factory() as session:
                existing_records_result = await session.execute(
                    select(NewsArticleRecord).where(NewsArticleRecord.fingerprint.in_(fingerprints))
                )
                existing_records = existing_records_result.scalars().all()
                existing_by_fingerprint = {
                    record.fingerprint: record for record in existing_records
                }

                incoming_ids = [article.id for article in articles]
                existing_ids_result = await session.execute(
                    select(NewsArticleRecord.id).where(NewsArticleRecord.id.in_(incoming_ids))
                )
                existing_ids = set(existing_ids_result.scalars().all())
                generated_ids: set[str] = set()

                for article, fingerprint in zip(articles, fingerprints):
                    incoming_provider = self._provider_from_article_id(article.id)
                    existing_record = existing_by_fingerprint.get(fingerprint)
                    if existing_record is not None:
                        # Backfill nullable fields when the same article is seen again.
                        if existing_record.image_url is None and article.image_url is not None:
                            existing_record.image_url = str(article.image_url)
                        if existing_record.summary is None and article.summary:
                            existing_record.summary = article.summary
                        if existing_record.source_domain is None and article.url is not None:
                            existing_record.source_domain = self._extract_source_domain(str(article.url))
                        self._merge_article_tags(existing_record, article.tags)
                        existing_record.ingestion_provider = self._resolve_preferred_provider(
                            current=existing_record.ingestion_provider,
                            incoming=incoming_provider,
                        )
                        existing_record.updated_at = datetime.utcnow()
                        deduped += 1
                        continue

                    article_id = self._ensure_unique_id(
                        base_id=article.id,
                        fingerprint=fingerprint,
                        taken_ids=existing_ids.union(generated_ids),
                    )
                    generated_ids.add(article_id)
                    record = NewsArticleRecord(
                        id=article_id,
                        fingerprint=fingerprint,
                        ingestion_provider=incoming_provider,
                        title=article.title,
                        source=article.source,
                        category=article.category,
                        summary=article.summary,
                        url=str(article.url) if article.url else None,
                        source_domain=self._extract_source_domain(
                            str(article.url) if article.url else None
                        ),
                        source_type=self._source_type_for_provider(incoming_provider),
                        image_url=str(article.image_url) if article.image_url else None,
                        submitted_by=article.submitted_by,
                        created_by_user_id=article.submitted_by,
                        is_user_generated=article.is_user_generated,
                        status="submitted",
                        verification_status="fact_checked"
                        if article.fact_checked
                        else "unverified",
                        published_at=article.published_at,
                        fact_checked=article.fact_checked,
                        is_featured=False,
                        review_notes=None,
                        created_at=datetime.utcnow(),
                        updated_at=datetime.utcnow(),
                    )
                    self._replace_article_tags(record, self._normalize_tags(article.tags))
                    session.add(record)
                    session.add(
                        ArticleWorkflowEventRecord(
                            article_id=record.id,
                            actor_user_id=None,
                            event_type="submit",
                            from_status=None,
                            to_status="submitted",
                            notes=f"Ingested from source '{record.source}'.",
                            created_at=datetime.utcnow(),
                        )
                    )
                    existing_by_fingerprint[fingerprint] = record
                    inserted += 1

                await session.commit()

        return inserted, deduped

    async def create_user_article(
        self,
        *,
        user_id: str,
        payload: CreateNewsArticleRequest,
    ) -> NewsArticle:
        normalized_user_id = self._normalize_user_id(user_id)
        if not normalized_user_id:
            raise InvalidNewsPayloadError("User id is required.")

        title = payload.title.strip()
        category = payload.category.strip()
        if not title:
            raise InvalidNewsPayloadError("Article title is required.")
        if not category:
            raise InvalidNewsPayloadError("Article category is required.")

        published_at = payload.published_at or datetime.utcnow()
        tags = self._normalize_tags(payload.tags, category=category)
        candidate = NewsArticle(
            id=f"user-article-{uuid4().hex[:12]}",
            title=title,
            source="Community Contributor",
            category=category,
            tags=tags,
            summary=(payload.summary or "").strip() or None,
            url=payload.content_url,
            image_url=payload.image_url,
            submitted_by=normalized_user_id,
            is_user_generated=True,
            published_at=published_at,
            fact_checked=False,
        )

        async with self._lock:
            async with self._session_factory() as session:
                user_result = await session.execute(
                    select(UserRecord).where(UserRecord.id == normalized_user_id)
                )
                user = user_result.scalar_one_or_none()
                if user is None:
                    raise UserNotFoundError(f"User '{normalized_user_id}' does not exist.")
                self._assert_can_contribute(user)
                if user.display_name and user.display_name.strip():
                    candidate.source = user.display_name.strip()

                fingerprint = self._fingerprint(candidate)

                existing_result = await session.execute(
                    select(NewsArticleRecord).where(NewsArticleRecord.fingerprint == fingerprint)
                )
                existing = existing_result.scalar_one_or_none()
                if existing is not None:
                    raise DuplicateNewsArticleError(
                        "An equivalent article already exists."
                    )

                record = NewsArticleRecord(
                    id=candidate.id,
                    fingerprint=fingerprint,
                    ingestion_provider="user",
                    title=candidate.title,
                    source=candidate.source,
                    category=candidate.category,
                    summary=candidate.summary,
                    url=str(candidate.url) if candidate.url else None,
                    source_domain=self._extract_source_domain(
                        str(candidate.url) if candidate.url else None
                    ),
                    source_type="user_submission",
                    image_url=str(candidate.image_url) if candidate.image_url else None,
                    submitted_by=normalized_user_id,
                    created_by_user_id=normalized_user_id,
                    is_user_generated=True,
                    status="submitted",
                    verification_status="unverified",
                    is_featured=False,
                    review_notes=None,
                    published_at=candidate.published_at,
                    fact_checked=False,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
                self._replace_article_tags(record, candidate.tags)
                session.add(record)
                session.add(
                    ArticleWorkflowEventRecord(
                        article_id=record.id,
                        actor_user_id=normalized_user_id,
                        event_type="submit",
                        from_status=None,
                        to_status="submitted",
                        notes="Submitted by contributor",
                        created_at=datetime.utcnow(),
                    )
                )
                await session.commit()
                return self._to_schema(record)

    async def list_admin_articles(
        self,
        *,
        actor_user_id: str,
        status: str | None = None,
        query: str | None = None,
        source: str | None = None,
        tag: str | None = None,
        published_from: datetime | None = None,
        published_to: datetime | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> tuple[list[NewsArticle], int]:
        normalized_actor_id = self._normalize_user_id(actor_user_id)
        if not normalized_actor_id:
            raise InvalidNewsPayloadError("User id is required.")

        async with self._session_factory() as session:
            actor = await self._load_user_or_raise(session, normalized_actor_id)
            self._assert_admin(actor)

            filters = []
            if status and status.strip():
                normalized_status = self._validate_status(status)
                filters.append(NewsArticleRecord.status == normalized_status)
            if source and source.strip():
                filters.append(NewsArticleRecord.source.ilike(source.strip()))
            if tag and tag.strip():
                filters.append(self._tag_equals_condition(tag.strip().lower()))
            if published_from is not None:
                filters.append(NewsArticleRecord.published_at >= published_from)
            if published_to is not None:
                filters.append(NewsArticleRecord.published_at <= published_to)
            if query and query.strip():
                normalized_query = f"%{query.strip()}%"
                filters.append(
                    or_(
                        NewsArticleRecord.title.ilike(normalized_query),
                        NewsArticleRecord.source.ilike(normalized_query),
                        NewsArticleRecord.category.ilike(normalized_query),
                        NewsArticleRecord.summary.ilike(normalized_query),
                        self._tag_contains_condition(query.strip().lower()),
                    )
                )

            total_statement = select(func.count()).select_from(NewsArticleRecord)
            if filters:
                total_statement = total_statement.where(*filters)

            total_result = await session.execute(total_statement)
            total = int(total_result.scalar() or 0)

            statement = select(NewsArticleRecord).order_by(
                NewsArticleRecord.updated_at.desc(),
                NewsArticleRecord.created_at.desc(),
            )
            if filters:
                statement = statement.where(*filters)
            statement = statement.offset(max(offset, 0)).limit(limit)

            result = await session.execute(statement)
            rows = result.scalars().all()
            return [self._to_schema(row) for row in rows], total

    async def create_admin_article(
        self,
        *,
        actor_user_id: str,
        payload: AdminCreateNewsArticleRequest,
    ) -> NewsArticle:
        normalized_actor_id = self._normalize_user_id(actor_user_id)
        if not normalized_actor_id:
            raise InvalidNewsPayloadError("User id is required.")

        status_value = self._validate_status(payload.status)
        verification_status = self._validate_verification_status(
            payload.verification_status
        )
        published_at = payload.published_at or datetime.utcnow()
        source_url = str(payload.source_url)
        tags = self._normalize_tags(payload.tags, category=payload.category)

        async with self._lock:
            async with self._session_factory() as session:
                actor = await self._load_user_or_raise(session, normalized_actor_id)
                self._assert_admin(actor)

                candidate = NewsArticle(
                    id=f"admin-article-{uuid4().hex[:12]}",
                    title=payload.title.strip(),
                    source=payload.source.strip(),
                    category=payload.category.strip(),
                    tags=tags,
                    summary=(payload.summary or "").strip() or None,
                    url=payload.source_url,
                    source_domain=self._extract_source_domain(source_url),
                    source_type="admin_submission",
                    image_url=payload.image_url,
                    submitted_by=normalized_actor_id,
                    created_by_user_id=normalized_actor_id,
                    is_user_generated=False,
                    status=status_value,
                    verification_status=verification_status,
                    is_featured=payload.is_featured,
                    review_notes=(payload.review_notes or "").strip() or None,
                    published_at=published_at,
                    fact_checked=verification_status == "fact_checked",
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )

                fingerprint = self._fingerprint(candidate)
                existing_result = await session.execute(
                    select(NewsArticleRecord).where(NewsArticleRecord.fingerprint == fingerprint)
                )
                if existing_result.scalar_one_or_none() is not None:
                    raise DuplicateNewsArticleError("An equivalent article already exists.")

                record = NewsArticleRecord(
                    id=candidate.id,
                    fingerprint=fingerprint,
                    ingestion_provider="admin",
                    title=candidate.title,
                    source=candidate.source,
                    category=candidate.category,
                    summary=candidate.summary,
                    url=source_url,
                    source_domain=candidate.source_domain,
                    source_type="admin_submission",
                    image_url=str(payload.image_url) if payload.image_url else None,
                    submitted_by=normalized_actor_id,
                    created_by_user_id=normalized_actor_id,
                    reviewed_by_user_id=normalized_actor_id
                    if status_value in {"approved", "published", "rejected"}
                    else None,
                    published_by_user_id=normalized_actor_id
                    if status_value == "published"
                    else None,
                    is_user_generated=False,
                    status=status_value,
                    verification_status=verification_status,
                    is_featured=payload.is_featured,
                    review_notes=(payload.review_notes or "").strip() or None,
                    published_at=published_at,
                    fact_checked=verification_status == "fact_checked",
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
                self._replace_article_tags(record, candidate.tags)
                session.add(record)
                session.add(
                    ArticleWorkflowEventRecord(
                        article_id=record.id,
                        actor_user_id=normalized_actor_id,
                        event_type="create",
                        from_status=None,
                        to_status=status_value,
                        notes=record.review_notes,
                        created_at=datetime.utcnow(),
                    )
                )
                await session.commit()
                return self._to_schema(record)

    async def update_admin_article(
        self,
        *,
        actor_user_id: str,
        article_id: str,
        payload: AdminUpdateNewsArticleRequest,
    ) -> NewsArticle:
        normalized_actor_id = self._normalize_user_id(actor_user_id)
        if not normalized_actor_id:
            raise InvalidNewsPayloadError("User id is required.")

        async with self._lock:
            async with self._session_factory() as session:
                actor = await self._load_user_or_raise(session, normalized_actor_id)
                self._assert_admin(actor)
                record = await self._load_article_or_raise(session, article_id)

                update_data = payload.model_dump(exclude_unset=True)
                if not update_data:
                    return self._to_schema(record)

                if "title" in update_data and update_data["title"] is not None:
                    record.title = str(update_data["title"]).strip()
                if "source" in update_data and update_data["source"] is not None:
                    record.source = str(update_data["source"]).strip()
                if "category" in update_data and update_data["category"] is not None:
                    record.category = str(update_data["category"]).strip()
                if "tags" in update_data:
                    self._replace_article_tags(
                        record,
                        self._normalize_tags(
                            update_data["tags"] or [],
                            category=record.category,
                        ),
                    )
                if "summary" in update_data:
                    record.summary = (update_data["summary"] or "").strip() or None
                if "source_url" in update_data and update_data["source_url"] is not None:
                    record.url = str(update_data["source_url"])
                    record.source_domain = self._extract_source_domain(record.url)
                if "image_url" in update_data:
                    record.image_url = (
                        str(update_data["image_url"]) if update_data["image_url"] else None
                    )
                if (
                    "verification_status" in update_data
                    and update_data["verification_status"] is not None
                ):
                    record.verification_status = self._validate_verification_status(
                        str(update_data["verification_status"])
                    )
                    record.fact_checked = record.verification_status == "fact_checked"
                if "is_featured" in update_data and update_data["is_featured"] is not None:
                    record.is_featured = bool(update_data["is_featured"])
                if "review_notes" in update_data:
                    record.review_notes = (update_data["review_notes"] or "").strip() or None

                record.updated_at = datetime.utcnow()
                session.add(
                    ArticleWorkflowEventRecord(
                        article_id=record.id,
                        actor_user_id=normalized_actor_id,
                        event_type="update",
                        from_status=record.status,
                        to_status=record.status,
                        notes=record.review_notes,
                        created_at=datetime.utcnow(),
                    )
                )
                await session.commit()
                return self._to_schema(record)

    async def transition_admin_article(
        self,
        *,
        actor_user_id: str,
        article_id: str,
        action: str,
        notes: str | None = None,
    ) -> NewsArticle:
        normalized_actor_id = self._normalize_user_id(actor_user_id)
        normalized_action = action.strip().lower()
        if not normalized_actor_id:
            raise InvalidNewsPayloadError("User id is required.")
        if normalized_action not in {"submit", "approve", "publish", "reject", "archive"}:
            raise InvalidNewsPayloadError("Unsupported article workflow action.")

        async with self._lock:
            async with self._session_factory() as session:
                actor = await self._load_user_or_raise(session, normalized_actor_id)
                self._assert_admin(actor)
                record = await self._load_article_or_raise(session, article_id)
                previous_status = record.status
                next_status = self._next_status(previous_status, normalized_action)

                if normalized_action in {"approve", "reject"}:
                    record.reviewed_by_user_id = normalized_actor_id
                if normalized_action == "publish":
                    record.reviewed_by_user_id = normalized_actor_id
                    record.published_by_user_id = normalized_actor_id
                    if record.published_at is None:
                        record.published_at = datetime.utcnow()
                if normalized_action == "submit" and record.created_by_user_id is None:
                    record.created_by_user_id = normalized_actor_id

                record.status = next_status
                record.review_notes = (notes or "").strip() or record.review_notes
                record.updated_at = datetime.utcnow()

                session.add(
                    ArticleWorkflowEventRecord(
                        article_id=record.id,
                        actor_user_id=normalized_actor_id,
                        event_type=normalized_action,
                        from_status=previous_status,
                        to_status=next_status,
                        notes=(notes or "").strip() or None,
                        created_at=datetime.utcnow(),
                    )
                )
                pending_notification = await self._create_editorial_notification(
                    session,
                    record=record,
                    actor=actor,
                    action=normalized_action,
                    previous_status=previous_status,
                    next_status=next_status,
                )
                await session.commit()
                await self._notifications_service.deliver_push(pending_notification)
                return self._to_schema(record)

    async def _query_stories(
        self,
        *,
        limit: int,
        category: Optional[str],
    ) -> List[NewsArticle]:
        async with self._session_factory() as session:
            statement = select(NewsArticleRecord).order_by(NewsArticleRecord.published_at.desc()).limit(limit)
            statement = statement.where(NewsArticleRecord.status == "published")
            if category:
                normalized = category.strip().lower()
                statement = statement.where(func.lower(NewsArticleRecord.category) == normalized)

            result = await session.execute(statement)
            rows = result.scalars().all()
            return [self._to_schema(row) for row in rows]

    async def _build_homepage_latest_stories(
        self,
        *,
        pinned_latest: list[NewsArticle],
        excluded_ids: set[str],
        limit: int,
        autofill_enabled: bool,
        recent_window: timedelta,
        fallback_window: timedelta,
    ) -> list[NewsArticle]:
        if limit <= 0:
            return []

        selected = pinned_latest[:limit]
        selected_ids = {story.id for story in selected}
        effective_excluded = excluded_ids | selected_ids
        remaining = limit - len(selected)
        if remaining <= 0 or not autofill_enabled:
            return selected

        auto_latest_primary = await self._query_recent_published_stories(
            limit=remaining,
            recent_window=recent_window,
            excluded_ids=effective_excluded,
        )
        selected.extend(auto_latest_primary)
        effective_excluded = effective_excluded | {
            story.id for story in auto_latest_primary
        }
        remaining = limit - len(selected)
        if (
            remaining <= 0
            or fallback_window <= recent_window
        ):
            return selected

        auto_latest_fallback = await self._query_recent_published_stories(
            limit=remaining,
            recent_window=fallback_window,
            excluded_ids=effective_excluded,
        )
        return [*selected, *auto_latest_fallback]

    async def _query_recent_published_stories(
        self,
        *,
        limit: int,
        recent_window: timedelta,
        excluded_ids: set[str],
    ) -> list[NewsArticle]:
        if limit <= 0:
            return []

        now = datetime.utcnow()
        published_after = now - recent_window

        async with self._session_factory() as session:
            statement = (
                select(NewsArticleRecord)
                .where(
                    NewsArticleRecord.status == "published",
                    NewsArticleRecord.published_at.is_not(None),
                    NewsArticleRecord.published_at >= published_after,
                )
                .order_by(NewsArticleRecord.published_at.desc())
                .limit(max(limit * 4, 40))
            )
            if excluded_ids:
                statement = statement.where(NewsArticleRecord.id.not_in(excluded_ids))

            result = await session.execute(statement)
            rows = result.scalars().all()

        fresh_rows = [
            row for row in rows if row.id not in excluded_ids and not self._is_row_stale(row, now=now)
        ]
        return [self._to_schema(row) for row in fresh_rows[:limit]]

    async def _query_latest_stories_diversified(
        self,
        *,
        limit: int,
        category: Optional[str],
    ) -> List[NewsArticle]:
        # Pull a wider window and interleave by provider id to avoid RSS-only top slices.
        fetch_limit = max(limit * 10, 120)
        async with self._session_factory() as session:
            statement = (
                select(NewsArticleRecord)
                .where(NewsArticleRecord.status == "published")
                .order_by(NewsArticleRecord.published_at.desc())
                .limit(fetch_limit)
            )
            if category:
                normalized = category.strip().lower()
                statement = statement.where(func.lower(NewsArticleRecord.category) == normalized)

            result = await session.execute(statement)
            rows = result.scalars().all()

        rows = [row for row in rows if not self._is_row_stale(row)]
        if len(rows) <= limit:
            return [self._to_schema(row) for row in rows]

        buckets: dict[str, List[NewsArticleRecord]] = {}
        provider_order: List[str] = []
        for row in rows:
            provider = self._provider_for_row(row)
            if provider not in buckets:
                buckets[provider] = []
                provider_order.append(provider)
            buckets[provider].append(row)

        selected: List[NewsArticleRecord] = []
        active_providers = provider_order
        while active_providers and len(selected) < limit:
            next_round: List[str] = []
            for provider in active_providers:
                provider_rows = buckets[provider]
                if not provider_rows:
                    continue
                selected.append(provider_rows.pop(0))
                if provider_rows:
                    next_round.append(provider)
                if len(selected) >= limit:
                    break
            active_providers = next_round

        return [self._to_schema(row) for row in selected]

    async def _query_top_stories_rss_first(
        self,
        *,
        limit: int,
        category: Optional[str],
    ) -> List[NewsArticle]:
        # Prioritize freshness and source diversity for the RSS-first rollout.
        fetch_limit = max(limit * 8, 120)
        async with self._session_factory() as session:
            statement = (
                select(NewsArticleRecord)
                .where(NewsArticleRecord.status == "published")
                .order_by(NewsArticleRecord.published_at.desc())
                .limit(fetch_limit)
            )
            if category:
                normalized = category.strip().lower()
                statement = statement.where(func.lower(NewsArticleRecord.category) == normalized)

            result = await session.execute(statement)
            rows = result.scalars().all()

        rows = [row for row in rows if not self._is_row_stale(row)]
        if not rows:
            return []

        buckets: dict[str, list[NewsArticleRecord]] = {}
        source_order: list[str] = []
        for row in rows:
            source_key = (row.source_domain or row.source or "unknown").strip().lower()
            if source_key not in buckets:
                buckets[source_key] = []
                source_order.append(source_key)
            buckets[source_key].append(row)

        selected: list[NewsArticleRecord] = []
        active_sources = source_order
        while active_sources and len(selected) < limit:
            next_round: list[str] = []
            for source_key in active_sources:
                source_rows = buckets[source_key]
                if not source_rows:
                    continue
                selected.append(source_rows.pop(0))
                if source_rows:
                    next_round.append(source_key)
                if len(selected) >= limit:
                    break
            active_sources = next_round

        return [self._to_schema(row) for row in selected[:limit]]

    def _fingerprint(self, article: NewsArticle) -> str:
        # Keep this deterministic and stable across ingestion runs.
        canonical_url = str(article.url).strip().lower() if article.url else ""
        key = "|".join(
            [
                canonical_url,
                article.title.strip().lower(),
                article.source.strip().lower(),
                article.published_at.strftime("%Y-%m-%d"),
            ]
        )
        return hashlib.sha1(key.encode("utf-8")).hexdigest()

    def _ensure_unique_id(
        self,
        *,
        base_id: str,
        fingerprint: str,
        taken_ids: set[str],
    ) -> str:
        if base_id not in taken_ids:
            return base_id
        return f"{base_id}-{hashlib.sha1(fingerprint.encode()).hexdigest()[:8]}"

    async def _load_user_or_raise(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> UserRecord:
        result = await session.execute(select(UserRecord).where(UserRecord.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")
        return user

    async def _load_article_or_raise(
        self,
        session: AsyncSession,
        article_id: str,
    ) -> NewsArticleRecord:
        result = await session.execute(
            select(NewsArticleRecord).where(NewsArticleRecord.id == article_id)
        )
        article = result.scalar_one_or_none()
        if article is None:
            raise NewsArticleNotFoundError(f"Article '{article_id}' does not exist.")
        return article

    def _assert_admin(self, user: UserRecord) -> None:
        if not user.is_active:
            raise NewsPermissionError("This account is disabled.")
        if user.role not in {"admin", "editor"}:
            raise NewsPermissionError(
                "Admin or editor privileges are required for this action."
            )

    def _assert_can_contribute(self, user: UserRecord) -> None:
        if not user.is_active:
            raise NewsPermissionError("This account is disabled.")
        if self._can_contribute_stories(user):
            return
        raise NewsPermissionError(
            "Story contribution requires admin approval for this account."
        )

    def _can_contribute_stories(self, user: UserRecord) -> bool:
        role = (user.role or "").strip().lower()
        if role in {"admin", "editor", "contributor"}:
            return True
        return bool(user.contribution_access_granted)

    def _validate_status(self, value: str) -> str:
        normalized = value.strip().lower()
        allowed = {
            "draft",
            "submitted",
            "in_review",
            "approved",
            "published",
            "rejected",
            "archived",
        }
        if normalized not in allowed:
            raise InvalidNewsPayloadError("Invalid article status.")
        return normalized

    def _validate_verification_status(self, value: str) -> str:
        normalized = value.strip().lower()
        allowed = {
            "unverified",
            "developing",
            "verified",
            "fact_checked",
            "opinion",
            "sponsored",
        }
        if normalized not in allowed:
            raise InvalidNewsPayloadError("Invalid verification status.")
        return normalized

    def _next_status(self, current: str, action: str) -> str:
        current_status = self._validate_status(current)
        transitions = {
            "submit": {
                "draft": "submitted",
                "rejected": "submitted",
            },
            "approve": {
                "submitted": "approved",
                "in_review": "approved",
                "draft": "approved",
            },
            "publish": {
                "draft": "published",
                "submitted": "published",
                "approved": "published",
                "rejected": "published",
            },
            "reject": {
                "submitted": "rejected",
                "in_review": "rejected",
                "approved": "rejected",
                "draft": "rejected",
            },
            "archive": {
                "draft": "archived",
                "submitted": "archived",
                "approved": "archived",
                "published": "archived",
                "rejected": "archived",
                "in_review": "archived",
            },
        }
        next_status = transitions.get(action, {}).get(current_status)
        if next_status is None:
            raise NewsStateError(
                f"Cannot {action} an article from status '{current_status}'."
            )
        return next_status

    def _provider_for_row(self, row: NewsArticleRecord) -> str:
        if row.ingestion_provider and row.ingestion_provider.strip():
            return row.ingestion_provider.strip().lower()
        return self._provider_from_article_id(row.id)

    async def _create_editorial_notification(
        self,
        session: AsyncSession,
        *,
        record: NewsArticleRecord,
        actor: UserRecord,
        action: str,
        previous_status: str,
        next_status: str,
    ) -> PendingNotificationDelivery | None:
        recipient_user_id = record.created_by_user_id
        if recipient_user_id is None or recipient_user_id == actor.id:
            return None

        notification_type = {
            "approve": "article_approved",
            "publish": "article_published",
            "reject": "article_rejected",
            "archive": "article_archived",
            "submit": "article_submitted",
        }.get(action)
        if notification_type is None:
            return None

        title = {
            "article_approved": "Your article was approved",
            "article_published": "Your article is now live",
            "article_rejected": "Your article was rejected",
            "article_archived": "Your article was archived",
            "article_submitted": "Your article moved to review",
        }[notification_type]

        body = {
            "article_approved": f"{self._user_display_name(actor)} approved \"{record.title}\".",
            "article_published": f"{self._user_display_name(actor)} published \"{record.title}\".",
            "article_rejected": f"{self._user_display_name(actor)} rejected \"{record.title}\".",
            "article_archived": f"{self._user_display_name(actor)} archived \"{record.title}\".",
            "article_submitted": f"\"{record.title}\" moved from {previous_status} to {next_status}.",
        }[notification_type]

        return await self._notifications_service.create_notification(
            session,
            user_id=recipient_user_id,
            type=notification_type,
            title=title,
            body=body,
            actor_user_id=actor.id,
            actor_name=self._user_display_name(actor),
            article_id=record.id,
            comment_id=None,
        )

    def _provider_from_article_id(self, article_id: str) -> str:
        if "-" not in article_id:
            return "unknown"
        return article_id.split("-", 1)[0]

    def _source_type_for_provider(self, provider: str | None) -> str:
        normalized = (provider or "").strip().lower()
        if normalized in {"user", "admin"}:
            return f"{normalized}_submission"
        if normalized.endswith("_rss") or normalized == "rss":
            return "rss"
        if normalized in {"newsapi", "gnews"}:
            return "aggregator_api"
        return "publisher"

    def _extract_source_domain(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        parsed = urlparse(normalized)
        host = parsed.netloc.strip().lower()
        if not host:
            return None
        host = host.removeprefix("www.")
        host = host.split(":", maxsplit=1)[0].strip()
        if not host:
            return None
        return host[:255]

    def _user_display_name(self, user: UserRecord) -> str:
        if user.display_name and user.display_name.strip():
            return user.display_name.strip()
        if user.email and user.email.strip():
            return user.email.strip()
        return user.id

    def _resolve_preferred_provider(
        self,
        *,
        current: str | None,
        incoming: str | None,
    ) -> str | None:
        normalized_current = (current or "").strip().lower() or None
        normalized_incoming = (incoming or "").strip().lower() or None
        if normalized_incoming is None:
            return normalized_current
        if normalized_current is None:
            return normalized_incoming

        priority = {
            "gnews": 4,
            "newsapi": 4,
            "premium_times_rss": 3,
            "guardian_ng_rss": 3,
            "google_news_business_rss": 2,
            "google_news_sports_rss": 2,
            "google_news_technology_rss": 2,
            "google_news_rss": 2,
            "user": 1,
            "unknown": 0,
        }
        if priority.get(normalized_incoming, 1) >= priority.get(normalized_current, 1):
            return normalized_incoming
        return normalized_current

    def _normalize_user_id(self, user_id: str | None) -> str:
        return (user_id or "").strip()[:128]

    def _to_schema(self, row: NewsArticleRecord) -> NewsArticle:
        image_url = row.image_url
        if image_url is None and row.summary:
            extracted = extract_first_image_from_html(row.summary, base_url=row.url)
            image_url = extracted or None

        comment_count = self._extract_comment_count(row.summary)
        cleaned_summary = self._clean_summary_for_response(row.title, row.summary)

        return NewsArticle(
            id=row.id,
            title=row.title,
            source=row.source,
            category=row.category,
            tags=self._extract_row_tags(row),
            summary=cleaned_summary,
            comment_count=comment_count,
            url=row.url,
            source_domain=row.source_domain,
            source_type=row.source_type,
            image_url=image_url,
            submitted_by=row.submitted_by,
            created_by_user_id=row.created_by_user_id,
            reviewed_by_user_id=row.reviewed_by_user_id,
            published_by_user_id=row.published_by_user_id,
            is_user_generated=row.is_user_generated,
            status=row.status,
            verification_status=row.verification_status,
            is_featured=row.is_featured,
            review_notes=row.review_notes,
            published_at=row.published_at,
            fact_checked=row.fact_checked,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    def _normalize_tags(
        self,
        tags: list[str] | tuple[str, ...] | None,
        *,
        category: str | None = None,
    ) -> list[str]:
        values = list(tags or [])
        if category and category.strip():
            values.insert(0, category.strip())

        normalized: list[str] = []
        seen: set[str] = set()
        for raw in values:
            tag = str(raw or "").strip()
            if not tag:
                continue
            key = tag.lower()
            if key in seen:
                continue
            seen.add(key)
            normalized.append(tag[:120])
        return normalized

    def _replace_article_tags(self, record: NewsArticleRecord, tags: list[str]) -> None:
        record.tags.clear()
        for tag in tags:
            record.tags.append(
                ArticleTagRecord(
                    tag=tag,
                    normalized_tag=tag.lower(),
                )
            )

    def _merge_article_tags(self, record: NewsArticleRecord, tags: list[str]) -> None:
        existing = {tag.normalized_tag for tag in record.tags}
        for tag in self._normalize_tags(tags):
            normalized = tag.lower()
            if normalized in existing:
                continue
            existing.add(normalized)
            record.tags.append(
                ArticleTagRecord(
                    tag=tag,
                    normalized_tag=normalized,
                )
            )

    def _extract_row_tags(self, row: NewsArticleRecord) -> list[str]:
        tags = [tag.tag.strip() for tag in row.tags if tag.tag and tag.tag.strip()]
        if not tags and row.category.strip():
            return [row.category.strip()]
        return tags

    def _exclude_story_ids(
        self,
        stories: list[NewsArticle],
        *,
        excluded_ids: set[str],
    ) -> list[NewsArticle]:
        if not excluded_ids:
            return stories
        return [story for story in stories if story.id not in excluded_ids]

    def _tag_contains_condition(self, normalized_query: str):
        return (
            select(ArticleTagRecord.id)
            .where(
                and_(
                    ArticleTagRecord.article_id == NewsArticleRecord.id,
                    func.lower(ArticleTagRecord.normalized_tag).contains(
                        normalized_query
                    ),
                )
            )
            .exists()
        )

    def _tag_equals_condition(self, normalized_tag: str):
        return (
            select(ArticleTagRecord.id)
            .where(
                and_(
                    ArticleTagRecord.article_id == NewsArticleRecord.id,
                    ArticleTagRecord.normalized_tag == normalized_tag,
                )
            )
            .exists()
        )

    def _clean_summary_for_response(
        self, title: str, summary: str | None
    ) -> str | None:
        excerpt = plain_text_excerpt(summary)
        if excerpt is None:
            return None

        normalized_title = self._normalize_comparison_text(title)
        normalized_summary = self._normalize_comparison_text(excerpt)
        if not normalized_summary:
            return None
        if normalized_summary == normalized_title:
            return None
        if normalized_summary.startswith(normalized_title):
            remainder = normalized_summary[len(normalized_title) :].strip()
            if not remainder or len(remainder) <= 16:
                return None
        return excerpt

    def _normalize_comparison_text(self, value: str | None) -> str:
        if value is None:
            return ""
        normalized = re.sub(r"<[^>]*>", " ", value)
        normalized = unescape(normalized)
        normalized = normalized.lower()
        normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
        return re.sub(r"\s+", " ", normalized).strip()

    def _is_row_stale(self, row: NewsArticleRecord, *, now: datetime | None = None) -> bool:
        published_at = row.published_at
        if published_at is None:
            return True

        current_time = now or datetime.utcnow()
        if published_at > current_time:
            return False
        age = current_time - published_at
        return age > self._stale_window_for_category(row.category)

    def _stale_window_for_category(self, category: str | None) -> timedelta:
        normalized = (category or "").strip().lower()
        if "breaking" in normalized:
            return timedelta(hours=18)
        if "politic" in normalized or "election" in normalized:
            return timedelta(hours=48)
        if "business" in normalized or "econom" in normalized or "finance" in normalized:
            return timedelta(hours=48)
        if "sport" in normalized:
            return timedelta(hours=30)
        if "tech" in normalized:
            return timedelta(hours=72)
        if "entertain" in normalized or "music" in normalized or "lifestyle" in normalized:
            return timedelta(hours=72)
        if "opinion" in normalized or "analysis" in normalized:
            return timedelta(days=7)
        return timedelta(hours=36)

    def _extract_comment_count(self, summary: str | None) -> int | None:
        if summary is None or not summary.strip():
            return None

        text = re.sub(r"<[^>]*>", " ", summary)
        text = unescape(text)
        text = re.sub(r"\s+", " ", text).strip().lower()

        match = re.search(r"\b(\d{1,6})\s+comments?\b", text)
        if match is None:
            return None

        try:
            count = int(match.group(1))
        except ValueError:
            return None

        if count <= 0:
            return None
        return count

