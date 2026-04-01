from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.db.models import (
    StreamCommentRecord,
    StreamSessionRecord,
    StreamViewerPresenceRecord,
    UserRecord,
)
from app.schemas.streams import CreateStreamRequest, StreamComment, StreamSession


class StreamNotFoundError(Exception):
    pass


class InvalidStreamPayloadError(Exception):
    pass


class StreamPermissionError(Exception):
    pass


class StreamStateError(Exception):
    pass


class StreamViewerIdentityError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class StreamCommentPermissionError(Exception):
    pass


class StreamsService:
    """Manage live and scheduled stream sessions plus viewer presence."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        viewer_presence_ttl_seconds: int = 75,
    ) -> None:
        self._session_factory = session_factory
        self._viewer_presence_ttl_seconds = viewer_presence_ttl_seconds

    async def list_live_streams(
        self,
        *,
        category: str | None = None,
        limit: int = 20,
        user_id: str | None = None,
    ) -> list[StreamSession]:
        return await self._list_streams(
            status="live",
            category=category,
            limit=limit,
            user_id=user_id,
        )

    async def list_scheduled_streams(
        self,
        *,
        category: str | None = None,
        limit: int = 20,
        user_id: str | None = None,
    ) -> list[StreamSession]:
        return await self._list_streams(
            status="scheduled",
            category=category,
            limit=limit,
            user_id=user_id,
        )

    async def get_stream(
        self,
        stream_id: str,
        *,
        user_id: str | None = None,
    ) -> StreamSession:
        async with self._session_factory() as session:
            viewer = await self._load_stream_viewer_or_raise(session, user_id)
            self._assert_can_access_streams(viewer)
            record = await self._load_stream_or_raise(session, stream_id)
            viewer_counts = await self._viewer_counts_for_streams(session, [record.id])
            return self._to_schema(record, viewer_count=viewer_counts.get(record.id, 0))

    async def create_stream(
        self,
        *,
        payload: CreateStreamRequest,
        host_user_id: str | None,
    ) -> StreamSession:
        normalized_host_user_id = self._normalize_identity(host_user_id)
        if normalized_host_user_id is None:
            raise InvalidStreamPayloadError("Sign in is required to host or schedule a stream.")

        title = payload.title.strip()
        category = payload.category.strip()
        if len(title) < 5:
            raise InvalidStreamPayloadError("Stream title must be at least 5 characters.")
        if len(category) < 2:
            raise InvalidStreamPayloadError("Stream category must be at least 2 characters.")

        now = datetime.utcnow()
        scheduled_for = self._normalize_datetime(payload.scheduled_for)
        mode = payload.mode
        if mode == "schedule":
            if scheduled_for is None:
                raise InvalidStreamPayloadError(
                    "scheduled_for is required when scheduling a stream."
                )
            if scheduled_for <= now:
                raise InvalidStreamPayloadError("Scheduled stream time must be in the future.")

        async with self._session_factory() as session:
            host = await self._load_user_or_raise(session, normalized_host_user_id)
            self._assert_can_host_streams(host)
            record = StreamSessionRecord(
                id=f"stream-{uuid4().hex[:12]}",
                host_user_id=host.id,
                title=title,
                description=(payload.description or "").strip() or None,
                category=category,
                cover_image_url=str(payload.cover_image_url) if payload.cover_image_url else None,
                stream_url=str(payload.stream_url) if payload.stream_url else None,
                status="scheduled" if mode == "schedule" else "live",
                scheduled_for=scheduled_for if mode == "schedule" else None,
                started_at=now if mode == "go_live" else None,
                ended_at=None,
                created_at=now,
                updated_at=now,
            )
            session.add(record)
            await session.commit()
            await session.refresh(record, attribute_names=["host"])
            return self._to_schema(record, viewer_count=0)

    async def start_stream(
        self,
        *,
        stream_id: str,
        host_user_id: str | None,
    ) -> StreamSession:
        normalized_host_user_id = self._normalize_identity(host_user_id)
        if normalized_host_user_id is None:
            raise StreamPermissionError("Sign in is required to start a stream.")

        async with self._session_factory() as session:
            record = await self._load_stream_or_raise(session, stream_id)
            host = await self._load_user_or_raise(session, normalized_host_user_id)
            self._assert_can_host_streams(host)
            self._assert_host_ownership(record, normalized_host_user_id)

            if record.status == "live":
                viewer_counts = await self._viewer_counts_for_streams(session, [record.id])
                return self._to_schema(record, viewer_count=viewer_counts.get(record.id, 0))
            if record.status == "ended":
                raise StreamStateError("Ended streams cannot be restarted.")

            now = datetime.utcnow()
            record.status = "live"
            record.started_at = now
            record.ended_at = None
            record.updated_at = now
            await session.commit()
            await session.refresh(record, attribute_names=["host"])
            return self._to_schema(record, viewer_count=0)

    async def end_stream(
        self,
        *,
        stream_id: str,
        host_user_id: str | None,
    ) -> StreamSession:
        normalized_host_user_id = self._normalize_identity(host_user_id)
        if normalized_host_user_id is None:
            raise StreamPermissionError("Sign in is required to end a stream.")

        async with self._session_factory() as session:
            record = await self._load_stream_or_raise(session, stream_id)
            host = await self._load_user_or_raise(session, normalized_host_user_id)
            self._assert_can_host_streams(host)
            self._assert_host_ownership(record, normalized_host_user_id)

            if record.status == "ended":
                return self._to_schema(record, viewer_count=0)
            if record.status not in {"live", "scheduled"}:
                raise StreamStateError("This stream cannot be ended.")

            now = datetime.utcnow()
            record.status = "ended"
            record.ended_at = now
            record.updated_at = now
            await session.execute(
                update(StreamViewerPresenceRecord)
                .where(
                    StreamViewerPresenceRecord.stream_id == record.id,
                    StreamViewerPresenceRecord.left_at.is_(None),
                )
                .values(left_at=now, last_seen_at=now)
            )
            await session.commit()
            await session.refresh(record, attribute_names=["host"])
            return self._to_schema(record, viewer_count=0)

    async def update_presence(
        self,
        *,
        stream_id: str,
        action: str,
        viewer_id: str | None,
        user_id: str | None,
    ) -> StreamSession:
        normalized_user_id = self._normalize_identity(user_id)
        normalized_viewer_id = self._normalize_identity(viewer_id)
        viewer_key = normalized_user_id or normalized_viewer_id
        if viewer_key is None:
            raise StreamViewerIdentityError(
                "A viewer identity is required for stream presence updates."
            )

        async with self._session_factory() as session:
            viewer = await self._load_stream_viewer_or_raise(session, user_id)
            self._assert_can_access_streams(viewer)
            record = await self._load_stream_or_raise(session, stream_id)
            if action != "leave" and record.status != "live":
                raise StreamStateError("Only live streams can accept active viewers.")

            now = datetime.utcnow()
            result = await session.execute(
                select(StreamViewerPresenceRecord).where(
                    StreamViewerPresenceRecord.stream_id == record.id,
                    StreamViewerPresenceRecord.viewer_key == viewer_key,
                )
            )
            presence = result.scalar_one_or_none()

            if action == "leave":
                if presence is not None:
                    presence.left_at = now
                    presence.last_seen_at = now
                await session.commit()
                viewer_counts = await self._viewer_counts_for_streams(session, [record.id])
                return self._to_schema(record, viewer_count=viewer_counts.get(record.id, 0))

            if presence is None:
                presence = StreamViewerPresenceRecord(
                    stream_id=record.id,
                    viewer_key=viewer_key,
                    user_id=normalized_user_id,
                    joined_at=now,
                    last_seen_at=now,
                    left_at=None,
                )
                session.add(presence)
            else:
                presence.user_id = normalized_user_id
                presence.last_seen_at = now
                presence.left_at = None

            await session.commit()
            viewer_counts = await self._viewer_counts_for_streams(session, [record.id])
            return self._to_schema(record, viewer_count=viewer_counts.get(record.id, 0))

    async def list_comments(
        self,
        *,
        stream_id: str,
        limit: int = 50,
        user_id: str | None = None,
    ) -> list[StreamComment]:
        async with self._session_factory() as session:
            viewer = await self._load_stream_viewer_or_raise(session, user_id)
            self._assert_can_access_streams(viewer)
            await self._load_stream_or_raise(session, stream_id)
            result = await session.execute(
                select(StreamCommentRecord)
                .where(StreamCommentRecord.stream_id == stream_id)
                .order_by(StreamCommentRecord.created_at.desc())
                .limit(limit)
            )
            return [self._to_comment_schema(record) for record in result.scalars().all()]

    async def create_comment(
        self,
        *,
        stream_id: str,
        body: str,
        user_id: str | None,
    ) -> StreamComment:
        normalized_user_id = self._normalize_identity(user_id)
        if normalized_user_id is None:
            raise StreamCommentPermissionError("Sign in is required to comment on a stream.")

        normalized_body = body.strip()
        if not normalized_body:
            raise InvalidStreamPayloadError("Comment body cannot be empty.")
        if len(normalized_body) > 2000:
            raise InvalidStreamPayloadError("Comment body is too long.")

        async with self._session_factory() as session:
            record = await self._load_stream_or_raise(session, stream_id)
            if record.status != "live":
                raise StreamStateError("Comments can only be posted while the stream is live.")

            user = await self._load_user_or_raise(session, normalized_user_id)
            self._assert_can_access_streams(user)
            author_name = self._user_display_name(user)
            comment = StreamCommentRecord(
                stream_id=record.id,
                user_id=user.id,
                author_name=author_name,
                body=normalized_body,
                created_at=datetime.utcnow(),
            )
            session.add(comment)
            await session.commit()
            await session.refresh(comment)
            return self._to_comment_schema(comment)

    async def _list_streams(
        self,
        *,
        status: str,
        category: str | None,
        limit: int,
        user_id: str | None,
    ) -> list[StreamSession]:
        async with self._session_factory() as session:
            viewer = await self._load_stream_viewer_or_raise(session, user_id)
            self._assert_can_access_streams(viewer)
            statement = (
                select(StreamSessionRecord)
                .options(selectinload(StreamSessionRecord.host))
                .where(StreamSessionRecord.status == status)
                .limit(limit)
            )

            normalized_category = self._normalize_category(category)
            if normalized_category is not None:
                statement = statement.where(
                    func.lower(StreamSessionRecord.category) == normalized_category
                )

            if status == "scheduled":
                statement = statement.order_by(
                    StreamSessionRecord.scheduled_for.asc(),
                    StreamSessionRecord.created_at.desc(),
                )
            else:
                statement = statement.order_by(
                    StreamSessionRecord.started_at.desc(),
                    StreamSessionRecord.created_at.desc(),
                )

            result = await session.execute(statement)
            records = result.scalars().all()
            viewer_counts = await self._viewer_counts_for_streams(
                session,
                [record.id for record in records],
            )
            return [
                self._to_schema(record, viewer_count=viewer_counts.get(record.id, 0))
                for record in records
            ]

    async def _viewer_counts_for_streams(
        self,
        session: AsyncSession,
        stream_ids: list[str],
    ) -> dict[str, int]:
        if not stream_ids:
            return {}

        cutoff = datetime.utcnow() - timedelta(seconds=self._viewer_presence_ttl_seconds)
        result = await session.execute(
            select(
                StreamViewerPresenceRecord.stream_id,
                func.count(StreamViewerPresenceRecord.id),
            )
            .where(
                StreamViewerPresenceRecord.stream_id.in_(stream_ids),
                StreamViewerPresenceRecord.left_at.is_(None),
                StreamViewerPresenceRecord.last_seen_at >= cutoff,
            )
            .group_by(StreamViewerPresenceRecord.stream_id)
        )
        rows = result.all()
        return {stream_id: int(count) for stream_id, count in rows}

    async def _load_stream_or_raise(
        self,
        session: AsyncSession,
        stream_id: str,
    ) -> StreamSessionRecord:
        result = await session.execute(
            select(StreamSessionRecord)
            .options(selectinload(StreamSessionRecord.host))
            .where(StreamSessionRecord.id == stream_id)
        )
        record = result.scalar_one_or_none()
        if record is None:
            raise StreamNotFoundError(f"Stream '{stream_id}' does not exist.")
        return record

    async def _load_user_or_raise(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> UserRecord:
        result = await session.execute(
            select(UserRecord).where(UserRecord.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")
        if not user.is_active:
            raise StreamPermissionError("This account is disabled.")
        return user

    async def _load_stream_viewer_or_raise(
        self,
        session: AsyncSession,
        user_id: str | None,
    ) -> UserRecord:
        normalized_user_id = self._normalize_identity(user_id)
        if normalized_user_id is None:
            raise StreamPermissionError(
                "Sign in with an eligible account to access streams."
            )
        return await self._load_user_or_raise(session, normalized_user_id)

    def _assert_can_access_streams(self, user: UserRecord) -> None:
        if self._can_access_streams(user):
            return
        raise StreamPermissionError(
            "Streams require admin approval for this account."
        )

    def _assert_can_host_streams(self, user: UserRecord) -> None:
        if self._can_host_streams(user):
            return
        raise StreamPermissionError(
            "Hosting streams requires admin approval for this account."
        )

    def _can_access_streams(self, user: UserRecord) -> bool:
        role = (user.role or "").strip().lower()
        if role in {"admin", "editor", "contributor"}:
            return True
        return bool(user.stream_access_granted)

    def _can_host_streams(self, user: UserRecord) -> bool:
        role = (user.role or "").strip().lower()
        if role in {"admin", "editor", "contributor"}:
            return True
        return bool(user.stream_hosting_granted)

    def _assert_host_ownership(
        self,
        record: StreamSessionRecord,
        host_user_id: str,
    ) -> None:
        if record.host_user_id != host_user_id:
            raise StreamPermissionError("Only the stream host can change stream status.")

    def _normalize_identity(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        return normalized[:128]

    def _normalize_category(self, value: str | None) -> str | None:
        normalized = (value or "").strip().lower()
        if not normalized or normalized == "all":
            return None
        return normalized

    def _normalize_datetime(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=None)
        return value.astimezone(timezone.utc).replace(tzinfo=None)

    def _host_name(self, record: StreamSessionRecord) -> str | None:
        if record.host is None:
            return None
        if record.host.display_name and record.host.display_name.strip():
            return record.host.display_name.strip()
        if record.host.email and record.host.email.strip():
            return record.host.email.strip()
        return record.host.id

    def _user_display_name(self, user: UserRecord) -> str:
        if user.display_name and user.display_name.strip():
            return user.display_name.strip()
        if user.email and user.email.strip():
            return user.email.strip()
        return user.id

    def _to_schema(
        self,
        record: StreamSessionRecord,
        *,
        viewer_count: int,
    ) -> StreamSession:
        return StreamSession(
            id=record.id,
            title=record.title,
            description=record.description,
            category=record.category,
            cover_image_url=record.cover_image_url,
            stream_url=record.stream_url,
            status=record.status,
            host_user_id=record.host_user_id,
            host_name=self._host_name(record),
            viewer_count=viewer_count if record.status == "live" else 0,
            scheduled_for=record.scheduled_for,
            started_at=record.started_at,
            ended_at=record.ended_at,
            created_at=record.created_at,
            updated_at=record.updated_at,
        )

    def _to_comment_schema(self, record: StreamCommentRecord) -> StreamComment:
        return StreamComment(
            id=record.id,
            stream_id=record.stream_id,
            user_id=record.user_id,
            author_name=record.author_name,
            body=record.body,
            created_at=record.created_at,
        )
