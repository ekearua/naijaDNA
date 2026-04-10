import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.db.models import (
    AdminAccessRequestRecord,
    ArticleQueueSettingsRecord,
    ArticleCommentRecord,
    ArticleWorkflowEventRecord,
    CommentReportRecord,
    FeedEventRecord,
    HomepageCategoryRecord,
    HomepageSettingsRecord,
    HomepageSecondaryChipRecord,
    HomepageStoryPlacementRecord,
    NewsArticleRecord,
    NewsSourceRecord,
    NotificationRecord,
    UserAccessRequestRecord,
    UserRecord,
)
from app.schemas.admin import (
    AdminHomepageConfigResponse,
    AdminArticleQueueSettingsResponse,
    AdminArticleQueueArchiveRunResponse,
    AdminCreateSourceRequest,
    AdminNewsroomAccessRequestItem,
    AdminNewsroomAccessRequestsResponse,
    AdminReviewUserAccessRequest,
    AdminReviewNewsroomAccessRequest,
    AdminSourcesResponse,
    AdminUpdateSourceRequest,
    AdminUpdateUserRequest,
    AdminUserAccessRequestItem,
    AdminUserAccessRequestsResponse,
    AdminUserListItem,
    AdminUsersResponse,
    AnalyticsArticleItem,
    AnalyticsMetricItem,
    AnalyticsOverviewResponse,
    AnalyticsSourceItem,
    ArticleWorkflowHistoryResponse,
    CacheDiagnosticsResponse,
    CacheNamespaceDiagnostics,
    DashboardEditorialQueue,
    DashboardKpiItem,
    DashboardSummaryResponse,
    HomepageCategoryConfigItem,
    ArticleQueueSettingsConfigItem,
    ArticleQueueSettingsPatchRequest,
    ArticleQueueStatusCounts,
    HomepageCategoryPatchRequest,
    HomepagePlacementPatchRequest,
    HomepageSettingsConfigItem,
    HomepageSettingsPatchRequest,
    HomepageSecondaryChipConfigItem,
    HomepageSecondaryChipPatchRequest,
    HomepageStoryPlacementDetail,
    HomepageStoryPlacementItem,
    ResponseCacheDiagnostics,
    SourceHealthItem,
    VerificationDeskCounts,
    VerificationDeskResponse,
    WorkflowActivityItem,
)
from app.schemas.comments import ReportedCommentItem
from app.schemas.ingestion import IngestionStatusResponse
from app.schemas.news import HomepageCategoryFeed, HomepageSecondaryChipFeed, NewsSourceInfo
from app.schemas.users import User, UserEntitlements
from app.services.email_service import EmailService
from app.services.news_service import NewsArticleNotFoundError, NewsService
from app.services.response_cache_service import ResponseCacheService


class MissingAdminContextError(Exception):
    pass


class AdminPermissionError(Exception):
    pass


class AdminEntityNotFoundError(Exception):
    pass


class AdminValidationError(Exception):
    pass


