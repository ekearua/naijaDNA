from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.db.models import DeviceTokenRecord, NotificationRecord, UserPreferenceRecord, UserRecord
from app.schemas.notifications import NotificationItem, NotificationsResponse
from app.services.push_notification_service import PushNotificationService


class MissingUserContextError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class NotificationNotFoundError(Exception):
    pass


class InvalidNotificationPayloadError(Exception):
    pass


@dataclass(frozen=True, slots=True)
class PendingNotificationDelivery:
    notification_id: int
    user_id: str
    type: str
    title: str
    body: str
    article_id: str | None
    comment_id: int | None


class NotificationsService:
    """List and update user notification inbox state."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        push_service: PushNotificationService,
    ) -> None:
        self._session_factory = session_factory
        self._push_service = push_service

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

    async def register_device_token(
        self,
        *,
        user_id: str,
        token: str,
        platform: str,
    ) -> None:
        normalized_user_id = self._normalize_user_id(user_id)
        normalized_token = self._normalize_token(token)
        normalized_platform = self._normalize_platform(platform)

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            result = await session.execute(
                select(DeviceTokenRecord).where(DeviceTokenRecord.token == normalized_token)
            )
            record = result.scalar_one_or_none()
            now = datetime.utcnow()
            if record is None:
                session.add(
                    DeviceTokenRecord(
                        user_id=normalized_user_id,
                        token=normalized_token,
                        platform=normalized_platform,
                        is_active=True,
                        created_at=now,
                        last_seen_at=now,
                    )
                )
            else:
                record.user_id = normalized_user_id
                record.platform = normalized_platform
                record.is_active = True
                record.last_seen_at = now
            await session.commit()

    async def unregister_device_token(
        self,
        *,
        user_id: str,
        token: str,
    ) -> None:
        normalized_user_id = self._normalize_user_id(user_id)
        normalized_token = self._normalize_token(token)

        async with self._session_factory() as session:
            await self._assert_user_exists(session, normalized_user_id)
            result = await session.execute(
                select(DeviceTokenRecord).where(
                    DeviceTokenRecord.user_id == normalized_user_id,
                    DeviceTokenRecord.token == normalized_token,
                )
            )
            record = result.scalar_one_or_none()
            if record is None:
                return
            record.is_active = False
            record.last_seen_at = datetime.utcnow()
            await session.commit()

    async def create_notification(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        type: str,
        title: str,
        body: str,
        actor_user_id: str | None = None,
        actor_name: str | None = None,
        article_id: str | None = None,
        comment_id: int | None = None,
    ) -> PendingNotificationDelivery:
        record = NotificationRecord(
            user_id=user_id,
            type=type,
            title=title,
            body=body,
            actor_user_id=actor_user_id,
            actor_name=actor_name,
            article_id=article_id,
            comment_id=comment_id,
            is_read=False,
            created_at=datetime.utcnow(),
        )
        session.add(record)
        await session.flush()
        return PendingNotificationDelivery(
            notification_id=record.id,
            user_id=user_id,
            type=type,
            title=title,
            body=body,
            article_id=article_id,
            comment_id=comment_id,
        )

    async def deliver_push(
        self,
        pending: PendingNotificationDelivery | None,
    ) -> None:
        if pending is None or not self._push_service.enabled:
            return

        async with self._session_factory() as session:
            pref_result = await session.execute(
                select(UserPreferenceRecord).where(
                    UserPreferenceRecord.user_id == pending.user_id
                )
            )
            preferences = pref_result.scalar_one_or_none()
            if not self._push_allowed_for_type(pending.type, preferences):
                return

            token_result = await session.execute(
                select(DeviceTokenRecord).where(
                    DeviceTokenRecord.user_id == pending.user_id,
                    DeviceTokenRecord.is_active.is_(True),
                )
            )
            rows = token_result.scalars().all()
            tokens = [row.token for row in rows if row.token and row.token.strip()]
            if not tokens:
                return

        payload = {
            "notification_id": str(pending.notification_id),
            "type": pending.type,
        }
        if pending.article_id is not None:
            payload["article_id"] = pending.article_id
        if pending.comment_id is not None:
            payload["comment_id"] = str(pending.comment_id)

        result = self._push_service.send_notification(
            tokens=tokens,
            title=pending.title,
            body=pending.body,
            data=payload,
        )

        if not result.invalid_tokens:
            return

        async with self._session_factory() as session:
            invalid_result = await session.execute(
                select(DeviceTokenRecord).where(
                    DeviceTokenRecord.token.in_(result.invalid_tokens)
                )
            )
            for row in invalid_result.scalars().all():
                row.is_active = False
                row.last_seen_at = datetime.utcnow()
            await session.commit()

    async def _assert_user_exists(self, session: AsyncSession, user_id: str) -> None:
        result = await session.execute(select(UserRecord.id).where(UserRecord.id == user_id))
        if result.scalar_one_or_none() is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")

    def _normalize_user_id(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if not normalized:
            raise MissingUserContextError("x-user-id header is required.")
        return normalized[:128]

    def _normalize_token(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if len(normalized) < 32:
            raise InvalidNotificationPayloadError("A valid device token is required.")
        return normalized[:512]

    def _normalize_platform(self, value: str | None) -> str:
        normalized = (value or "").strip().lower()
        if not normalized:
            return "unknown"
        return normalized[:24]

    def _push_allowed_for_type(
        self,
        notification_type: str,
        preferences: UserPreferenceRecord | None,
    ) -> bool:
        if preferences is None:
            return True
        if notification_type in {"comment_reply", "comment_like"}:
            return preferences.comment_replies
        return True

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
