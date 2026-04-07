import re
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.db.models import (
    LiveUpdateEntryRecord,
    LiveUpdatePageRecord,
    NewsArticleRecord,
    PollRecord,
    UserRecord,
)
from app.schemas.live_updates import (
    CreateLiveUpdateEntryRequest,
    CreateLiveUpdatePageRequest,
    LiveUpdateAuthor,
    LiveUpdateEntry,
    LiveUpdatePageDetail,
    LiveUpdatePageListResponse,
    LiveUpdatePageSummary,
    UpdateLiveUpdateEntryRequest,
    UpdateLiveUpdatePageRequest,
)
from app.schemas.polls import Poll, PollOption
from app.services.news_service import NewsService


class MissingLiveUpdatesContextError(Exception):
    pass


class LiveUpdatesPermissionError(Exception):
    pass


class LiveUpdateNotFoundError(Exception):
    pass


class LiveUpdateValidationError(Exception):
    pass


class LiveUpdatesService:
    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        news_service: NewsService,
    ) -> None:
        self._session_factory = session_factory
        self._news_service = news_service

    async def list_public_pages(
        self,
        *,
        status: str | None = None,
        limit: int = 20,
    ) -> LiveUpdatePageListResponse:
        normalized_status = self._normalize_status(status, allow_none=True)
        allowed_statuses = (
            [normalized_status]
            if normalized_status is not None
            else ["live", "ended"]
        )
        async with self._session_factory() as session:
            result = await session.execute(
                select(LiveUpdatePageRecord)
                .options(selectinload(LiveUpdatePageRecord.entries))
                .where(LiveUpdatePageRecord.status.in_(allowed_statuses))
                .order_by(
                    LiveUpdatePageRecord.is_featured.desc(),
                    LiveUpdatePageRecord.is_breaking.desc(),
                    LiveUpdatePageRecord.last_published_entry_at.desc(),
                    LiveUpdatePageRecord.created_at.desc(),
                )
                .limit(limit)
            )
            rows = result.scalars().all()
            items = [
                self._to_page_summary(row, visible_only=True)
                for row in rows
            ]
            return LiveUpdatePageListResponse(items=items, total=len(items))

    async def get_public_page(
        self,
        *,
        slug: str,
        after: datetime | None = None,
    ) -> LiveUpdatePageDetail:
        normalized_slug = self._normalize_slug(slug)
        if not normalized_slug:
            raise LiveUpdateNotFoundError("Live update page was not specified.")

        async with self._session_factory() as session:
            page = await self._load_page_by_slug(
                session,
                slug=normalized_slug,
                public_only=True,
            )
            entries = self._sorted_entries(
                page.entries,
                visible_only=True,
                after=after,
            )
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=True),
                entries=[self._to_entry_schema(item) for item in entries],
            )

    async def list_admin_pages(
        self,
        *,
        actor_user_id: str | None,
        status: str | None = None,
        limit: int = 50,
    ) -> LiveUpdatePageListResponse:
        normalized_status = self._normalize_status(status, allow_none=True)
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id)
            statement = (
                select(LiveUpdatePageRecord)
                .options(selectinload(LiveUpdatePageRecord.entries))
                .order_by(
                    LiveUpdatePageRecord.updated_at.desc(),
                    LiveUpdatePageRecord.created_at.desc(),
                )
                .limit(limit)
            )
            if normalized_status is not None:
                statement = statement.where(LiveUpdatePageRecord.status == normalized_status)
            result = await session.execute(statement)
            rows = result.scalars().all()
            items = [
                self._to_page_summary(row, visible_only=False)
                for row in rows
            ]
            return LiveUpdatePageListResponse(items=items, total=len(items))

    async def get_admin_page(
        self,
        *,
        actor_user_id: str | None,
        page_id: str,
    ) -> LiveUpdatePageDetail:
        normalized_page_id = page_id.strip()
        if not normalized_page_id:
            raise LiveUpdateNotFoundError("Live update page was not specified.")

        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id)
            page = await self._load_page_by_id(session, page_id=normalized_page_id)
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=False),
                entries=[
                    self._to_entry_schema(item)
                    for item in self._sorted_entries(page.entries, visible_only=False)
                ],
            )

    async def create_page(
        self,
        *,
        actor_user_id: str | None,
        payload: CreateLiveUpdatePageRequest,
    ) -> LiveUpdatePageDetail:
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id)
            now = datetime.utcnow()
            status = self._normalize_status(payload.status)
            slug = await self._ensure_unique_slug(
                session,
                desired_slug=payload.slug,
                title=payload.title,
            )
            page = LiveUpdatePageRecord(
                id=f"live-{uuid4().hex[:12]}",
                slug=slug,
                title=payload.title.strip(),
                summary=payload.summary.strip(),
                hero_kicker=self._clean_optional(payload.hero_kicker),
                category=payload.category.strip(),
                cover_image_url=self._clean_optional(payload.cover_image_url),
                status=status,
                is_featured=payload.is_featured,
                is_breaking=payload.is_breaking,
                started_at=self._normalize_datetime(payload.started_at)
                if payload.started_at is not None
                else None,
                ended_at=self._normalize_datetime(payload.ended_at)
                if payload.ended_at is not None
                else None,
                created_by_user_id=actor.id,
                updated_by_user_id=actor.id,
                created_at=now,
                updated_at=now,
            )
            self._apply_page_status_defaults(page, now=now)
            session.add(page)
            await session.commit()
            await session.refresh(page)
            page = await self._load_page_by_id(session, page_id=page.id)
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=False),
                entries=[],
            )

    async def update_page(
        self,
        *,
        actor_user_id: str | None,
        page_id: str,
        payload: UpdateLiveUpdatePageRequest,
    ) -> LiveUpdatePageDetail:
        changes = payload.model_dump(exclude_unset=True)
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id)
            page = await self._load_page_by_id(session, page_id=page_id.strip())
            if "title" in changes:
                page.title = payload.title.strip()
            if "summary" in changes:
                page.summary = payload.summary.strip()
            if "slug" in changes:
                page.slug = await self._ensure_unique_slug(
                    session,
                    desired_slug=payload.slug,
                    title=payload.title or page.title,
                    page_id=page.id,
                )
            if "hero_kicker" in changes:
                page.hero_kicker = self._clean_optional(payload.hero_kicker)
            if "category" in changes:
                page.category = payload.category.strip()
            if "cover_image_url" in changes:
                page.cover_image_url = self._clean_optional(payload.cover_image_url)
            if "status" in changes and payload.status is not None:
                page.status = self._normalize_status(payload.status)
            if "is_featured" in changes:
                page.is_featured = bool(payload.is_featured)
            if "is_breaking" in changes:
                page.is_breaking = bool(payload.is_breaking)
            if "started_at" in changes:
                page.started_at = (
                    self._normalize_datetime(payload.started_at)
                    if payload.started_at is not None
                    else None
                )
            if "ended_at" in changes:
                page.ended_at = (
                    self._normalize_datetime(payload.ended_at)
                    if payload.ended_at is not None
                    else None
                )
            page.updated_by_user_id = actor.id
            page.updated_at = datetime.utcnow()
            self._apply_page_status_defaults(page, now=page.updated_at)
            await session.commit()
            page = await self._load_page_by_id(session, page_id=page.id)
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=False),
                entries=[
                    self._to_entry_schema(item)
                    for item in self._sorted_entries(page.entries, visible_only=False)
                ],
            )

    async def create_entry(
        self,
        *,
        actor_user_id: str | None,
        page_id: str,
        payload: CreateLiveUpdateEntryRequest,
    ) -> LiveUpdatePageDetail:
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id)
            page = await self._load_page_by_id(session, page_id=page_id.strip())
            block_type = self._normalize_block_type(payload.block_type)
            article, poll = await self._resolve_entry_links(
                session,
                linked_article_id=payload.linked_article_id,
                linked_poll_id=payload.linked_poll_id,
            )
            self._validate_entry_payload(
                block_type=block_type,
                headline=payload.headline,
                body=payload.body,
                image_url=payload.image_url,
                linked_article=article,
                linked_poll=poll,
            )
            published_at = self._normalize_datetime(payload.published_at) or datetime.utcnow()
            entry = LiveUpdateEntryRecord(
                id=f"live-entry-{uuid4().hex[:12]}",
                page_id=page.id,
                block_type=block_type,
                headline=self._clean_optional(payload.headline),
                body=self._clean_optional(payload.body),
                image_url=self._clean_optional(payload.image_url),
                image_caption=self._clean_optional(payload.image_caption),
                linked_article_id=article.id if article is not None else None,
                linked_poll_id=poll.id if poll is not None else None,
                published_at=published_at,
                display_order=0,
                is_pinned=payload.is_pinned,
                is_visible=payload.is_visible,
                created_by_user_id=actor.id,
                updated_by_user_id=actor.id,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
            session.add(entry)
            page.entries.append(entry)
            await session.flush()
            await self._refresh_page_timestamps(session, page)
            await session.commit()
            page = await self._load_page_by_id(session, page_id=page.id)
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=False),
                entries=[
                    self._to_entry_schema(item)
                    for item in self._sorted_entries(page.entries, visible_only=False)
                ],
            )

    async def update_entry(
        self,
        *,
        actor_user_id: str | None,
        entry_id: str,
        payload: UpdateLiveUpdateEntryRequest,
    ) -> LiveUpdatePageDetail:
        changes = payload.model_dump(exclude_unset=True)
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id)
            entry = await self._load_entry(session, entry_id=entry_id.strip())
            article = entry.article
            poll = entry.poll
            if "linked_article_id" in changes or "linked_poll_id" in changes:
                article, poll = await self._resolve_entry_links(
                    session,
                    linked_article_id=payload.linked_article_id
                    if "linked_article_id" in changes
                    else entry.linked_article_id,
                    linked_poll_id=payload.linked_poll_id
                    if "linked_poll_id" in changes
                    else entry.linked_poll_id,
                )
            next_headline = (
                payload.headline if "headline" in changes else entry.headline
            )
            next_body = payload.body if "body" in changes else entry.body
            next_image_url = (
                payload.image_url if "image_url" in changes else entry.image_url
            )
            self._validate_entry_payload(
                block_type=entry.block_type,
                headline=next_headline,
                body=next_body,
                image_url=next_image_url,
                linked_article=article,
                linked_poll=poll,
            )
            if "headline" in changes:
                entry.headline = self._clean_optional(payload.headline)
            if "body" in changes:
                entry.body = self._clean_optional(payload.body)
            if "image_url" in changes:
                entry.image_url = self._clean_optional(payload.image_url)
            if "image_caption" in changes:
                entry.image_caption = self._clean_optional(payload.image_caption)
            if "linked_article_id" in changes:
                entry.linked_article_id = article.id if article is not None else None
            if "linked_poll_id" in changes:
                entry.linked_poll_id = poll.id if poll is not None else None
            if "published_at" in changes:
                entry.published_at = self._normalize_datetime(payload.published_at) or entry.published_at
            if "is_pinned" in changes and payload.is_pinned is not None:
                entry.is_pinned = payload.is_pinned
            if "is_visible" in changes and payload.is_visible is not None:
                entry.is_visible = payload.is_visible
            entry.updated_by_user_id = actor.id
            entry.updated_at = datetime.utcnow()
            await self._refresh_page_timestamps(session, entry.page)
            await session.commit()
            page = await self._load_page_by_id(session, page_id=entry.page_id)
            return LiveUpdatePageDetail(
                page=self._to_page_summary(page, visible_only=False),
                entries=[
                    self._to_entry_schema(item)
                    for item in self._sorted_entries(page.entries, visible_only=False)
                ],
            )

    async def _load_actor(
        self,
        session: AsyncSession,
        actor_user_id: str | None,
    ) -> UserRecord:
        normalized_actor = (actor_user_id or "").strip()
        if not normalized_actor:
            raise MissingLiveUpdatesContextError("Admin context header is required.")
        result = await session.execute(
            select(UserRecord).where(UserRecord.id == normalized_actor)
        )
        actor = result.scalar_one_or_none()
        if actor is None:
            raise LiveUpdateNotFoundError(f"Actor '{normalized_actor}' does not exist.")
        if actor.role not in {"admin", "editor"}:
            raise LiveUpdatesPermissionError(
                "Only editors and admins can manage live updates."
            )
        if not actor.is_active:
            raise LiveUpdatesPermissionError("This account is inactive.")
        return actor

    async def _load_page_by_id(
        self,
        session: AsyncSession,
        *,
        page_id: str,
    ) -> LiveUpdatePageRecord:
        if not page_id:
            raise LiveUpdateNotFoundError("Live update page was not specified.")
        result = await session.execute(
            select(LiveUpdatePageRecord)
            .options(
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.article),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.poll)
                .selectinload(PollRecord.options),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.poll)
                .selectinload(PollRecord.category),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.created_by),
            )
            .where(LiveUpdatePageRecord.id == page_id)
        )
        page = result.scalar_one_or_none()
        if page is None:
            raise LiveUpdateNotFoundError(f"Live update page '{page_id}' does not exist.")
        return page

    async def _load_page_by_slug(
        self,
        session: AsyncSession,
        *,
        slug: str,
        public_only: bool,
    ) -> LiveUpdatePageRecord:
        statement = (
            select(LiveUpdatePageRecord)
            .options(
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.article),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.poll)
                .selectinload(PollRecord.options),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.poll)
                .selectinload(PollRecord.category),
                selectinload(LiveUpdatePageRecord.entries)
                .selectinload(LiveUpdateEntryRecord.created_by),
            )
            .where(LiveUpdatePageRecord.slug == slug)
        )
        if public_only:
            statement = statement.where(LiveUpdatePageRecord.status.in_(("live", "ended")))
        result = await session.execute(statement)
        page = result.scalar_one_or_none()
        if page is None:
            raise LiveUpdateNotFoundError(f"Live update page '{slug}' does not exist.")
        return page

    async def _load_entry(
        self,
        session: AsyncSession,
        *,
        entry_id: str,
    ) -> LiveUpdateEntryRecord:
        if not entry_id:
            raise LiveUpdateNotFoundError("Live update entry was not specified.")
        result = await session.execute(
            select(LiveUpdateEntryRecord)
            .options(
                selectinload(LiveUpdateEntryRecord.page).selectinload(
                    LiveUpdatePageRecord.entries
                ),
                selectinload(LiveUpdateEntryRecord.article),
                selectinload(LiveUpdateEntryRecord.poll).selectinload(
                    PollRecord.options
                ),
                selectinload(LiveUpdateEntryRecord.poll).selectinload(
                    PollRecord.category
                ),
            )
            .where(LiveUpdateEntryRecord.id == entry_id)
        )
        entry = result.scalar_one_or_none()
        if entry is None:
            raise LiveUpdateNotFoundError(f"Live update entry '{entry_id}' does not exist.")
        return entry

    async def _ensure_unique_slug(
        self,
        session: AsyncSession,
        *,
        desired_slug: str | None,
        title: str,
        page_id: str | None = None,
    ) -> str:
        base_slug = self._normalize_slug(desired_slug or title)
        if not base_slug:
            raise LiveUpdateValidationError("Live update slug could not be generated.")
        candidate = base_slug
        suffix = 2
        while True:
            result = await session.execute(
                select(LiveUpdatePageRecord).where(LiveUpdatePageRecord.slug == candidate)
            )
            existing = result.scalar_one_or_none()
            if existing is None or existing.id == page_id:
                return candidate
            candidate = f"{base_slug}-{suffix}"
            suffix += 1

    async def _resolve_entry_links(
        self,
        session: AsyncSession,
        *,
        linked_article_id: str | None,
        linked_poll_id: str | None,
    ) -> tuple[NewsArticleRecord | None, PollRecord | None]:
        article: NewsArticleRecord | None = None
        poll: PollRecord | None = None
        normalized_article_id = self._clean_optional(linked_article_id)
        normalized_poll_id = self._clean_optional(linked_poll_id)
        if normalized_article_id is not None:
            article_result = await session.execute(
                select(NewsArticleRecord)
                .where(
                    NewsArticleRecord.id == normalized_article_id,
                    NewsArticleRecord.status == "published",
                )
            )
            article = article_result.scalar_one_or_none()
            if article is None:
                raise LiveUpdateValidationError(
                    f"Article '{normalized_article_id}' does not exist or is not published."
                )
        if normalized_poll_id is not None:
            poll_result = await session.execute(
                select(PollRecord)
                .options(
                    selectinload(PollRecord.options),
                    selectinload(PollRecord.category),
                )
                .where(PollRecord.id == normalized_poll_id)
            )
            poll = poll_result.scalar_one_or_none()
            if poll is None:
                raise LiveUpdateValidationError(
                    f"Poll '{normalized_poll_id}' does not exist."
                )
        return article, poll

    def _validate_entry_payload(
        self,
        *,
        block_type: str,
        headline: str | None,
        body: str | None,
        image_url: str | None,
        linked_article: NewsArticleRecord | None,
        linked_poll: PollRecord | None,
    ) -> None:
        clean_headline = self._clean_optional(headline)
        clean_body = self._clean_optional(body)
        clean_image_url = self._clean_optional(image_url)

        if block_type == "text" and clean_body is None:
            raise LiveUpdateValidationError("Text updates require body content.")
        if block_type == "image" and clean_image_url is None:
            raise LiveUpdateValidationError("Image updates require an image URL.")
        if block_type == "article_embed" and linked_article is None:
            raise LiveUpdateValidationError("Article embeds require a linked article.")
        if block_type == "poll_embed" and linked_poll is None:
            raise LiveUpdateValidationError("Poll embeds require a linked poll.")
        if block_type == "milestone" and clean_headline is None:
            raise LiveUpdateValidationError("Milestones require a headline.")

        if block_type != "image" and clean_image_url is not None:
            raise LiveUpdateValidationError(
                "Image URLs are only allowed on image blocks."
            )
        if block_type != "article_embed" and linked_article is not None:
            raise LiveUpdateValidationError(
                "Linked articles are only allowed on article embed blocks."
            )
        if block_type != "poll_embed" and linked_poll is not None:
            raise LiveUpdateValidationError(
                "Linked polls are only allowed on poll embed blocks."
            )

    async def _refresh_page_timestamps(
        self,
        session: AsyncSession,
        page: LiveUpdatePageRecord,
    ) -> None:
        visible_entries = [
            entry for entry in page.entries if entry.is_visible
        ]
        if visible_entries:
            latest = max(visible_entries, key=lambda item: item.published_at)
            page.last_published_entry_at = latest.published_at
        else:
            page.last_published_entry_at = None
        page.updated_at = datetime.utcnow()
        await session.flush()

    def _apply_page_status_defaults(
        self,
        page: LiveUpdatePageRecord,
        *,
        now: datetime,
    ) -> None:
        if page.status == "live":
            page.started_at = page.started_at or now
            if page.ended_at is not None and page.ended_at <= page.started_at:
                page.ended_at = None
        elif page.status in {"ended", "archived"}:
            page.started_at = page.started_at or now
            page.ended_at = page.ended_at or now

    def _to_page_summary(
        self,
        page: LiveUpdatePageRecord,
        *,
        visible_only: bool,
    ) -> LiveUpdatePageSummary:
        entries = self._sorted_entries(page.entries, visible_only=visible_only)
        return LiveUpdatePageSummary(
            id=page.id,
            slug=page.slug,
            title=page.title,
            summary=page.summary,
            hero_kicker=page.hero_kicker,
            category=page.category,
            cover_image_url=page.cover_image_url,
            status=page.status,
            is_featured=page.is_featured,
            is_breaking=page.is_breaking,
            started_at=page.started_at,
            ended_at=page.ended_at,
            last_published_entry_at=page.last_published_entry_at,
            created_at=page.created_at,
            updated_at=page.updated_at,
            entry_count=len(entries),
        )

    def _to_entry_schema(self, entry: LiveUpdateEntryRecord) -> LiveUpdateEntry:
        article = (
            self._news_service._to_schema(entry.article)
            if entry.article is not None
            else None
        )
        poll = self._to_poll_schema(entry.poll) if entry.poll is not None else None
        author = None
        if entry.created_by is not None:
            author = LiveUpdateAuthor(
                id=entry.created_by.id,
                display_name=entry.created_by.display_name
                or entry.created_by.email
                or "Editorial Desk",
            )
        return LiveUpdateEntry(
            id=entry.id,
            page_id=entry.page_id,
            block_type=entry.block_type,
            headline=entry.headline,
            body=entry.body,
            image_url=entry.image_url,
            image_caption=entry.image_caption,
            linked_article=article,
            linked_poll=poll,
            published_at=entry.published_at,
            is_pinned=entry.is_pinned,
            is_visible=entry.is_visible,
            author=author,
            created_at=entry.created_at,
            updated_at=entry.updated_at,
        )

    def _to_poll_schema(self, poll: PollRecord) -> Poll:
        options = [
            PollOption(
                id=option.option_id,
                label=option.label,
                votes=option.votes,
            )
            for option in sorted(
                poll.options,
                key=lambda item: (item.position, item.id),
            )
        ]
        return Poll(
            id=poll.id,
            question=poll.question,
            category_id=poll.category_id,
            category_name=poll.category.name if poll.category is not None else None,
            options=options,
            ends_at=poll.ends_at,
            has_voted=False,
            selected_option_id=None,
        )

    def _sorted_entries(
        self,
        entries: list[LiveUpdateEntryRecord],
        *,
        visible_only: bool,
        after: datetime | None = None,
    ) -> list[LiveUpdateEntryRecord]:
        filtered = [
            entry
            for entry in entries
            if (entry.is_visible or not visible_only)
            and (after is None or entry.published_at > after)
        ]
        return sorted(
            filtered,
            key=lambda item: (
                1 if item.is_pinned else 0,
                item.published_at,
                item.created_at,
            ),
            reverse=True,
        )

    def _normalize_status(
        self,
        value: str | None,
        *,
        allow_none: bool = False,
    ) -> str | None:
        normalized = (value or "").strip().lower()
        if not normalized:
            if allow_none:
                return None
            return "draft"
        allowed = {"draft", "live", "ended", "archived"}
        if normalized not in allowed:
            raise LiveUpdateValidationError(
                f"Unsupported live update status '{value}'."
            )
        return normalized

    def _normalize_block_type(self, value: str) -> str:
        normalized = value.strip().lower()
        allowed = {"text", "image", "article_embed", "poll_embed", "milestone"}
        if normalized not in allowed:
            raise LiveUpdateValidationError(
                f"Unsupported live update block type '{value}'."
            )
        return normalized

    def _normalize_slug(self, value: str | None) -> str:
        normalized = re.sub(r"[^a-z0-9]+", "-", (value or "").strip().lower()).strip("-")
        return normalized[:160]

    def _normalize_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=None)
        return value.astimezone(timezone.utc).replace(tzinfo=None)

    def _clean_optional(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        return normalized or None
