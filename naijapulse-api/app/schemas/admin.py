from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

from app.schemas.comments import ReportedCommentItem
from app.schemas.ingestion import IngestionStatusResponse
from app.schemas.news import (
    HomepageCategoryFeed,
    HomepageSecondaryChipFeed,
    NewsArticle,
    NewsSourceInfo,
)
from app.schemas.notifications import NotificationItem
from app.schemas.users import User


class DashboardKpiItem(BaseModel):
    key: str
    label: str
    value: int = Field(..., ge=0)
    tone: Literal["neutral", "success", "warning", "danger", "info"] = "neutral"


class WorkflowActivityItem(BaseModel):
    event_id: int
    article_id: str
    article_title: str
    actor_user_id: Optional[str] = None
    actor_name: str
    event_type: str
    from_status: Optional[str] = None
    to_status: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime


class SourceHealthItem(BaseModel):
    source_id: str
    source_name: str
    status: Literal["healthy", "warning", "failing", "idle"]
    configured: bool
    enabled: bool
    last_run_at: Optional[datetime] = None
    last_error: Optional[str] = None
    fetched: int = Field(default=0, ge=0)
    inserted: int = Field(default=0, ge=0)
    deduped: int = Field(default=0, ge=0)


class DashboardEditorialQueue(BaseModel):
    submitted: int = Field(default=0, ge=0)
    approved: int = Field(default=0, ge=0)
    rejected: int = Field(default=0, ge=0)
    scheduled: int = Field(default=0, ge=0)


class DashboardSummaryResponse(BaseModel):
    generated_at: datetime
    kpis: List[DashboardKpiItem] = Field(default_factory=list)
    editorial_queue: DashboardEditorialQueue
    recent_workflow_activity: List[WorkflowActivityItem] = Field(default_factory=list)
    reported_comments: List[ReportedCommentItem] = Field(default_factory=list)
    source_health: List[SourceHealthItem] = Field(default_factory=list)
    ingestion: Optional[IngestionStatusResponse] = None


class ArticleWorkflowHistoryResponse(BaseModel):
    article: NewsArticle
    workflow_events: List[WorkflowActivityItem] = Field(default_factory=list)
    related_notifications: List[NotificationItem] = Field(default_factory=list)
    reported_comment_count: int = Field(default=0, ge=0)
    total_comment_count: int = Field(default=0, ge=0)


class VerificationDeskCounts(BaseModel):
    unverified: int = Field(default=0, ge=0)
    developing: int = Field(default=0, ge=0)
    verified: int = Field(default=0, ge=0)
    fact_checked: int = Field(default=0, ge=0)
    opinion: int = Field(default=0, ge=0)
    sponsored: int = Field(default=0, ge=0)


class VerificationDeskResponse(BaseModel):
    items: List[NewsArticle] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)
    counts: VerificationDeskCounts


class AdminCreateSourceRequest(BaseModel):
    id: str = Field(..., min_length=2, max_length=80)
    name: str = Field(..., min_length=2, max_length=255)
    type: str = Field(..., min_length=2, max_length=80)
    country: Optional[str] = Field(default=None, max_length=8)
    enabled: bool = True
    feed_url: Optional[str] = Field(default=None, max_length=4096)
    api_base_url: Optional[str] = Field(default=None, max_length=4096)
    poll_interval_sec: int = Field(default=900, ge=60, le=86400)
    notes: Optional[str] = Field(default=None, max_length=5000)


class AdminUpdateSourceRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=255)
    type: Optional[str] = Field(default=None, min_length=2, max_length=80)
    country: Optional[str] = Field(default=None, max_length=8)
    enabled: Optional[bool] = None
    configured: Optional[bool] = None
    feed_url: Optional[str] = Field(default=None, max_length=4096)
    api_base_url: Optional[str] = Field(default=None, max_length=4096)
    poll_interval_sec: Optional[int] = Field(default=None, ge=60, le=86400)
    notes: Optional[str] = Field(default=None, max_length=5000)


class AdminSourcesResponse(BaseModel):
    items: List[NewsSourceInfo] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)


class AdminUserListItem(BaseModel):
    user: User
    submitted_article_count: int = Field(default=0, ge=0)
    published_article_count: int = Field(default=0, ge=0)
    comment_count: int = Field(default=0, ge=0)
    report_count: int = Field(default=0, ge=0)


class AdminUsersResponse(BaseModel):
    items: List[AdminUserListItem] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)


class AdminUpdateUserRequest(BaseModel):
    display_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    avatar_url: Optional[str] = Field(default=None, max_length=4096)
    is_active: Optional[bool] = None
    role: Optional[
        Literal["user", "contributor", "moderator", "editor", "admin"]
    ] = None
    stream_access_granted: Optional[bool] = None
    stream_hosting_granted: Optional[bool] = None
    contribution_access_granted: Optional[bool] = None


class AdminUserAccessRequestItem(BaseModel):
    id: str
    user_id: str
    user_email: Optional[str] = None
    user_display_name: Optional[str] = None
    access_type: Literal["stream_access", "stream_hosting", "contribution_access"]
    status: Literal["pending", "approved", "rejected"] = "pending"
    reason: str
    review_note: Optional[str] = None
    reviewed_by_user_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class AdminUserAccessRequestsResponse(BaseModel):
    items: List[AdminUserAccessRequestItem] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)


