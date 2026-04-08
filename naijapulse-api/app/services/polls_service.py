import asyncio
import re
from datetime import datetime, timezone
from uuid import uuid4
from typing import List

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.db.models import (
    CategoryRecord,
    FeedTagRecord,
    PollOptionRecord,
    PollRecord,
    PollVoteRecord,
    UserRecord,
)
from app.schemas.categories import Category
from app.schemas.polls import CreatePollRequest, Poll, PollOption
from app.schemas.tags import FeedTag


class PollNotFoundError(Exception):
    pass


class InvalidPollOptionError(Exception):
    pass


class InvalidPollPayloadError(Exception):
    pass


class CategoryAlreadyExistsError(Exception):
    pass


class CategoryNotFoundError(Exception):
    pass


class FeedTagAlreadyExistsError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class PollsService:
    """Polls domain service backed by Postgres."""

    _DEFAULT_CATEGORIES = (
        ("world-news", "World News", "#C62828"),
        ("business", "Business", "#1E3A8A"),
        ("technology", "Technology", "#0F766E"),
        ("entertainment", "Entertainment", "#7C3AED"),
        ("science", "Science", "#2563EB"),
        ("sports", "Sports", "#F97316"),
        ("health", "Health", "#0F9D58"),
        ("general", "General", "#475569"),
    )
    _DEFAULT_FEED_TAGS = (
        ("fact-checked", "Fact-Checked", "#1B8B63", 10),
        ("live-updates", "Live Updates", "#EE6C22", 20),
        ("election-2027", "Election 2027", "#1A9C5A", 30),
    )

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory
        self._lock = asyncio.Lock()

    async def initialize_defaults(self) -> None:
        """Ensure base categories are present and aligned for filters/polls."""
        async with self._session_factory() as session:
            existing_result = await session.execute(select(CategoryRecord))
            existing_map = {row.id: row for row in existing_result.scalars().all()}
            changed = False

            for category_id, name, color_hex in self._DEFAULT_CATEGORIES:
                existing = existing_map.get(category_id)
                if existing is None:
                    session.add(
                        CategoryRecord(
                            id=category_id,
                            name=name,
                            color_hex=color_hex,
                            description=None,
                        )
                    )
                    changed = True
                    continue

                # Keep seeded category naming/colors stable across restarts/migrations.
                if existing.name != name:
                    existing.name = name
                    changed = True
                if existing.color_hex != color_hex:
                    existing.color_hex = color_hex
                    changed = True

            existing_tags_result = await session.execute(select(FeedTagRecord))
            existing_tags_map = {row.id: row for row in existing_tags_result.scalars().all()}

            for tag_id, name, color_hex, position in self._DEFAULT_FEED_TAGS:
                existing_tag = existing_tags_map.get(tag_id)
                if existing_tag is None:
                    session.add(
                        FeedTagRecord(
                            id=tag_id,
                            name=name,
                            color_hex=color_hex,
                            description=None,
                            position=position,
                            is_active=True,
                        )
                    )
                    changed = True
                    continue

                # Keep seeded feed tags stable and visible for client tag strip.
                if existing_tag.name != name:
                    existing_tag.name = name
                    changed = True
                if existing_tag.color_hex != color_hex:
                    existing_tag.color_hex = color_hex
                    changed = True
                if existing_tag.position != position:
                    existing_tag.position = position
                    changed = True
                if not existing_tag.is_active:
                    existing_tag.is_active = True
                    changed = True

            if changed:
                await session.commit()

    async def list_categories(self) -> List[Category]:
        async with self._session_factory() as session:
            result = await session.execute(
                select(CategoryRecord).order_by(CategoryRecord.name.asc())
            )
            rows = result.scalars().all()
            return [self._to_category_schema(row) for row in rows]

    async def create_category(
        self,
        *,
        name: str,
        color_hex: str | None = None,
        description: str | None = None,
        category_id: str | None = None,
    ) -> Category:
        normalized_name = name.strip()
        if len(normalized_name) < 2:
            raise InvalidPollPayloadError("Category name must be at least 2 characters.")

        normalized_id = self._normalize_category_id(category_id, normalized_name)
        normalized_color_hex = self._normalize_color_hex(color_hex)
        normalized_description = (description or "").strip() or None

        async with self._session_factory() as session:
            existing_name_result = await session.execute(
                select(CategoryRecord).where(
                    func.lower(CategoryRecord.name) == normalized_name.lower()
                )
            )
            if existing_name_result.scalar_one_or_none() is not None:
                raise CategoryAlreadyExistsError(
                    f"Category '{normalized_name}' already exists."
                )

            existing_id_result = await session.execute(
                select(CategoryRecord).where(CategoryRecord.id == normalized_id)
            )
            if existing_id_result.scalar_one_or_none() is not None:
                raise CategoryAlreadyExistsError(
                    f"Category id '{normalized_id}' already exists."
                )

            record = CategoryRecord(
                id=normalized_id,
                name=normalized_name,
                color_hex=normalized_color_hex,
                description=normalized_description,
            )
            session.add(record)
            await session.commit()
            return self._to_category_schema(record)

    async def list_feed_tags(self) -> List[FeedTag]:
        async with self._session_factory() as session:
            result = await session.execute(
                select(FeedTagRecord)
                .where(FeedTagRecord.is_active.is_(True))
                .order_by(FeedTagRecord.position.asc(), FeedTagRecord.name.asc())
            )
            rows = result.scalars().all()
            return [self._to_feed_tag_schema(row) for row in rows]

    async def create_feed_tag(
        self,
        *,
        name: str,
        color_hex: str | None = None,
        description: str | None = None,
        tag_id: str | None = None,
        position: int = 0,
        is_active: bool = True,
    ) -> FeedTag:
        normalized_name = name.strip()
        if len(normalized_name) < 2:
            raise InvalidPollPayloadError("Tag name must be at least 2 characters.")

        normalized_id = self._normalize_tag_id(tag_id, normalized_name)
        normalized_color_hex = self._normalize_color_hex(color_hex)
        normalized_description = (description or "").strip() or None
        normalized_position = max(0, int(position))

        async with self._session_factory() as session:
            existing_name_result = await session.execute(
                select(FeedTagRecord).where(
                    func.lower(FeedTagRecord.name) == normalized_name.lower()
                )
            )
            if existing_name_result.scalar_one_or_none() is not None:
                raise FeedTagAlreadyExistsError(f"Tag '{normalized_name}' already exists.")

            existing_id_result = await session.execute(
                select(FeedTagRecord).where(FeedTagRecord.id == normalized_id)
            )
            if existing_id_result.scalar_one_or_none() is not None:
                raise FeedTagAlreadyExistsError(
                    f"Tag id '{normalized_id}' already exists."
                )

            record = FeedTagRecord(
                id=normalized_id,
                name=normalized_name,
                color_hex=normalized_color_hex,
                description=normalized_description,
                position=normalized_position,
                is_active=is_active,
            )
            session.add(record)
            await session.commit()
            return self._to_feed_tag_schema(record)

    async def create_poll(
        self,
        *,
        payload: CreatePollRequest,
        created_by: str | None = None,
    ) -> Poll:
        question = payload.question.strip()
        if len(question) < 8:
            raise InvalidPollPayloadError("Poll question must be at least 8 characters.")

        ends_at = self._normalize_datetime(payload.ends_at)
        if ends_at <= datetime.utcnow():
            raise InvalidPollPayloadError("Poll end time must be in the future.")

        options = payload.options
        if len(options) < 2:
            raise InvalidPollPayloadError("Poll must include at least 2 options.")

        seen_option_ids: set[str] = set()
        normalized_options: list[tuple[str, str]] = []
        for index, option in enumerate(options):
            option_id = option.id.strip().lower()
            label = option.label.strip()
            if not option_id:
                raise InvalidPollPayloadError(
                    f"Option at position {index + 1} has an empty id."
                )
            if not label:
                raise InvalidPollPayloadError(
                    f"Option '{option.id}' has an empty label."
                )
            if option_id in seen_option_ids:
                raise InvalidPollPayloadError(
                    f"Duplicate option id '{option_id}' in poll options."
                )
            seen_option_ids.add(option_id)
            normalized_options.append((option_id[:80], label[:255]))

        normalized_category_id = (payload.category_id or "").strip() or None
        normalized_created_by = self._normalize_voter_id(created_by)

        async with self._session_factory() as session:
            if normalized_category_id is not None:
                category_result = await session.execute(
                    select(CategoryRecord).where(CategoryRecord.id == normalized_category_id)
                )
                if category_result.scalar_one_or_none() is None:
                    raise CategoryNotFoundError(
                        f"Category '{normalized_category_id}' does not exist."
                    )
            if normalized_created_by is not None:
                await self._assert_user_exists(session, normalized_created_by)

            poll_id = f"poll-{uuid4().hex[:12]}"
            poll = PollRecord(
                id=poll_id,
                question=question,
                category_id=normalized_category_id,
                created_by=normalized_created_by,
                ends_at=ends_at,
                options=[
                    PollOptionRecord(
                        poll_id=poll_id,
                        option_id=option_id,
                        label=label,
                        votes=0,
                        position=position,
                    )
                    for position, (option_id, label) in enumerate(normalized_options)
                ],
            )
            session.add(poll)
            await session.commit()
            return self._to_schema(poll)

    async def get_active_polls(self) -> List[Poll]:
        # Stored timestamps are naive UTC; compare using naive utcnow().
        now = datetime.utcnow()
        async with self._session_factory() as session:
            result = await session.execute(
                select(PollRecord)
                .options(selectinload(PollRecord.options))
                .where(PollRecord.ends_at > now)
                .order_by(PollRecord.ends_at.asc())
            )
            polls = result.scalars().all()
            return [self._to_schema(poll) for poll in polls]

    async def get_poll(self, poll_id: str) -> Poll:
        async with self._session_factory() as session:
            result = await session.execute(
                select(PollRecord)
                .options(selectinload(PollRecord.options))
                .where(PollRecord.id == poll_id)
            )
            poll = result.scalar_one_or_none()
            if poll is None:
                raise PollNotFoundError(f"Poll '{poll_id}' does not exist.")
            return self._to_schema(poll)

    async def vote(
        self,
        *,
        poll_id: str,
        option_id: str,
        idempotency_key: str | None = None,
        voter_id: str | None = None,
        user_id: str | None = None,
    ) -> tuple[Poll, str]:
        # Lock ensures vote increments are consistent under concurrent requests.
        async with self._lock:
            async with self._session_factory() as session:
                normalized_idempotency_key = self._normalize_idempotency_key(
                    idempotency_key
                )
                normalized_voter_id = self._normalize_voter_id(voter_id)
                normalized_user_id = self._normalize_voter_id(user_id)

                if normalized_user_id is not None:
                    await self._assert_user_exists(session, normalized_user_id)

                existing_by_key = await session.execute(
                    select(PollVoteRecord).where(
                        PollVoteRecord.idempotency_key == normalized_idempotency_key
                    )
                )
                idempotent_vote = existing_by_key.scalar_one_or_none()
                if idempotent_vote is not None:
                    poll = await self._load_poll(session, idempotent_vote.poll_id)
                    return (
                        self._to_schema(
                            poll,
                            has_voted=True,
                            selected_option_id=idempotent_vote.option_id,
                        ),
                        "idempotent",
                    )

                result = await session.execute(
                    select(PollRecord)
                    .options(selectinload(PollRecord.options))
                    .where(PollRecord.id == poll_id)
                )
                poll = result.scalar_one_or_none()
                if poll is None:
                    raise PollNotFoundError(f"Poll '{poll_id}' does not exist.")

                if normalized_voter_id is not None:
                    existing_by_voter = await session.execute(
                        select(PollVoteRecord).where(
                            PollVoteRecord.poll_id == poll_id,
                            PollVoteRecord.voter_id == normalized_voter_id,
                        )
                    )
                    voter_vote = existing_by_voter.scalar_one_or_none()
                    if voter_vote is not None:
                        return (
                            self._to_schema(
                                poll,
                                has_voted=True,
                                selected_option_id=voter_vote.option_id,
                            ),
                            "already_voted",
                        )
                if normalized_user_id is not None:
                    existing_by_user = await session.execute(
                        select(PollVoteRecord).where(
                            PollVoteRecord.poll_id == poll_id,
                            PollVoteRecord.user_id == normalized_user_id,
                        )
                    )
                    user_vote = existing_by_user.scalar_one_or_none()
                    if user_vote is not None:
                        return (
                            self._to_schema(
                                poll,
                                has_voted=True,
                                selected_option_id=user_vote.option_id,
                            ),
                            "already_voted",
                        )

                if poll.ends_at <= datetime.utcnow():
                    return (self._to_schema(poll), "closed")

                selected_option = next(
                    (option for option in poll.options if option.option_id == option_id),
                    None,
                )
                if selected_option is None:
                    raise InvalidPollOptionError(
                        f"Option '{option_id}' does not exist in poll '{poll_id}'."
                    )

                selected_option.votes += 1
                session.add(
                    PollVoteRecord(
                        poll_id=poll_id,
                        option_id=option_id,
                        voter_id=normalized_voter_id,
                        user_id=normalized_user_id,
                        idempotency_key=normalized_idempotency_key,
                    )
                )
                await session.commit()
                return (
                    self._to_schema(
                        poll,
                        has_voted=True,
                        selected_option_id=option_id,
                    ),
                    "applied",
                )

    async def _load_poll(self, session: AsyncSession, poll_id: str) -> PollRecord:
        result = await session.execute(
            select(PollRecord)
            .options(selectinload(PollRecord.options))
            .where(PollRecord.id == poll_id)
        )
        poll = result.scalar_one_or_none()
        if poll is None:
            raise PollNotFoundError(f"Poll '{poll_id}' does not exist.")
        return poll

    async def _assert_user_exists(self, session: AsyncSession, user_id: str) -> None:
        user_result = await session.execute(
            select(UserRecord).where(UserRecord.id == user_id)
        )
        if user_result.scalar_one_or_none() is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")

    def _normalize_idempotency_key(self, key: str | None) -> str:
        normalized = (key or "").strip()
        if normalized:
            return normalized[:160]
        # Fallback for clients that have not yet rolled out idempotency keys.
        return f"server-{uuid4()}"

    def _normalize_voter_id(self, voter_id: str | None) -> str | None:
        normalized = (voter_id or "").strip()
        if not normalized:
            return None
        return normalized[:128]

    def _normalize_category_id(self, category_id: str | None, fallback_name: str) -> str:
        normalized = (category_id or "").strip().lower()
        if normalized:
            normalized = self._slugify(normalized)
        if not normalized:
            normalized = self._slugify(fallback_name)
        if not normalized:
            raise InvalidPollPayloadError("Category id could not be generated.")
        return normalized[:80]

    def _normalize_tag_id(self, tag_id: str | None, fallback_name: str) -> str:
        normalized = (tag_id or "").strip().lower()
        if normalized:
            normalized = self._slugify(normalized)
        if not normalized:
            normalized = self._slugify(fallback_name)
        if not normalized:
            raise InvalidPollPayloadError("Tag id could not be generated.")
        return normalized[:80]

    def _normalize_color_hex(self, value: str | None) -> str | None:
        normalized = (value or "").strip().upper()
        if not normalized:
            return None
        if not normalized.startswith("#"):
            normalized = f"#{normalized}"
        if not re.fullmatch(r"#([A-F0-9]{6})", normalized):
            raise InvalidPollPayloadError(
                "Category color_hex must match #RRGGBB format."
            )
        return normalized

    def _slugify(self, value: str) -> str:
        slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
        return slug

    def _normalize_datetime(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=None)
        return value.astimezone(timezone.utc).replace(tzinfo=None)

    def _to_category_schema(self, row: CategoryRecord) -> Category:
        return Category(
            id=row.id,
            name=row.name,
            color_hex=row.color_hex,
            description=row.description,
            created_at=row.created_at,
        )

    def _to_feed_tag_schema(self, row: FeedTagRecord) -> FeedTag:
        return FeedTag(
            id=row.id,
            name=row.name,
            color_hex=row.color_hex,
            description=row.description,
            position=row.position,
            is_active=row.is_active,
            created_at=row.created_at,
        )

    def _to_schema(
        self,
        poll: PollRecord,
        *,
        has_voted: bool = False,
        selected_option_id: str | None = None,
    ) -> Poll:
        options = [
            PollOption(
                id=option.option_id,
                label=option.label,
                votes=option.votes,
            )
            for option in poll.options
        ]
        return Poll(
            id=poll.id,
            question=poll.question,
            category_id=poll.category_id,
            category_name=poll.category.name if poll.category is not None else None,
            options=options,
            ends_at=poll.ends_at,
            has_voted=has_voted,
            selected_option_id=selected_option_id,
        )
