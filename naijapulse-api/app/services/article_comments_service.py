from datetime import datetime

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.db.models import (
    ArticleCommentRecord,
    CommentReactionRecord,
    CommentReportRecord,
    NewsArticleRecord,
    UserPreferenceRecord,
    UserRecord,
)
from app.schemas.comments import (
    ArticleComment,
    ArticleCommentReply,
    CommentReactionResponse,
    ReportedCommentItem,
)
from app.services.notifications_service import NotificationsService, PendingNotificationDelivery


class MissingUserContextError(Exception):
    pass


class NewsArticleNotFoundError(Exception):
    pass


class ArticleCommentNotFoundError(Exception):
    pass


class ArticleCommentPermissionError(Exception):
    pass


class InvalidArticleCommentPayloadError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class CommentModerationError(Exception):
    pass


class ArticleCommentsService:
    """Create and list threaded article comments plus reply/report events."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        notifications_service: NotificationsService,
    ) -> None:
        self._session_factory = session_factory
        self._notifications_service = notifications_service

    async def list_comments(
        self,
        *,
        article_id: str,
        limit: int = 100,
        viewer_user_id: str | None = None,
    ) -> list[ArticleComment]:
        async with self._session_factory() as session:
            await self._load_article_or_raise(session, article_id)
            normalized_viewer_id = self._normalize_optional_user_id(viewer_user_id)
            viewer_can_moderate = False
            if normalized_viewer_id is not None:
                viewer = await self._load_user_or_raise(session, normalized_viewer_id)
                viewer_can_moderate = viewer.role in {"admin", "editor", "moderator"}
            visible_statuses = ["visible", "removed"]
            if viewer_can_moderate:
                visible_statuses.append("flagged")

            result = await session.execute(
                select(ArticleCommentRecord)
                .where(
                    ArticleCommentRecord.article_id == article_id,
                    ArticleCommentRecord.status.in_(visible_statuses),
                )
                .options(
                    selectinload(ArticleCommentRecord.reports),
                    selectinload(ArticleCommentRecord.replies).selectinload(
                        ArticleCommentRecord.reports
                    ),
                )
                .order_by(ArticleCommentRecord.created_at.asc())
                .limit(limit)
            )
            rows = result.scalars().unique().all()

            top_level: list[ArticleCommentRecord] = []
            replies_by_parent: dict[int, list[ArticleCommentRecord]] = {}
            for row in rows:
                if row.parent_comment_id is None:
                    top_level.append(row)
                else:
                    replies_by_parent.setdefault(row.parent_comment_id, []).append(row)
            report_counts = {row.id: len(row.reports) for row in rows}

            liked_ids = await self._liked_comment_ids(
                session,
                normalized_viewer_id,
                [row.id for row in rows],
            )
            reported_ids = await self._reported_comment_ids(
                session,
                normalized_viewer_id,
                [row.id for row in rows],
            )

            return [
                self._to_comment_schema(
                    row,
                    replies=replies_by_parent.get(row.id, []),
                    liked_ids=liked_ids,
                    reported_ids=reported_ids,
                    report_counts=report_counts,
                    include_flagged=viewer_can_moderate,
                )
                for row in top_level
            ]

    async def create_comment(
        self,
        *,
        article_id: str,
        body: str,
        user_id: str | None,
    ) -> ArticleComment:
        normalized_user_id = self._normalize_user_id(user_id)
        normalized_body = self._normalize_body(body)

        async with self._session_factory() as session:
            article = await self._load_article_or_raise(session, article_id)
            user = await self._load_user_or_raise(session, normalized_user_id)
            now = datetime.utcnow()

            comment = ArticleCommentRecord(
                article_id=article.id,
                user_id=user.id,
                author_name=self._user_display_name(user),
                body=normalized_body,
                status="visible",
                created_at=now,
                updated_at=now,
            )
            session.add(comment)
            await session.commit()
            await session.refresh(comment)
            return self._to_comment_schema(
                comment,
                replies=[],
                liked_ids=set(),
                reported_ids=set(),
                report_counts={comment.id: 0},
            )

    async def reply_to_comment(
        self,
        *,
        parent_comment_id: int,
        body: str,
        user_id: str | None,
    ) -> ArticleCommentReply:
        normalized_user_id = self._normalize_user_id(user_id)
        normalized_body = self._normalize_body(body)

        async with self._session_factory() as session:
            parent = await self._load_comment_or_raise(session, parent_comment_id)
            if parent.status != "visible":
                raise ArticleCommentPermissionError(
                    "Replies can only be added to visible comments."
                )

            article = await self._load_article_or_raise(session, parent.article_id)
            user = await self._load_user_or_raise(session, normalized_user_id)
            now = datetime.utcnow()

            reply = ArticleCommentRecord(
                article_id=article.id,
                user_id=user.id,
                parent_comment_id=parent.id,
                author_name=self._user_display_name(user),
                body=normalized_body,
                status="visible",
                created_at=now,
                updated_at=now,
            )
            parent.reply_count += 1
            parent.updated_at = now
            session.add(reply)

            pending_notification = await self._create_reply_notification(
                session,
                parent=parent,
                article=article,
                actor=user,
                reply=reply,
            )

            await session.commit()
            await session.refresh(reply)
            await self._notifications_service.deliver_push(pending_notification)
            return self._to_reply_schema(reply, report_count=0)

    async def toggle_like(
        self,
        *,
        comment_id: int,
        user_id: str | None,
    ) -> CommentReactionResponse:
        normalized_user_id = self._normalize_user_id(user_id)

        async with self._session_factory() as session:
            comment = await self._load_comment_or_raise(session, comment_id)
            actor = await self._load_user_or_raise(session, normalized_user_id)
            if comment.status not in {"visible", "flagged"}:
                raise ArticleCommentPermissionError(
                    "Reactions can only be added to active comments."
                )

            existing_result = await session.execute(
                select(CommentReactionRecord).where(
                    CommentReactionRecord.comment_id == comment.id,
                    CommentReactionRecord.user_id == normalized_user_id,
                    CommentReactionRecord.reaction_type == "like",
                )
            )
            existing = existing_result.scalar_one_or_none()
            pending_notification: PendingNotificationDelivery | None = None
            if existing is None:
                session.add(
                    CommentReactionRecord(
                        comment_id=comment.id,
                        user_id=normalized_user_id,
                        reaction_type="like",
                        created_at=datetime.utcnow(),
                    )
                )
                comment.like_count += 1
                liked = True
                article = await self._load_article_or_raise(session, comment.article_id)
                pending_notification = await self._create_like_notification(
                    session,
                    comment=comment,
                    article=article,
                    actor=actor,
                )
            else:
                await session.delete(existing)
                comment.like_count = max(0, comment.like_count - 1)
                liked = False

            comment.updated_at = datetime.utcnow()
            await session.commit()
            if liked:
                await self._notifications_service.deliver_push(pending_notification)
            return CommentReactionResponse(
                comment_id=comment.id,
                reaction_type="like",
                liked=liked,
                like_count=comment.like_count,
            )

    async def report_comment(
        self,
        *,
        comment_id: int,
        user_id: str | None,
        reason: str | None,
    ) -> None:
        normalized_user_id = self._normalize_user_id(user_id)
        normalized_reason = (reason or "").strip() or None

        async with self._session_factory() as session:
            comment = await self._load_comment_or_raise(session, comment_id)
            reporter = await self._load_user_or_raise(session, normalized_user_id)

            existing_result = await session.execute(
                select(CommentReportRecord).where(
                    CommentReportRecord.comment_id == comment.id,
                    CommentReportRecord.reporter_user_id == reporter.id,
                )
            )
            existing = existing_result.scalar_one_or_none()
            if existing is None:
                session.add(
                    CommentReportRecord(
                        comment_id=comment.id,
                        reporter_user_id=reporter.id,
                        reason=normalized_reason,
                        created_at=datetime.utcnow(),
                    )
                )
            if comment.status == "visible":
                comment.status = "flagged"
                comment.updated_at = datetime.utcnow()
            await session.commit()

    async def list_reported_comments(
        self,
        *,
        actor_user_id: str | None,
        limit: int = 100,
    ) -> list[ReportedCommentItem]:
        normalized_actor_id = self._normalize_user_id(actor_user_id)

        async with self._session_factory() as session:
            actor = await self._load_user_or_raise(session, normalized_actor_id)
            self._assert_admin(actor)

            report_count = func.count(CommentReportRecord.id)
            result = await session.execute(
                select(ArticleCommentRecord, NewsArticleRecord.title, report_count.label("report_count"))
                .join(NewsArticleRecord, NewsArticleRecord.id == ArticleCommentRecord.article_id)
                .outerjoin(
                    CommentReportRecord,
                    CommentReportRecord.comment_id == ArticleCommentRecord.id,
                )
                .group_by(ArticleCommentRecord.id, NewsArticleRecord.title)
                .having(
                    (report_count > 0)
                    | (ArticleCommentRecord.status == "removed")
                    | (ArticleCommentRecord.status == "flagged")
                )
                .order_by(
                    report_count.desc(),
                    ArticleCommentRecord.updated_at.desc(),
                    ArticleCommentRecord.created_at.desc(),
                )
                .limit(limit)
            )
            rows = result.all()
            return [
                ReportedCommentItem(
                    id=comment.id,
                    article_id=comment.article_id,
                    article_title=article_title,
                    author_name=comment.author_name,
                    body=self._display_body(comment),
                    status=comment.status,
                    report_count=int(total_reports or 0),
                    like_count=comment.like_count,
                    reply_count=comment.reply_count,
                    moderation_reason=comment.moderation_reason,
                    created_at=comment.created_at,
                    updated_at=comment.updated_at,
                )
                for comment, article_title, total_reports in rows
            ]

    async def moderate_comment(
        self,
        *,
        actor_user_id: str | None,
        comment_id: int,
        action: str,
        notes: str | None = None,
    ) -> ArticleComment:
        normalized_actor_id = self._normalize_user_id(actor_user_id)
        normalized_action = action.strip().lower()
        normalized_notes = (notes or "").strip() or None
        if normalized_action not in {"remove", "restore", "dismiss_reports"}:
            raise InvalidArticleCommentPayloadError("Unsupported moderation action.")

        async with self._session_factory() as session:
            actor = await self._load_user_or_raise(session, normalized_actor_id)
            self._assert_admin(actor)
            comment = await self._load_comment_or_raise(session, comment_id)

            if normalized_action == "remove":
                comment.status = "removed"
                comment.moderated_by_user_id = actor.id
                comment.moderated_at = datetime.utcnow()
                comment.moderation_reason = normalized_notes or "Removed by moderation team."
            elif normalized_action == "restore":
                comment.status = "visible"
                comment.moderated_by_user_id = actor.id
                comment.moderated_at = datetime.utcnow()
                comment.moderation_reason = normalized_notes
            else:
                comment.status = "visible"
                comment.moderated_by_user_id = actor.id
                comment.moderated_at = datetime.utcnow()
                comment.moderation_reason = normalized_notes
                await session.execute(
                    delete(CommentReportRecord).where(
                        CommentReportRecord.comment_id == comment.id
                    )
                )

            comment.updated_at = datetime.utcnow()
            await session.commit()
            report_count = int(
                await session.scalar(
                    select(func.count(CommentReportRecord.id)).where(
                        CommentReportRecord.comment_id == comment.id
                    )
                )
                or 0
            )
            await session.refresh(comment)
            return self._to_comment_schema(
                comment,
                replies=[],
                liked_ids=set(),
                reported_ids=set(),
                report_counts={comment.id: report_count},
            )

    async def _load_article_or_raise(
        self,
        session: AsyncSession,
        article_id: str,
    ) -> NewsArticleRecord:
        result = await session.execute(
            select(NewsArticleRecord).where(
                NewsArticleRecord.id == article_id,
                NewsArticleRecord.status == "published",
            )
        )
        article = result.scalar_one_or_none()
        if article is None:
            raise NewsArticleNotFoundError(f"Article '{article_id}' does not exist.")
        return article

    async def _load_comment_or_raise(
        self,
        session: AsyncSession,
        comment_id: int,
    ) -> ArticleCommentRecord:
        result = await session.execute(
            select(ArticleCommentRecord).where(ArticleCommentRecord.id == comment_id)
        )
        comment = result.scalar_one_or_none()
        if comment is None:
            raise ArticleCommentNotFoundError(
                f"Comment '{comment_id}' does not exist."
            )
        return comment

    async def _load_user_or_raise(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> UserRecord:
        result = await session.execute(select(UserRecord).where(UserRecord.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")
        if not user.is_active:
            raise ArticleCommentPermissionError("This account is disabled.")
        return user

    async def _create_reply_notification(
        self,
        session: AsyncSession,
        *,
        parent: ArticleCommentRecord,
        article: NewsArticleRecord,
        actor: UserRecord,
        reply: ArticleCommentRecord,
    ) -> PendingNotificationDelivery | None:
        if parent.user_id is None or parent.user_id == actor.id:
            return None

        preference_result = await session.execute(
            select(UserPreferenceRecord).where(
                UserPreferenceRecord.user_id == parent.user_id
            )
        )
        preferences = preference_result.scalar_one_or_none()
        if preferences is not None and not preferences.comment_replies:
            return None

        return await self._notifications_service.create_notification(
            session,
            user_id=parent.user_id,
            type="comment_reply",
            title="New reply to your comment",
            body=f"{self._user_display_name(actor)} replied on \"{article.title}\".",
            actor_user_id=actor.id,
            actor_name=self._user_display_name(actor),
            article_id=article.id,
            comment_id=reply.id,
        )

    async def _create_like_notification(
        self,
        session: AsyncSession,
        *,
        comment: ArticleCommentRecord,
        article: NewsArticleRecord,
        actor: UserRecord,
    ) -> PendingNotificationDelivery | None:
        if comment.user_id is None or comment.user_id == actor.id:
            return None

        preference_result = await session.execute(
            select(UserPreferenceRecord).where(
                UserPreferenceRecord.user_id == comment.user_id
            )
        )
        preferences = preference_result.scalar_one_or_none()
        if preferences is not None and not preferences.comment_replies:
            return None

        return await self._notifications_service.create_notification(
            session,
            user_id=comment.user_id,
            type="comment_like",
            title="Someone liked your comment",
            body=f"{self._user_display_name(actor)} liked your comment on \"{article.title}\".",
            actor_user_id=actor.id,
            actor_name=self._user_display_name(actor),
            article_id=article.id,
            comment_id=comment.id,
        )

    def _normalize_user_id(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if not normalized:
            raise MissingUserContextError("x-user-id header is required.")
        return normalized[:128]

    def _normalize_optional_user_id(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        return normalized[:128]

    def _normalize_body(self, value: str | None) -> str:
        normalized = (value or "").strip()
        if not normalized:
            raise InvalidArticleCommentPayloadError("Comment body cannot be empty.")
        if len(normalized) > 2000:
            raise InvalidArticleCommentPayloadError("Comment body is too long.")
        return normalized

    def _user_display_name(self, user: UserRecord) -> str:
        if user.display_name and user.display_name.strip():
            return user.display_name.strip()
        if user.email and user.email.strip():
            return user.email.strip()
        return user.id

    def _display_body(self, row: ArticleCommentRecord) -> str:
        if row.status == "removed":
            return "This comment was removed."
        return row.body

    async def _liked_comment_ids(
        self,
        session: AsyncSession,
        user_id: str | None,
        comment_ids: list[int],
    ) -> set[int]:
        if user_id is None or not comment_ids:
            return set()
        result = await session.execute(
            select(CommentReactionRecord.comment_id).where(
                CommentReactionRecord.user_id == user_id,
                CommentReactionRecord.reaction_type == "like",
                CommentReactionRecord.comment_id.in_(comment_ids),
            )
        )
        return set(result.scalars().all())

    async def _reported_comment_ids(
        self,
        session: AsyncSession,
        user_id: str | None,
        comment_ids: list[int],
    ) -> set[int]:
        if user_id is None or not comment_ids:
            return set()
        result = await session.execute(
            select(CommentReportRecord.comment_id).where(
                CommentReportRecord.reporter_user_id == user_id,
                CommentReportRecord.comment_id.in_(comment_ids),
            )
        )
        return set(result.scalars().all())

    def _assert_admin(self, user: UserRecord) -> None:
        if not user.is_active:
            raise CommentModerationError("This account is disabled.")
        if user.role not in {"admin", "editor", "moderator"}:
            raise CommentModerationError(
                "Moderator, editor, or admin privileges are required for this action."
            )

    def _to_comment_schema(
        self,
        row: ArticleCommentRecord,
        *,
        replies: list[ArticleCommentRecord],
        liked_ids: set[int],
        reported_ids: set[int],
        report_counts: dict[int, int],
        include_flagged: bool,
    ) -> ArticleComment:
        return ArticleComment(
            id=row.id,
            article_id=row.article_id,
            parent_comment_id=row.parent_comment_id,
            user_id=row.user_id,
            author_name=row.author_name,
            body=self._display_body(row),
            status=row.status,
            reply_count=row.reply_count,
            like_count=row.like_count,
            report_count=report_counts.get(row.id, 0),
            viewer_has_liked=row.id in liked_ids,
            viewer_has_reported=row.id in reported_ids,
            moderation_reason=row.moderation_reason,
            created_at=row.created_at,
            updated_at=row.updated_at,
            replies=[
                self._to_reply_schema(
                    item,
                    report_count=report_counts.get(item.id, 0),
                    liked=item.id in liked_ids,
                    reported=item.id in reported_ids,
                )
                for item in replies
                if item.status in ({"visible", "removed", "flagged"} if include_flagged else {"visible", "removed"})
            ],
        )

    def _to_reply_schema(
        self,
        row: ArticleCommentRecord,
        *,
        report_count: int = 0,
        liked: bool = False,
        reported: bool = False,
    ) -> ArticleCommentReply:
        return ArticleCommentReply(
            id=row.id,
            article_id=row.article_id,
            parent_comment_id=row.parent_comment_id or 0,
            user_id=row.user_id,
            author_name=row.author_name,
            body=self._display_body(row),
            status=row.status,
            reply_count=row.reply_count,
            like_count=row.like_count,
            report_count=report_count,
            viewer_has_liked=liked,
            viewer_has_reported=reported,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )
