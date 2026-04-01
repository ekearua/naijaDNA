from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.db.models import NotificationRecord, UserRecord
from app.schemas.notifications import NotificationItem, NotificationsResponse


class MissingUserContextError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class NotificationNotFoundError(Exception):
    pass


class NotificationsService:
    """List and update user notification inbox state."""

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def list_notifications(
        self,
        *,
        user_id: str,
        limit: int = 50,
        unread_only: bool = False,
    ) -> NotificationsResponse:
        normalized_user_id = self._normalize_user_id(user_id)
        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)

            statement = (
                select(NotificationRecord)
                .where(NotificationRecord.user_id == normalized_user_id)
                .order_by(NotificationRecord.created_at.desc())
                .limit(limit)
            )
            if unread_only:
                statement = statement.where(NotificationRecord.is_read.is_(False))

            result = await session.execute(statement)
            items = [self._to_schema(row) for row in result.scalars().all()]

            unread_count = await session.scalar(
                select(func.count(NotificationRecord.id)).where(
                    NotificationRecord.user_id == normalized_user_id,
                    NotificationRecord.is_read.is_(False),
                )
            )

            return NotificationsResponse(
                items=items,
                total=len(items),
                unread_count=int(unread_count or 0),
            )

    async def mark_read(
        self,
        *,
        user_id: str,
        notification_id: int,
    ) -> None:
        normalized_user_id = self._normalize_user_id(user_id)
        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            result = await session.execute(
                select(NotificationRecord).where(
                    NotificationRecord.id == notification_id,
                    NotificationRecord.user_id == normalized_user_id,
                )
            )
            notification = result.scalar_one_or_none()
            if notification is None:
                raise NotificationNotFoundError(
                    f"Notification '{notification_id}' does not exist."
                )
            notification.is_read = True
            await session.commit()

    async def mark_all_read(self, *, user_id: str) -> int:
        normalized_user_id = self._normalize_user_id(user_id)
        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            result = await session.execute(
                update(NotificationRecord)
                .where(
                    NotificationRecord.user_id == normalized_user_id,
                    NotificationRecord.is_read.is_(False),
                )
                .values(is_read=True)
                .returning(NotificationRecord.id)
            )
            marked_count = len(result.scalars().all())
            await session.commit()
            return marked_count

    async def _assert_user_exists(self, session: AsyncSession, user_id: str) -> None:
        result = await session.execute(select(UserRecord.id).where(UserRecord.id == user_id))
        if result.scalar_one_or_none() is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")

    def _normalize_user_id(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if not normalized:
            raise MissingUserContextError("x-user-id header is required.")
        return normalized[:128]

    def _to_schema(self, row: NotificationRecord) -> NotificationItem:
        return NotificationItem(
            id=row.id,
            type=row.type,
            title=row.title,
            body=row.body,
            actor_user_id=row.actor_user_id,
            actor_name=row.actor_name,
            article_id=row.article_id,
            comment_id=row.comment_id,
            is_read=row.is_read,
            created_at=row.created_at,
        )