class AdminPlatformService:
    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        news_service: NewsService,
        email_service: EmailService,
        settings: Settings | None = None,
    ) -> None:
        self._session_factory = session_factory
        self._news_service = news_service
        self._email_service = email_service
        self._settings = settings or get_settings()

    async def get_dashboard_summary(
        self,
        *,
        actor_user_id: str | None,
        ingestion_status: IngestionStatusResponse,
        limit_activity: int = 8,
        limit_reported_comments: int = 5,
        limit_sources: int = 5,
    ) -> DashboardSummaryResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)

            status_counts = await self._article_status_counts(session)
            published_today = await self._published_today_count(session)
            flagged_comments = await self._reported_comment_total(session)
            recent_activity = await self._recent_workflow_activity(
                session,
                limit=limit_activity,
            )
            reported_comments = await self._reported_comments_preview(
                session,
                limit=limit_reported_comments,
            )

        source_health = await self._build_source_health(
            ingestion_status=ingestion_status,
            limit=limit_sources,
        )
        healthy_sources = sum(1 for item in source_health if item.status == "healthy")
        failed_sources = sum(1 for item in source_health if item.status == "failing")

        review_count = (
            status_counts.get("submitted", 0) + status_counts.get("in_review", 0)
        )
        kpis = [
            DashboardKpiItem(
                key="drafts",
                label="Drafts",
                value=status_counts.get("draft", 0),
                tone="neutral",
            ),
            DashboardKpiItem(
                key="review",
                label="Review",
                value=review_count,
                tone="warning",
            ),
            DashboardKpiItem(
                key="published_today",
                label="Published Today",
                value=published_today,
                tone="success",
            ),
            DashboardKpiItem(
                key="flagged_comments",
                label="Flagged Comments",
                value=flagged_comments,
                tone="danger",
            ),
            DashboardKpiItem(
                key="healthy_sources",
                label="Healthy Sources",
                value=healthy_sources,
                tone="info",
            ),
            DashboardKpiItem(
                key="failed_sources",
                label="Failed Sources",
                value=failed_sources,
                tone="danger",
            ),
        ]

        return DashboardSummaryResponse(
            generated_at=datetime.utcnow(),
            kpis=kpis,
            editorial_queue=DashboardEditorialQueue(
                submitted=status_counts.get("submitted", 0),
                approved=status_counts.get("approved", 0),
                rejected=status_counts.get("rejected", 0),
                scheduled=await self._scheduled_count(),
            ),
            recent_workflow_activity=recent_activity,
            reported_comments=reported_comments,
            source_health=source_health,
            ingestion=ingestion_status,
        )

    async def get_article_workflow_detail(
        self,
        *,
        actor_user_id: str | None,
        article_id: str,
    ) -> ArticleWorkflowHistoryResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            article = await self._load_article(session, article_id)

            workflow_result = await session.execute(
                select(ArticleWorkflowEventRecord)
                .options(
                    selectinload(ArticleWorkflowEventRecord.article),
                    selectinload(ArticleWorkflowEventRecord.actor),
                )
                .where(ArticleWorkflowEventRecord.article_id == article_id)
                .order_by(ArticleWorkflowEventRecord.created_at.desc())
            )
            workflow_rows = workflow_result.scalars().all()

            notification_result = await session.execute(
                select(NotificationRecord)
                .where(NotificationRecord.article_id == article_id)
                .order_by(NotificationRecord.created_at.desc())
                .limit(25)
            )
            notification_rows = notification_result.scalars().all()

            total_comment_count = await session.scalar(
                select(func.count(ArticleCommentRecord.id)).where(
                    ArticleCommentRecord.article_id == article_id
                )
            )
            reported_comment_count = await session.scalar(
                select(func.count(func.distinct(CommentReportRecord.comment_id)))
                .select_from(CommentReportRecord)
                .join(
                    ArticleCommentRecord,
                    ArticleCommentRecord.id == CommentReportRecord.comment_id,
                )
                .where(ArticleCommentRecord.article_id == article_id)
            )

            return ArticleWorkflowHistoryResponse(
                article=self._news_service._to_schema(article),
                workflow_events=[
                    self._to_workflow_activity(item) for item in workflow_rows
                ],
                related_notifications=[
                    self._to_notification_item(item) for item in notification_rows
                ],
                reported_comment_count=reported_comment_count or 0,
                total_comment_count=total_comment_count or 0,
            )

    async def list_verification_articles(
        self,
        *,
        actor_user_id: str | None,
        verification_status: str | None = None,
        article_status: str | None = None,
        limit: int = 50,
    ) -> VerificationDeskResponse:
        normalized_verification = self._normalize_verification_status(
            verification_status
        )
        normalized_status = self._normalize_article_status(article_status)

        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)

            base_statement = select(NewsArticleRecord)
            total_statement = select(func.count(NewsArticleRecord.id))
            counts_statement = select(
                NewsArticleRecord.verification_status,
                func.count(NewsArticleRecord.id),
            ).group_by(NewsArticleRecord.verification_status)

            if normalized_status is not None:
                base_statement = base_statement.where(
                    NewsArticleRecord.status == normalized_status
                )
                total_statement = total_statement.where(
                    NewsArticleRecord.status == normalized_status
                )
                counts_statement = counts_statement.where(
                    NewsArticleRecord.status == normalized_status
                )
            if normalized_verification is not None:
                base_statement = base_statement.where(
                    NewsArticleRecord.verification_status == normalized_verification
                )
                total_statement = total_statement.where(
                    NewsArticleRecord.verification_status == normalized_verification
                )

            result = await session.execute(
                base_statement.order_by(
                    NewsArticleRecord.updated_at.desc(),
                    NewsArticleRecord.created_at.desc(),
                ).limit(limit)
            )
            rows = result.scalars().all()
            total = await session.scalar(total_statement)

            count_rows = await session.execute(counts_statement)
            counts = {status: count for status, count in count_rows.all()}

            return VerificationDeskResponse(
                items=[self._news_service._to_schema(row) for row in rows],
                total=total or 0,
                counts=VerificationDeskCounts(
                    unverified=counts.get("unverified", 0),
                    developing=counts.get("developing", 0),
                    verified=counts.get("verified", 0),
                    fact_checked=counts.get("fact_checked", 0),
                    opinion=counts.get("opinion", 0),
                    sponsored=counts.get("sponsored", 0),
                ),
            )

    async def list_sources(
        self,
        *,
        actor_user_id: str | None,
    ) -> AdminSourcesResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            result = await session.execute(
                select(NewsSourceRecord).order_by(NewsSourceRecord.id.asc())
            )
            rows = result.scalars().all()
            items = [self._to_source_info(row) for row in rows]
            return AdminSourcesResponse(items=items, total=len(items))

    async def create_source(
        self,
        *,
        actor_user_id: str | None,
        payload: AdminCreateSourceRequest,
    ) -> NewsSourceInfo:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            source_id = payload.id.strip().lower()
            existing = await session.get(NewsSourceRecord, source_id)
            if existing is not None:
                raise AdminValidationError(f"Source '{source_id}' already exists.")

            record = NewsSourceRecord(
                id=source_id,
                name=payload.name.strip(),
                type=payload.type.strip(),
                country=(payload.country or "").strip() or None,
                enabled=payload.enabled,
                requires_api_key=False,
                configured=self._derive_source_configured(
                    feed_url=payload.feed_url,
                    api_base_url=payload.api_base_url,
                ),
                feed_url=(payload.feed_url or "").strip() or None,
                api_base_url=(payload.api_base_url or "").strip() or None,
                poll_interval_sec=payload.poll_interval_sec,
                last_run_at=None,
                notes=(payload.notes or "").strip() or None,
            )
            session.add(record)
            await session.commit()
            return self._to_source_info(record)

    async def update_source(
        self,
        *,
        actor_user_id: str | None,
        source_id: str,
        payload: AdminUpdateSourceRequest,
    ) -> NewsSourceInfo:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            record = await session.get(NewsSourceRecord, source_id)
            if record is None:
                raise AdminEntityNotFoundError(f"Source '{source_id}' does not exist.")

            update_data = payload.model_dump(exclude_unset=True)
            if "name" in update_data and update_data["name"] is not None:
                record.name = update_data["name"].strip()
            if "type" in update_data and update_data["type"] is not None:
                record.type = update_data["type"].strip()
            if "country" in update_data:
                record.country = (update_data["country"] or "").strip() or None
            if "enabled" in update_data and update_data["enabled"] is not None:
                record.enabled = bool(update_data["enabled"])
            if "feed_url" in update_data:
                record.feed_url = (update_data["feed_url"] or "").strip() or None
            if "api_base_url" in update_data:
                record.api_base_url = (
                    update_data["api_base_url"] or ""
                ).strip() or None
            if (
                "poll_interval_sec" in update_data
                and update_data["poll_interval_sec"] is not None
            ):
                record.poll_interval_sec = int(update_data["poll_interval_sec"])
            if "notes" in update_data:
                record.notes = (update_data["notes"] or "").strip() or None

            if "configured" in update_data and update_data["configured"] is not None:
                record.configured = bool(update_data["configured"])
            elif not record.requires_api_key:
                record.configured = self._derive_source_configured(
                    feed_url=record.feed_url,
                    api_base_url=record.api_base_url,
                )

            await session.commit()
            return self._to_source_info(record)

    async def ensure_source_action_allowed(
        self,
        *,
        actor_user_id: str | None,
        source_id: str,
    ) -> NewsSourceInfo:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            record = await session.get(NewsSourceRecord, source_id)
            if record is None:
                raise AdminEntityNotFoundError(f"Source '{source_id}' does not exist.")
            if not record.configured:
                raise AdminValidationError(
                    f"Source '{source_id}' is not configured yet."
                )
            if not record.enabled:
                raise AdminValidationError(
                    f"Source '{source_id}' is disabled. Enable it before running."
                )
            return self._to_source_info(record)

    async def list_users(
        self,
        *,
        actor_user_id: str | None,
        role: str | None = None,
        is_active: bool | None = None,
        limit: int = 100,
    ) -> AdminUsersResponse:
        normalized_role = self._normalize_role(role)

        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)

            statement = select(UserRecord).order_by(UserRecord.created_at.desc()).limit(
                limit
            )
            count_statement = select(func.count(UserRecord.id))
            if normalized_role is not None:
                statement = statement.where(UserRecord.role == normalized_role)
                count_statement = count_statement.where(UserRecord.role == normalized_role)
            if is_active is not None:
                statement = statement.where(UserRecord.is_active.is_(is_active))
                count_statement = count_statement.where(UserRecord.is_active.is_(is_active))

            result = await session.execute(statement)
            rows = result.scalars().all()
            total = await session.scalar(count_statement)
            user_ids = [row.id for row in rows]
            if not user_ids:
                return AdminUsersResponse(items=[], total=total or 0)

            submitted_counts = await self._count_by_user(
                session,
                select(
                    NewsArticleRecord.created_by_user_id,
                    func.count(NewsArticleRecord.id),
                )
                .where(NewsArticleRecord.created_by_user_id.in_(user_ids))
                .group_by(NewsArticleRecord.created_by_user_id),
            )
            published_counts = await self._count_by_user(
                session,
                select(
                    NewsArticleRecord.created_by_user_id,
                    func.count(NewsArticleRecord.id),
                )
                .where(
                    NewsArticleRecord.created_by_user_id.in_(user_ids),
                    NewsArticleRecord.status == "published",
                )
                .group_by(NewsArticleRecord.created_by_user_id),
            )
            comment_counts = await self._count_by_user(
                session,
                select(
                    ArticleCommentRecord.user_id,
                    func.count(ArticleCommentRecord.id),
                )
                .where(ArticleCommentRecord.user_id.in_(user_ids))
                .group_by(ArticleCommentRecord.user_id),
            )
            report_counts = await self._count_by_user(
                session,
                select(
                    ArticleCommentRecord.user_id,
                    func.count(CommentReportRecord.id),
                )
                .select_from(CommentReportRecord)
                .join(
                    ArticleCommentRecord,
                    ArticleCommentRecord.id == CommentReportRecord.comment_id,
                )
                .where(ArticleCommentRecord.user_id.in_(user_ids))
                .group_by(ArticleCommentRecord.user_id),
            )

            items = [
                AdminUserListItem(
                    user=self._to_user_schema(row),
                    submitted_article_count=submitted_counts.get(row.id, 0),
                    published_article_count=published_counts.get(row.id, 0),
                    comment_count=comment_counts.get(row.id, 0),
                    report_count=report_counts.get(row.id, 0),
                )
                for row in rows
            ]
            return AdminUsersResponse(items=items, total=total or len(items))

    async def update_user(
        self,
        *,
        actor_user_id: str | None,
        user_id: str,
        payload: AdminUpdateUserRequest,
    ) -> User:
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id, admin_only=True)
            user = await self._load_user(session, user_id)

            update_data = payload.model_dump(exclude_unset=True)
            if "display_name" in update_data:
                user.display_name = (update_data["display_name"] or "").strip() or None
            if "avatar_url" in update_data:
                user.avatar_url = (update_data["avatar_url"] or "").strip() or None
            if "is_active" in update_data and update_data["is_active"] is not None:
                user.is_active = bool(update_data["is_active"])
            if "role" in update_data and update_data["role"] is not None:
                user.role = self._normalize_role(update_data["role"]) or user.role
            if (
                "stream_access_granted" in update_data
                and update_data["stream_access_granted"] is not None
            ):
                user.stream_access_granted = bool(update_data["stream_access_granted"])
            if (
                "stream_hosting_granted" in update_data
                and update_data["stream_hosting_granted"] is not None
            ):
                user.stream_hosting_granted = bool(
                    update_data["stream_hosting_granted"]
                )
            if (
                "contribution_access_granted" in update_data
                and update_data["contribution_access_granted"] is not None
            ):
                user.contribution_access_granted = bool(
                    update_data["contribution_access_granted"]
                )

            if user.id == actor.id and not user.is_active:
                raise AdminValidationError("You cannot disable your own admin account.")

            user.updated_at = datetime.utcnow()
            await session.commit()
            return self._to_user_schema(user)

    async def list_user_access_requests(
        self,
        *,
        actor_user_id: str | None,
        status: str | None = None,
        limit: int = 100,
    ) -> AdminUserAccessRequestsResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            statement = (
                select(UserAccessRequestRecord, UserRecord)
                .join(UserRecord, UserRecord.id == UserAccessRequestRecord.user_id)
                .order_by(UserAccessRequestRecord.created_at.desc())
                .limit(limit)
            )
            if status is not None and status.strip():
                statement = statement.where(
                    UserAccessRequestRecord.status == status.strip().lower()
                )
            result = await session.execute(statement)
            items = [
                self._to_user_access_request_item(request_row, user_row)
                for request_row, user_row in result.all()
            ]
            return AdminUserAccessRequestsResponse(items=items, total=len(items))

    async def review_user_access_request(
        self,
        *,
        actor_user_id: str | None,
        request_id: str,
        payload: AdminReviewUserAccessRequest,
    ) -> AdminUserAccessRequestItem:
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id, admin_only=True)
            result = await session.execute(
                select(UserAccessRequestRecord, UserRecord)
                .join(UserRecord, UserRecord.id == UserAccessRequestRecord.user_id)
                .where(UserAccessRequestRecord.id == request_id)
            )
            row = result.first()
            if row is None:
                raise AdminEntityNotFoundError("Access request was not found.")
            request_record, user = row

            if request_record.status != "pending":
                raise AdminValidationError("This access request has already been reviewed.")

            action = payload.action.strip().lower()
            request_record.status = "approved" if action == "approve" else "rejected"
            request_record.reviewed_by_user_id = actor.id
            request_record.review_note = (
                (payload.review_note or "").strip() or None
            )
            request_record.updated_at = datetime.utcnow()

            if action == "approve":
                if request_record.access_type == "stream_access":
                    user.stream_access_granted = True
                elif request_record.access_type == "stream_hosting":
                    user.stream_access_granted = True
                    user.stream_hosting_granted = True
                elif request_record.access_type == "contribution_access":
                    user.contribution_access_granted = True

            user.updated_at = datetime.utcnow()
            recipient_email = (user.email or "").strip()
            recipient_name = user.display_name
            review_note = request_record.review_note
            access_label = self._describe_user_access_type(request_record.access_type)
            await session.commit()
            if recipient_email and self._email_service.enabled:
                await self._email_service.send_access_request_reviewed_email(
                    to_email=recipient_email,
                    recipient_name=recipient_name,
                    request_label=access_label,
                    approved=action == "approve",
                    review_note=review_note,
                )
            return self._to_user_access_request_item(request_record, user)

    async def list_newsroom_access_requests(
        self,
        *,
        actor_user_id: str | None,
        status: str | None = None,
        limit: int = 100,
    ) -> AdminNewsroomAccessRequestsResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=True)
            statement = (
                select(AdminAccessRequestRecord)
                .order_by(AdminAccessRequestRecord.created_at.desc())
                .limit(limit)
            )
            if status is not None and status.strip():
                statement = statement.where(
                    AdminAccessRequestRecord.status == status.strip().lower()
                )
            result = await session.execute(statement)
            items = [
                self._to_newsroom_access_request_item(row)
                for row in result.scalars().all()
            ]
            return AdminNewsroomAccessRequestsResponse(items=items, total=len(items))

    async def review_newsroom_access_request(
        self,
        *,
        actor_user_id: str | None,
        request_id: str,
        payload: AdminReviewNewsroomAccessRequest,
    ) -> AdminNewsroomAccessRequestItem:
        async with self._session_factory() as session:
            actor = await self._load_actor(session, actor_user_id, admin_only=True)
            result = await session.execute(
                select(AdminAccessRequestRecord).where(
                    AdminAccessRequestRecord.id == request_id
                )
            )
            request_record = result.scalar_one_or_none()
            if request_record is None:
                raise AdminEntityNotFoundError("Newsroom access request was not found.")

            if request_record.status != "pending":
                raise AdminValidationError(
                    "This newsroom access request has already been reviewed."
                )

            action = payload.action.strip().lower()
            review_note = (payload.review_note or "").strip() or None
            request_record.status = "approved" if action == "approve" else "rejected"
            request_record.reviewed_by_user_id = actor.id
            request_record.review_note = review_note
            request_record.updated_at = datetime.utcnow()

            recipient_email = request_record.work_email
            recipient_name = request_record.full_name
            requested_role = request_record.requested_role
            setup_url: str | None = None

            if action == "approve":
                role = self._map_newsroom_role(requested_role)
                existing_user_result = await session.execute(
                    select(UserRecord).where(
                        func.lower(UserRecord.email) == recipient_email.lower()
                    )
                )
                user = existing_user_result.scalar_one_or_none()
                if user is None:
                    now = datetime.utcnow()
                    user = UserRecord(
                        id=f"user-{uuid4().hex[:12]}",
                        email=recipient_email,
                        password_hash=None,
                        display_name=recipient_name,
                        avatar_url=None,
                        is_active=True,
                        role=role,
                        created_at=now,
                        updated_at=now,
                    )
                    session.add(user)
                else:
                    user.email = recipient_email
                    if not (user.display_name or "").strip():
                        user.display_name = recipient_name
                    user.is_active = True
                    user.role = self._merge_newsroom_role(
                        existing_role=user.role,
                        requested_role=role,
                    )
                    user.updated_at = datetime.utcnow()

                request_record.granted_user_id = user.id
                token = self._issue_password_reset_token(
                    user_id=user.id,
                    password_hash=user.password_hash or "",
                )
                setup_url = self._build_password_reset_url(
                    reset_path="/admin/reset-password",
                    token=token,
                )

            await session.commit()
            item = self._to_newsroom_access_request_item(request_record)

        if recipient_email and self._email_service.enabled:
            if action == "approve" and setup_url:
                await self._email_service.send_newsroom_access_approved_email(
                    to_email=recipient_email,
                    recipient_name=recipient_name,
                    requested_role=requested_role,
                    setup_url=setup_url,
                    review_note=review_note,
                )
            else:
                await self._email_service.send_access_request_reviewed_email(
                    to_email=recipient_email,
                    recipient_name=recipient_name,
                    request_label=f"newsroom access ({requested_role})",
                    approved=False,
                    review_note=review_note,
                )

        return item

    async def get_cache_diagnostics(
        self,
        *,
        actor_user_id: str | None,
        cache_service: ResponseCacheService,
        ingestion_status: IngestionStatusResponse,
    ) -> CacheDiagnosticsResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)

        cache_data = cache_service.diagnostics()
        return CacheDiagnosticsResponse(
            generated_at=datetime.utcnow(),
            cache=ResponseCacheDiagnostics(
                enabled=cache_data["enabled"],
                configured=cache_data["configured"],
                client_ready=cache_data["client_ready"],
                news_top_ttl_seconds=cache_data["news_top_ttl_seconds"],
                news_latest_ttl_seconds=cache_data["news_latest_ttl_seconds"],
                polls_active_ttl_seconds=cache_data["polls_active_ttl_seconds"],
                categories_ttl_seconds=cache_data["categories_ttl_seconds"],
                tags_ttl_seconds=cache_data["tags_ttl_seconds"],
                read_count=cache_data["read_count"],
                hit_count=cache_data["hit_count"],
                miss_count=cache_data["miss_count"],
                write_count=cache_data["write_count"],
                error_count=cache_data["error_count"],
                last_error_at=cache_data["last_error_at"],
                last_error_message=cache_data["last_error_message"],
                namespaces=[
                    CacheNamespaceDiagnostics.model_validate(item)
                    for item in cache_data["namespaces"]
                ],
            ),
            ingestion=ingestion_status,
            scheduler_enabled=self._settings.enable_ingestion_scheduler,
            ingestion_interval_seconds=self._settings.ingestion_interval_seconds,
            startup_ingestion_enabled=self._settings.run_ingestion_on_startup,
        )

    async def get_analytics_overview(
        self,
        *,
        actor_user_id: str | None,
        window_days: int = 30,
    ) -> AnalyticsOverviewResponse:
        if window_days < 1 or window_days > 365:
            raise AdminValidationError("window_days must be between 1 and 365.")

        now = datetime.utcnow()
        window_start = now - timedelta(days=window_days)

        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)

            articles_created = await session.scalar(
                select(func.count(NewsArticleRecord.id)).where(
                    NewsArticleRecord.created_at >= window_start
                )
            )
            published_articles = await session.scalar(
                select(func.count(NewsArticleRecord.id)).where(
                    NewsArticleRecord.status == "published",
                    NewsArticleRecord.published_at >= window_start,
                )
            )
            comments_created = await session.scalar(
                select(func.count(ArticleCommentRecord.id)).where(
                    ArticleCommentRecord.created_at >= window_start
                )
            )
            reports_created = await session.scalar(
                select(func.count(CommentReportRecord.id)).where(
                    CommentReportRecord.created_at >= window_start
                )
            )
            users_created = await session.scalar(
                select(func.count(UserRecord.id)).where(UserRecord.created_at >= window_start)
            )
            notifications_created = await session.scalar(
                select(func.count(NotificationRecord.id)).where(
                    NotificationRecord.created_at >= window_start
                )
            )

            status_rows = await session.execute(
                select(NewsArticleRecord.status, func.count(NewsArticleRecord.id)).group_by(
                    NewsArticleRecord.status
                )
            )
            status_breakdown_rows = status_rows.all()
            verification_rows = await session.execute(
                select(
                    NewsArticleRecord.verification_status,
                    func.count(NewsArticleRecord.id),
                ).group_by(NewsArticleRecord.verification_status)
            )
            verification_breakdown_rows = verification_rows.all()

            comment_rows = await session.execute(
                select(
                    ArticleCommentRecord.article_id,
                    func.count(ArticleCommentRecord.id),
                )
                .where(ArticleCommentRecord.created_at >= window_start)
                .group_by(ArticleCommentRecord.article_id)
            )
            comment_count_by_article = {
                article_id: count for article_id, count in comment_rows.all()
            }

            event_rows = await session.execute(
                select(FeedEventRecord.article_id, func.count(FeedEventRecord.id))
                .where(
                    FeedEventRecord.created_at >= window_start,
                    FeedEventRecord.article_id.is_not(None),
                )
                .group_by(FeedEventRecord.article_id)
            )
            event_count_by_article = {
                article_id: count for article_id, count in event_rows if article_id
            }

            ranked_article_ids = sorted(
                set(comment_count_by_article.keys()) | set(event_count_by_article.keys()),
                key=lambda article_id: (
                    comment_count_by_article.get(article_id, 0)
                    + event_count_by_article.get(article_id, 0)
                ),
                reverse=True,
            )[:5]

            article_rows: list[NewsArticleRecord] = []
            if ranked_article_ids:
                result = await session.execute(
                    select(NewsArticleRecord).where(
                        NewsArticleRecord.id.in_(ranked_article_ids)
                    )
                )
                article_rows = result.scalars().all()
            article_by_id = {row.id: row for row in article_rows}

            source_article_rows = await session.execute(
                select(NewsArticleRecord.source, func.count(NewsArticleRecord.id))
                .where(NewsArticleRecord.created_at >= window_start)
                .group_by(NewsArticleRecord.source)
                .order_by(func.count(NewsArticleRecord.id).desc())
                .limit(5)
            )
            source_article_counts = source_article_rows.all()
            source_published_rows = await session.execute(
                select(NewsArticleRecord.source, func.count(NewsArticleRecord.id))
                .where(
                    NewsArticleRecord.status == "published",
                    NewsArticleRecord.published_at >= window_start,
                )
                .group_by(NewsArticleRecord.source)
            )
            published_by_source = {
                source: count for source, count in source_published_rows.all()
            }
            source_comment_rows = await session.execute(
                select(NewsArticleRecord.source, func.count(ArticleCommentRecord.id))
                .select_from(ArticleCommentRecord)
                .join(
                    NewsArticleRecord,
                    NewsArticleRecord.id == ArticleCommentRecord.article_id,
                )
                .where(ArticleCommentRecord.created_at >= window_start)
                .group_by(NewsArticleRecord.source)
            )
            comment_by_source = {
                source: count for source, count in source_comment_rows.all()
            }

        top_articles = []
        for article_id in ranked_article_ids:
            row = article_by_id.get(article_id)
            if row is None:
                continue
            top_articles.append(
                AnalyticsArticleItem(
                    article_id=row.id,
                    title=row.title,
                    source=row.source,
                    category=row.category,
                    published_at=row.published_at,
                    engagement_count=comment_count_by_article.get(row.id, 0)
                    + event_count_by_article.get(row.id, 0),
                    comment_count=comment_count_by_article.get(row.id, 0),
                )
            )

        top_sources = [
            AnalyticsSourceItem(
                source=source,
                article_count=count,
                published_count=published_by_source.get(source, 0),
                comment_count=comment_by_source.get(source, 0),
            )
            for source, count in source_article_counts
        ]

        return AnalyticsOverviewResponse(
            generated_at=now,
            window_days=window_days,
            headline_metrics=[
                AnalyticsMetricItem(label="Articles Created", value=articles_created or 0),
                AnalyticsMetricItem(label="Published", value=published_articles or 0),
                AnalyticsMetricItem(label="Comments", value=comments_created or 0),
                AnalyticsMetricItem(label="Reports", value=reports_created or 0),
                AnalyticsMetricItem(label="New Users", value=users_created or 0),
                AnalyticsMetricItem(
                    label="Notifications",
                    value=notifications_created or 0,
                ),
            ],
            article_status_breakdown=[
                AnalyticsMetricItem(label=status, value=count)
                for status, count in status_breakdown_rows
            ],
            verification_breakdown=[
                AnalyticsMetricItem(label=status, value=count)
                for status, count in verification_breakdown_rows
            ],
            top_articles=top_articles,
            top_sources=top_sources,
        )

    async def get_homepage_config(
        self,
        *,
        actor_user_id: str | None,
    ) -> AdminHomepageConfigResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            settings_record = await self._load_homepage_settings(session)
            categories = await self._load_homepage_categories(session)
            chips = await self._load_homepage_secondary_chips(session)
            placements = await self._load_homepage_story_placements(session)
            article_by_id = await self._load_homepage_articles(
                session,
                [item.article_id for item in placements],
            )

        grouped = self._group_homepage_placements(placements, article_by_id)
        return AdminHomepageConfigResponse(
            generated_at=datetime.utcnow(),
            settings=HomepageSettingsConfigItem(
                latest_autofill_enabled=settings_record.latest_autofill_enabled,
                latest_item_limit=settings_record.latest_item_limit,
                latest_window_hours=settings_record.latest_window_hours,
                latest_fallback_window_hours=settings_record.latest_fallback_window_hours,
                direct_gnews_top_publish_enabled=settings_record.direct_gnews_top_publish_enabled,
                category_autofill_enabled=settings_record.category_autofill_enabled,
                category_window_hours=settings_record.category_window_hours,
                stale_general_hours=settings_record.stale_general_hours,
                stale_world_hours=settings_record.stale_world_hours,
                stale_business_hours=settings_record.stale_business_hours,
                stale_technology_hours=settings_record.stale_technology_hours,
                stale_entertainment_hours=settings_record.stale_entertainment_hours,
                stale_science_hours=settings_record.stale_science_hours,
                stale_sports_hours=settings_record.stale_sports_hours,
                stale_health_hours=settings_record.stale_health_hours,
                stale_breaking_hours=settings_record.stale_breaking_hours,
                stale_opinion_hours=settings_record.stale_opinion_hours,
            ),
            categories=[
                HomepageCategoryConfigItem(
                    key=item.id,
                    label=item.label,
                    color_hex=item.color_hex,
                    position=item.position,
                    enabled=item.enabled,
                )
                for item in categories
            ],
            secondary_chips=[
                HomepageSecondaryChipConfigItem(
                    key=item.id,
                    label=item.label,
                    chip_type=item.chip_type,  # type: ignore[arg-type]
                    color_hex=item.color_hex,
                    position=item.position,
                    enabled=item.enabled,
                )
                for item in chips
            ],
            top_stories=grouped.get(("top", None), []),
            latest_stories=grouped.get(("latest", None), []),
            category_sections=[
                HomepageCategoryFeed(
                    key=item.id,
                    label=item.label,
                    color_hex=item.color_hex,
                    position=item.position,
                    items=[
                        placement.article
                        for placement in grouped.get(("category", item.id), [])
                    ],
                )
                for item in categories
            ],
            secondary_chip_sections=[
                HomepageSecondaryChipFeed(
                    key=item.id,
                    label=item.label,
                    chip_type=item.chip_type,
                    color_hex=item.color_hex,
                    position=item.position,
                    items=[
                        placement.article
                        for placement in grouped.get(("secondary_chip", item.id), [])
                    ],
                )
                for item in chips
            ],
        )

    async def get_article_queue_settings(
        self,
        *,
        actor_user_id: str | None,
    ) -> AdminArticleQueueSettingsResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            settings_record = await self._load_article_queue_settings(session)
            status_counts = await self._article_status_counts(session)

        return AdminArticleQueueSettingsResponse(
            generated_at=datetime.utcnow(),
            settings=ArticleQueueSettingsConfigItem(
                auto_archive_enabled=settings_record.auto_archive_enabled,
                archive_draft_after_days=settings_record.archive_draft_after_days,
                archive_review_after_days=settings_record.archive_review_after_days,
                archive_rejected_after_days=settings_record.archive_rejected_after_days,
            ),
            counts=self._to_article_queue_status_counts(status_counts),
        )

    async def update_article_queue_settings(
        self,
        *,
        actor_user_id: str | None,
        payload: ArticleQueueSettingsPatchRequest,
    ) -> AdminArticleQueueSettingsResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            settings_record = await self._load_article_queue_settings(session)
            settings_record.auto_archive_enabled = payload.auto_archive_enabled
            settings_record.archive_draft_after_days = payload.archive_draft_after_days
            settings_record.archive_review_after_days = payload.archive_review_after_days
            settings_record.archive_rejected_after_days = (
                payload.archive_rejected_after_days
            )
            settings_record.updated_at = datetime.utcnow()
            await session.commit()

        return await self.get_article_queue_settings(actor_user_id=actor_user_id)

    async def run_article_queue_auto_archive(
        self,
        *,
        actor_user_id: str | None,
    ) -> AdminArticleQueueArchiveRunResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)

        archived_count = await self._news_service.auto_archive_stale_queue_items()

        async with self._session_factory() as session:
            status_counts = await self._article_status_counts(session)

        return AdminArticleQueueArchiveRunResponse(
            generated_at=datetime.utcnow(),
            archived_count=archived_count,
            counts=self._to_article_queue_status_counts(status_counts),
        )

    async def update_homepage_settings(
        self,
        *,
        actor_user_id: str | None,
        payload: HomepageSettingsPatchRequest,
        response_cache_service: ResponseCacheService | None = None,
    ) -> AdminHomepageConfigResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            settings_record = await self._load_homepage_settings(session)
            settings_record.latest_autofill_enabled = payload.latest_autofill_enabled
            settings_record.latest_item_limit = payload.latest_item_limit
            settings_record.latest_window_hours = payload.latest_window_hours
            settings_record.latest_fallback_window_hours = (
                payload.latest_fallback_window_hours
            )
            settings_record.direct_gnews_top_publish_enabled = (
                payload.direct_gnews_top_publish_enabled
            )
            settings_record.category_autofill_enabled = payload.category_autofill_enabled
            settings_record.category_window_hours = payload.category_window_hours
            settings_record.stale_general_hours = payload.stale_general_hours
            settings_record.stale_world_hours = payload.stale_world_hours
            settings_record.stale_business_hours = payload.stale_business_hours
            settings_record.stale_technology_hours = payload.stale_technology_hours
            settings_record.stale_entertainment_hours = (
                payload.stale_entertainment_hours
            )
            settings_record.stale_science_hours = payload.stale_science_hours
            settings_record.stale_sports_hours = payload.stale_sports_hours
            settings_record.stale_health_hours = payload.stale_health_hours
            settings_record.stale_breaking_hours = payload.stale_breaking_hours
            settings_record.stale_opinion_hours = payload.stale_opinion_hours
            settings_record.updated_at = datetime.utcnow()
            await session.commit()

        if response_cache_service is not None:
            await response_cache_service.invalidate_namespace("homepage")
        return await self.get_homepage_config(actor_user_id=actor_user_id)

    async def replace_homepage_categories(
        self,
        *,
        actor_user_id: str | None,
        payload: HomepageCategoryPatchRequest,
    ) -> AdminHomepageConfigResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            await session.execute(HomepageCategoryRecord.__table__.delete())
            now = datetime.utcnow()
            for item in payload.items:
                session.add(
                    HomepageCategoryRecord(
                        id=item.key.strip(),
                        label=item.label.strip(),
                        color_hex=item.color_hex,
                        position=item.position,
                        enabled=item.enabled,
                        created_at=now,
                        updated_at=now,
                    )
                )
            await session.commit()
        return await self.get_homepage_config(actor_user_id=actor_user_id)

    async def replace_homepage_secondary_chips(
        self,
        *,
        actor_user_id: str | None,
        payload: HomepageSecondaryChipPatchRequest,
    ) -> AdminHomepageConfigResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            await session.execute(HomepageSecondaryChipRecord.__table__.delete())
            now = datetime.utcnow()
            for item in payload.items:
                session.add(
                    HomepageSecondaryChipRecord(
                        id=item.key.strip(),
                        label=item.label.strip(),
                        chip_type=item.chip_type,
                        color_hex=item.color_hex,
                        position=item.position,
                        enabled=item.enabled,
                        created_at=now,
                        updated_at=now,
                    )
                )
            await session.commit()
        return await self.get_homepage_config(actor_user_id=actor_user_id)

    async def replace_homepage_story_placements(
        self,
        *,
        actor_user_id: str | None,
        payload: HomepagePlacementPatchRequest,
        response_cache_service: ResponseCacheService | None = None,
    ) -> AdminHomepageConfigResponse:
        async with self._session_factory() as session:
            await self._load_actor(session, actor_user_id, admin_only=False)
            await self._validate_homepage_placement_targets(session, payload.items)
            await session.execute(HomepageStoryPlacementRecord.__table__.delete())
            now = datetime.utcnow()
            seen: set[tuple[str, str, str | None]] = set()
            for item in payload.items:
                target_key = item.target_key.strip() if item.target_key else None
                dedupe_key = (item.article_id.strip(), item.section, target_key)
                if dedupe_key in seen:
                    continue
                seen.add(dedupe_key)
                session.add(
                    HomepageStoryPlacementRecord(
                        article_id=item.article_id.strip(),
                        section=item.section,
                        target_key=target_key,
                        position=item.position,
                        enabled=item.enabled,
                        created_at=now,
                        updated_at=now,
                    )
                )
            await session.commit()

        if response_cache_service is not None:
            await response_cache_service.invalidate_namespace("homepage")
        return await self.get_homepage_config(actor_user_id=actor_user_id)

    async def _scheduled_count(self) -> int:
        async with self._session_factory() as session:
            now = datetime.utcnow()
            count = await session.scalar(
                select(func.count(NewsArticleRecord.id)).where(
                    NewsArticleRecord.published_at > now,
                    NewsArticleRecord.status.in_(["approved", "published"]),
                )
            )
            return count or 0

    async def _article_status_counts(
        self,
        session: AsyncSession,
    ) -> dict[str, int]:
        result = await session.execute(
            select(NewsArticleRecord.status, func.count(NewsArticleRecord.id)).group_by(
                NewsArticleRecord.status
            )
        )
        return {status: count for status, count in result.all()}

    def _to_article_queue_status_counts(
        self,
        counts: dict[str, int],
    ) -> ArticleQueueStatusCounts:
        return ArticleQueueStatusCounts(
            draft=counts.get("draft", 0),
            submitted=counts.get("submitted", 0),
            in_review=counts.get("in_review", 0),
            approved=counts.get("approved", 0),
            published=counts.get("published", 0),
            rejected=counts.get("rejected", 0),
            archived=counts.get("archived", 0),
        )

    async def _load_homepage_categories(
        self,
        session: AsyncSession,
    ) -> list[HomepageCategoryRecord]:
        result = await session.execute(
            select(HomepageCategoryRecord).order_by(
                HomepageCategoryRecord.position.asc(),
                HomepageCategoryRecord.label.asc(),
            )
        )
        return result.scalars().all()

    async def _load_homepage_settings(
        self,
        session: AsyncSession,
    ) -> HomepageSettingsRecord:
        row = await session.get(HomepageSettingsRecord, 1)
        if row is not None:
            return row

        now = datetime.utcnow()
        row = HomepageSettingsRecord(
            id=1,
            latest_autofill_enabled=self._settings.homepage_latest_autofill_enabled,
            latest_item_limit=max(1, self._settings.homepage_latest_item_limit),
            latest_window_hours=max(1, self._settings.homepage_latest_window_hours),
            latest_fallback_window_hours=max(
                1,
                self._settings.homepage_latest_fallback_window_hours,
            ),
            direct_gnews_top_publish_enabled=(
                self._settings.homepage_direct_gnews_top_publish_enabled
            ),
            category_autofill_enabled=(
                self._settings.homepage_category_autofill_enabled
            ),
            category_window_hours=max(1, self._settings.homepage_category_window_hours),
            stale_general_hours=max(1, self._settings.homepage_stale_general_hours),
            stale_world_hours=max(1, self._settings.homepage_stale_world_hours),
            stale_business_hours=max(1, self._settings.homepage_stale_business_hours),
            stale_technology_hours=max(
                1,
                self._settings.homepage_stale_technology_hours,
            ),
            stale_entertainment_hours=max(
                1,
                self._settings.homepage_stale_entertainment_hours,
            ),
            stale_science_hours=max(1, self._settings.homepage_stale_science_hours),
            stale_sports_hours=max(1, self._settings.homepage_stale_sports_hours),
            stale_health_hours=max(1, self._settings.homepage_stale_health_hours),
            stale_breaking_hours=max(1, self._settings.homepage_stale_breaking_hours),
            stale_opinion_hours=max(1, self._settings.homepage_stale_opinion_hours),
            created_at=now,
            updated_at=now,
        )
        session.add(row)
        await session.commit()
        return row

    async def _load_article_queue_settings(
        self,
        session: AsyncSession,
    ) -> ArticleQueueSettingsRecord:
        row = await session.get(ArticleQueueSettingsRecord, 1)
        if row is not None:
            return row

        now = datetime.utcnow()
        row = ArticleQueueSettingsRecord(
            id=1,
            auto_archive_enabled=self._settings.article_queue_auto_archive_enabled,
            archive_draft_after_days=max(
                1,
                self._settings.article_queue_archive_draft_after_days,
            ),
            archive_review_after_days=max(
                1,
                self._settings.article_queue_archive_review_after_days,
            ),
            archive_rejected_after_days=max(
                1,
                self._settings.article_queue_archive_rejected_after_days,
            ),
            created_at=now,
            updated_at=now,
        )
        session.add(row)
        await session.commit()
        return row

    async def _load_homepage_secondary_chips(
        self,
        session: AsyncSession,
    ) -> list[HomepageSecondaryChipRecord]:
        result = await session.execute(
            select(HomepageSecondaryChipRecord).order_by(
                HomepageSecondaryChipRecord.position.asc(),
                HomepageSecondaryChipRecord.label.asc(),
            )
        )
        return result.scalars().all()

    async def _load_homepage_story_placements(
        self,
        session: AsyncSession,
    ) -> list[HomepageStoryPlacementRecord]:
        result = await session.execute(
            select(HomepageStoryPlacementRecord).order_by(
                HomepageStoryPlacementRecord.section.asc(),
                HomepageStoryPlacementRecord.target_key.asc(),
                HomepageStoryPlacementRecord.position.asc(),
                HomepageStoryPlacementRecord.id.asc(),
            )
        )
        return result.scalars().all()

    async def _load_homepage_articles(
        self,
        session: AsyncSession,
        article_ids: list[str],
    ) -> dict[str, NewsArticleRecord]:
        normalized_ids = [item.strip() for item in article_ids if item.strip()]
        if not normalized_ids:
            return {}
        result = await session.execute(
            select(NewsArticleRecord).where(NewsArticleRecord.id.in_(normalized_ids))
        )
        return {row.id: row for row in result.scalars().all()}

    def _group_homepage_placements(
        self,
        placements: list[HomepageStoryPlacementRecord],
        article_by_id: dict[str, NewsArticleRecord],
    ) -> dict[tuple[str, str | None], list[HomepageStoryPlacementDetail]]:
        grouped: dict[tuple[str, str | None], list[HomepageStoryPlacementDetail]] = {}
        for placement in placements:
            article = article_by_id.get(placement.article_id)
            if article is None or article.status != "published":
                continue
            key = (placement.section, placement.target_key)
            grouped.setdefault(key, []).append(
                HomepageStoryPlacementDetail(
                    article=self._news_service._to_schema(article),
                    section=placement.section,  # type: ignore[arg-type]
                    target_key=placement.target_key,
                    position=placement.position,
                    enabled=placement.enabled,
                )
            )
        return grouped

    async def _validate_homepage_placement_targets(
        self,
        session: AsyncSession,
        items: list[HomepageStoryPlacementItem],
    ) -> None:
        category_ids = {
            item.target_key.strip()
            for item in items
            if item.section == "category" and (item.target_key or "").strip()
        }
        chip_ids = {
            item.target_key.strip()
            for item in items
            if item.section == "secondary_chip" and (item.target_key or "").strip()
        }

        if any(item.section in {"category", "secondary_chip"} and not (item.target_key or "").strip() for item in items):
            raise AdminValidationError(
                "Category and secondary chip placements require a target key."
            )

        if any(item.section in {"top", "latest"} and (item.target_key or "").strip() for item in items):
            raise AdminValidationError(
                "Top and latest placements must not include a target key."
            )

        if category_ids:
            result = await session.execute(
                select(HomepageCategoryRecord.id).where(
                    HomepageCategoryRecord.id.in_(category_ids)
                )
            )
            existing = set(result.scalars().all())
            missing = category_ids - existing
            if missing:
                raise AdminValidationError(
                    f"Unknown homepage categories: {', '.join(sorted(missing))}."
                )

        if chip_ids:
            result = await session.execute(
                select(HomepageSecondaryChipRecord.id).where(
                    HomepageSecondaryChipRecord.id.in_(chip_ids)
                )
            )
            existing = set(result.scalars().all())
            missing = chip_ids - existing
            if missing:
                raise AdminValidationError(
                    f"Unknown homepage secondary chips: {', '.join(sorted(missing))}."
                )

        article_ids = {item.article_id.strip() for item in items if item.article_id.strip()}
        if not article_ids:
            return
        result = await session.execute(
            select(NewsArticleRecord.id, NewsArticleRecord.status).where(
                NewsArticleRecord.id.in_(article_ids)
            )
        )
        statuses = {article_id: status for article_id, status in result.all()}
        missing_articles = article_ids - set(statuses.keys())
        if missing_articles:
            raise AdminValidationError(
                f"Unknown articles: {', '.join(sorted(missing_articles))}."
            )
        unpublished = sorted(
            article_id
            for article_id, status in statuses.items()
            if status != "published"
        )
        if unpublished:
            raise AdminValidationError(
                "Only published stories can be placed on the homepage."
            )

    async def _published_today_count(self, session: AsyncSession) -> int:
        start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        count = await session.scalar(
            select(func.count(NewsArticleRecord.id)).where(
                NewsArticleRecord.status == "published",
                NewsArticleRecord.published_at >= start,
            )
        )
        return count or 0

    async def _reported_comment_total(self, session: AsyncSession) -> int:
        count = await session.scalar(
            select(func.count(func.distinct(CommentReportRecord.comment_id)))
        )
        return count or 0

    async def _recent_workflow_activity(
        self,
        session: AsyncSession,
        *,
        limit: int,
    ) -> list[WorkflowActivityItem]:
        result = await session.execute(
            select(ArticleWorkflowEventRecord)
            .options(
                selectinload(ArticleWorkflowEventRecord.article),
                selectinload(ArticleWorkflowEventRecord.actor),
            )
            .order_by(ArticleWorkflowEventRecord.created_at.desc())
            .limit(limit)
        )
        return [self._to_workflow_activity(row) for row in result.scalars().all()]

    async def _reported_comments_preview(
        self,
        session: AsyncSession,
        *,
        limit: int,
    ) -> list[ReportedCommentItem]:
        result = await session.execute(
            select(
                ArticleCommentRecord,
                NewsArticleRecord.title,
                func.count(CommentReportRecord.id).label("report_count"),
            )
            .join(NewsArticleRecord, NewsArticleRecord.id == ArticleCommentRecord.article_id)
            .join(CommentReportRecord, CommentReportRecord.comment_id == ArticleCommentRecord.id)
            .group_by(ArticleCommentRecord.id, NewsArticleRecord.title)
            .order_by(
                func.count(CommentReportRecord.id).desc(),
                ArticleCommentRecord.updated_at.desc(),
            )
            .limit(limit)
        )
        items: list[ReportedCommentItem] = []
        for comment, article_title, report_count in result.all():
            items.append(
                ReportedCommentItem(
                    id=comment.id,
                    article_id=comment.article_id,
                    article_title=article_title,
                    author_name=comment.author_name,
                    body=comment.body,
                    status=comment.status,
                    report_count=report_count,
                    like_count=comment.like_count,
                    reply_count=comment.reply_count,
                    moderation_reason=comment.moderation_reason,
                    created_at=comment.created_at,
                    updated_at=comment.updated_at,
                )
            )
        return items

    async def _build_source_health(
        self,
        *,
        ingestion_status: IngestionStatusResponse,
        limit: int,
    ) -> list[SourceHealthItem]:
        async with self._session_factory() as session:
            result = await session.execute(
                select(NewsSourceRecord).order_by(NewsSourceRecord.id.asc())
            )
            rows = result.scalars().all()

        latest_by_source = {}
        if ingestion_status.last_run is not None:
            latest_by_source = {
                item.source_id: item for item in ingestion_status.last_run.sources
            }

        items: list[SourceHealthItem] = []
        for row in rows[:limit]:
            latest = latest_by_source.get(row.id)
            status = "idle"
            last_error = None
            fetched = 0
            inserted = 0
            deduped = 0
            if latest is not None:
                fetched = latest.fetched
                inserted = latest.inserted
                deduped = latest.deduped
                last_error = latest.errors[0] if latest.errors else None
                if latest.status == "failed":
                    status = "failing"
                elif latest.errors:
                    status = "warning"
                else:
                    status = "healthy"
            elif row.enabled and row.configured:
                status = "warning" if row.last_run_at is None else "idle"

            items.append(
                SourceHealthItem(
                    source_id=row.id,
                    source_name=row.name,
                    status=status,
                    configured=row.configured,
                    enabled=row.enabled,
                    last_run_at=row.last_run_at,
                    last_error=last_error,
                    fetched=fetched,
                    inserted=inserted,
                    deduped=deduped,
                )
            )
        return items

    async def _count_by_user(
        self,
        session: AsyncSession,
        statement,
    ) -> dict[str, int]:
        result = await session.execute(statement)
        counts: dict[str, int] = {}
        for user_id, count in result.all():
            if user_id:
                counts[str(user_id)] = int(count)
        return counts

    async def _load_actor(
        self,
        session: AsyncSession,
        actor_user_id: str | None,
        *,
        admin_only: bool,
    ) -> UserRecord:
        normalized = (actor_user_id or "").strip()
        if not normalized:
            raise MissingAdminContextError("User context is required.")
        actor = await self._load_user(session, normalized)
        if not actor.is_active:
            raise AdminPermissionError("This account is disabled.")
        allowed_roles = {"admin"} if admin_only else {"admin", "editor"}
        if actor.role not in allowed_roles:
            raise AdminPermissionError("You do not have permission for this action.")
        return actor

    async def _load_user(self, session: AsyncSession, user_id: str) -> UserRecord:
        row = await session.get(UserRecord, user_id)
        if row is None:
            raise AdminEntityNotFoundError(f"User '{user_id}' does not exist.")
        return row

    async def _load_article(
        self,
        session: AsyncSession,
        article_id: str,
    ) -> NewsArticleRecord:
        row = await session.get(NewsArticleRecord, article_id)
        if row is None:
            raise NewsArticleNotFoundError(f"Article '{article_id}' does not exist.")
        return row

    def _normalize_verification_status(self, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
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
            raise AdminValidationError("Invalid verification status.")
        return normalized

    def _normalize_article_status(self, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
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
            raise AdminValidationError("Invalid article status.")
        return normalized

    def _normalize_role(self, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        normalized = value.strip().lower()
        allowed = {"user", "contributor", "moderator", "editor", "admin"}
        if normalized not in allowed:
            raise AdminValidationError("Invalid user role.")
        return normalized

    def _describe_user_access_type(self, access_type: str) -> str:
        return {
            "stream_access": "stream access",
            "stream_hosting": "stream hosting access",
            "contribution_access": "story contribution access",
        }.get(access_type, "additional access")

    def _derive_source_configured(
        self,
        *,
        feed_url: str | None,
        api_base_url: str | None,
    ) -> bool:
        return bool((feed_url or "").strip() or (api_base_url or "").strip())

    def _to_workflow_activity(
        self,
        row: ArticleWorkflowEventRecord,
    ) -> WorkflowActivityItem:
        article_title = row.article.title if row.article is not None else row.article_id
        actor_name = row.actor.display_name if row.actor and row.actor.display_name else (
            row.actor.email if row.actor and row.actor.email else (row.actor_user_id or "System")
        )
        return WorkflowActivityItem(
            event_id=row.id,
            article_id=row.article_id,
            article_title=article_title,
            actor_user_id=row.actor_user_id,
            actor_name=actor_name,
            event_type=row.event_type,
            from_status=row.from_status,
            to_status=row.to_status,
            notes=row.notes,
            created_at=row.created_at,
        )

    def _to_source_info(self, row: NewsSourceRecord) -> NewsSourceInfo:
        return NewsSourceInfo(
            id=row.id,
            name=row.name,
            type=row.type,
            country=row.country,
            enabled=row.enabled,
            requires_api_key=row.requires_api_key,
            configured=row.configured,
            feed_url=row.feed_url,
            api_base_url=row.api_base_url,
            poll_interval_sec=row.poll_interval_sec,
            last_run_at=row.last_run_at,
            notes=row.notes,
        )

    def _to_user_schema(self, row: UserRecord) -> User:
        return User(
            id=row.id,
            email=row.email,
            display_name=row.display_name,
            avatar_url=row.avatar_url,
            is_active=row.is_active,
            role=row.role,
            stream_access_granted=row.stream_access_granted,
            stream_hosting_granted=row.stream_hosting_granted,
            contribution_access_granted=row.contribution_access_granted,
            entitlements=self._entitlements_for_user(
                user=row,
            ),
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    def _entitlements_for_user(
        self,
        *,
        user: UserRecord,
    ) -> UserEntitlements:
        role = (user.role or "").strip().lower()
        if not user.is_active:
            return UserEntitlements()
        if role in {"admin", "editor", "contributor"}:
            return UserEntitlements(
                can_access_streams=True,
                can_host_streams=True,
                can_contribute_stories=True,
            )

        return UserEntitlements(
            can_access_streams=user.stream_access_granted,
            can_host_streams=user.stream_hosting_granted,
            can_contribute_stories=user.contribution_access_granted,
        )

    def _to_user_access_request_item(
        self,
        request_row: UserAccessRequestRecord,
        user_row: UserRecord,
    ) -> AdminUserAccessRequestItem:
        return AdminUserAccessRequestItem(
            id=request_row.id,
            user_id=request_row.user_id,
            user_email=user_row.email,
            user_display_name=user_row.display_name,
            access_type=request_row.access_type,
            status=request_row.status,
            reason=request_row.reason,
            review_note=request_row.review_note,
            reviewed_by_user_id=request_row.reviewed_by_user_id,
            created_at=request_row.created_at,
            updated_at=request_row.updated_at,
        )

    def _to_newsroom_access_request_item(
        self,
        request_row: AdminAccessRequestRecord,
    ) -> AdminNewsroomAccessRequestItem:
        return AdminNewsroomAccessRequestItem(
            id=request_row.id,
            full_name=request_row.full_name,
            work_email=request_row.work_email,
            requested_role=request_row.requested_role,
            bureau=request_row.bureau,
            status=request_row.status,
            reason=request_row.reason,
            review_note=request_row.review_note,
            reviewed_by_user_id=request_row.reviewed_by_user_id,
            granted_user_id=request_row.granted_user_id,
            created_at=request_row.created_at,
            updated_at=request_row.updated_at,
        )

    def _map_newsroom_role(self, requested_role: str) -> str:
        normalized = requested_role.strip().lower()
        if "admin" in normalized:
            return "admin"
        return "editor"

    def _merge_newsroom_role(self, *, existing_role: str, requested_role: str) -> str:
        normalized_existing = (existing_role or "").strip().lower()
        if normalized_existing == "admin":
            return "admin"
        if requested_role == "admin":
            return "admin"
        if normalized_existing == "editor":
            return "editor"
        return requested_role

    def _build_password_reset_url(self, *, reset_path: str, token: str) -> str:
        if reset_path.startswith("/admin"):
            base_url = (
                self._settings.email_admin_web_base_url
                or self._settings.email_web_base_url
            )
        else:
            base_url = (
                self._settings.email_web_base_url
                or self._settings.email_admin_web_base_url
            )

        if not base_url:
            return f"{reset_path}?token={token}"

        parsed = urlparse(base_url)
        if parsed.scheme and parsed.netloc:
            target = f"{base_url.rstrip('/')}{reset_path}"
        else:
            target = reset_path

        parsed_target = urlparse(target)
        query_items = parse_qsl(parsed_target.query, keep_blank_values=True)
        query_items = [(key, value) for key, value in query_items if key != "token"]
        query_items.append(("token", token))
        return urlunparse(
            parsed_target._replace(query=urlencode(query_items, doseq=True))
        )

    def _issue_password_reset_token(
        self,
        *,
        user_id: str,
        password_hash: str,
    ) -> str:
        expiry = datetime.utcnow() + timedelta(minutes=30)
        fingerprint = self._password_hash_fingerprint(password_hash)
        payload = f"{user_id}:{int(expiry.timestamp())}:{fingerprint}:{secrets.token_hex(8)}"
        signature = hmac.new(
            self._settings.auth_token_secret.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        raw_token = f"{payload}:{signature}"
        return base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")

    def _password_hash_fingerprint(self, password_hash: str) -> str:
        return hashlib.sha256(password_hash.encode("utf-8")).hexdigest()[:16]

    def _to_notification_item(self, row: NotificationRecord):
        from app.schemas.notifications import NotificationItem

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