class AdminReviewUserAccessRequest(BaseModel):
    action: Literal["approve", "reject"]
    review_note: Optional[str] = Field(default=None, max_length=2000)


class CacheNamespaceDiagnostics(BaseModel):
    namespace: str
    version: int = Field(..., ge=1)


class ResponseCacheDiagnostics(BaseModel):
    enabled: bool
    configured: bool
    client_ready: bool
    news_top_ttl_seconds: int = Field(..., ge=0)
    news_latest_ttl_seconds: int = Field(..., ge=0)
    polls_active_ttl_seconds: int = Field(..., ge=0)
    categories_ttl_seconds: int = Field(..., ge=0)
    tags_ttl_seconds: int = Field(..., ge=0)
    read_count: int = Field(default=0, ge=0)
    hit_count: int = Field(default=0, ge=0)
    miss_count: int = Field(default=0, ge=0)
    write_count: int = Field(default=0, ge=0)
    error_count: int = Field(default=0, ge=0)
    last_error_at: Optional[datetime] = None
    last_error_message: Optional[str] = None
    namespaces: List[CacheNamespaceDiagnostics] = Field(default_factory=list)


class CacheDiagnosticsResponse(BaseModel):
    generated_at: datetime
    cache: ResponseCacheDiagnostics
    ingestion: IngestionStatusResponse
    scheduler_enabled: bool
    ingestion_interval_seconds: int = Field(..., ge=0)
    startup_ingestion_enabled: bool


class AnalyticsMetricItem(BaseModel):
    label: str
    value: int = Field(..., ge=0)


class AnalyticsArticleItem(BaseModel):
    article_id: str
    title: str
    source: str
    category: str
    published_at: datetime
    engagement_count: int = Field(default=0, ge=0)
    comment_count: int = Field(default=0, ge=0)


class AnalyticsSourceItem(BaseModel):
    source: str
    article_count: int = Field(default=0, ge=0)
    published_count: int = Field(default=0, ge=0)
    comment_count: int = Field(default=0, ge=0)


class AnalyticsOverviewResponse(BaseModel):
    generated_at: datetime
    window_days: int = Field(..., ge=1)
    headline_metrics: List[AnalyticsMetricItem] = Field(default_factory=list)
    article_status_breakdown: List[AnalyticsMetricItem] = Field(default_factory=list)
    verification_breakdown: List[AnalyticsMetricItem] = Field(default_factory=list)
    top_articles: List[AnalyticsArticleItem] = Field(default_factory=list)
    top_sources: List[AnalyticsSourceItem] = Field(default_factory=list)


class HomepageCategoryConfigItem(BaseModel):
    key: str = Field(..., min_length=2, max_length=80)
    label: str = Field(..., min_length=2, max_length=120)
    color_hex: Optional[str] = Field(default=None, max_length=7)
    position: int = Field(default=0, ge=0)
    enabled: bool = True


class HomepageSecondaryChipConfigItem(BaseModel):
    key: str = Field(..., min_length=2, max_length=80)
    label: str = Field(..., min_length=2, max_length=120)
    chip_type: Literal["tag", "live"] = "tag"
    color_hex: Optional[str] = Field(default=None, max_length=7)
    position: int = Field(default=0, ge=0)
    enabled: bool = True


class HomepageStoryPlacementItem(BaseModel):
    article_id: str = Field(..., min_length=2, max_length=96)
    section: Literal["top", "latest", "category", "secondary_chip"]
    target_key: Optional[str] = Field(default=None, max_length=80)
    position: int = Field(default=0, ge=0)
    enabled: bool = True


class HomepageStoryPlacementDetail(BaseModel):
    article: NewsArticle
    section: Literal["top", "latest", "category", "secondary_chip"]
    target_key: Optional[str] = None
    position: int = Field(default=0, ge=0)
    enabled: bool = True


class HomepageCategoryPatchRequest(BaseModel):
    items: List[HomepageCategoryConfigItem] = Field(default_factory=list)


class HomepageSecondaryChipPatchRequest(BaseModel):
    items: List[HomepageSecondaryChipConfigItem] = Field(default_factory=list)


class HomepagePlacementPatchRequest(BaseModel):
    items: List[HomepageStoryPlacementItem] = Field(default_factory=list)


class AdminHomepageConfigResponse(BaseModel):
    generated_at: datetime
    categories: List[HomepageCategoryConfigItem] = Field(default_factory=list)
    secondary_chips: List[HomepageSecondaryChipConfigItem] = Field(default_factory=list)
    top_stories: List[HomepageStoryPlacementDetail] = Field(default_factory=list)
    latest_stories: List[HomepageStoryPlacementDetail] = Field(default_factory=list)
    category_sections: List[HomepageCategoryFeed] = Field(default_factory=list)
    secondary_chip_sections: List[HomepageSecondaryChipFeed] = Field(default_factory=list)
