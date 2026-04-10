from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import (
    get_admin_platform_service,
    get_ingestion_pipeline_service,
    get_response_cache_service,
)
from app.schemas.admin import (
    AdminArticleQueueArchiveRunResponse,
    AdminArticleQueueSettingsResponse,
    AdminHomepageConfigResponse,
    WorkflowActivityListResponse,
    AdminCreateSourceRequest,
    AdminNewsroomAccessRequestItem,
    AdminNewsroomAccessRequestsResponse,
    AdminReviewNewsroomAccessRequest,
    AdminReviewUserAccessRequest,
    AdminSourcesResponse,
    AdminUserAccessRequestItem,
    AdminUserAccessRequestsResponse,
    AdminUpdateSourceRequest,
    AdminUpdateUserRequest,
    AdminUsersResponse,
    AnalyticsOverviewResponse,
    ArticleWorkflowHistoryResponse,
    CacheDiagnosticsResponse,
    DashboardSummaryResponse,
    ArticleQueueSettingsPatchRequest,
    HomepageCategoryPatchRequest,
    HomepagePlacementPatchRequest,
    HomepageSettingsPatchRequest,
    HomepageSecondaryChipPatchRequest,
    VerificationDeskResponse,
)
from app.schemas.ingestion import IngestionRunRecord
from app.schemas.news import NewsSourceInfo
from app.schemas.users import User
from app.services.admin_platform_service import (
    AdminEntityNotFoundError,
    AdminPermissionError,
    AdminPlatformService,
    AdminValidationError,
    MissingAdminContextError,
)
from app.services.ingestion_pipeline_service import IngestionPipelineService
from app.services.ingestion_pipeline_service import IngestionAlreadyRunningError
from app.services.news_service import NewsArticleNotFoundError
from app.services.response_cache_service import ResponseCacheService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/article-queue/settings", response_model=AdminArticleQueueSettingsResponse)
async def get_admin_article_queue_settings(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminArticleQueueSettingsResponse:
    try:
        return await admin_platform_service.get_article_queue_settings(
            actor_user_id=x_user_id,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.patch("/article-queue/settings", response_model=AdminArticleQueueSettingsResponse)
async def update_admin_article_queue_settings(
    payload: ArticleQueueSettingsPatchRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminArticleQueueSettingsResponse:
    try:
        return await admin_platform_service.update_article_queue_settings(
            actor_user_id=x_user_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/article-queue/run-auto-archive",
    response_model=AdminArticleQueueArchiveRunResponse,
)
async def run_admin_article_queue_auto_archive(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminArticleQueueArchiveRunResponse:
    try:
        return await admin_platform_service.run_article_queue_auto_archive(
            actor_user_id=x_user_id,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/homepage", response_model=AdminHomepageConfigResponse)
async def get_admin_homepage_config(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminHomepageConfigResponse:
    try:
        return await admin_platform_service.get_homepage_config(
            actor_user_id=x_user_id,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.patch("/homepage/categories", response_model=AdminHomepageConfigResponse)
async def replace_admin_homepage_categories(
    payload: HomepageCategoryPatchRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> AdminHomepageConfigResponse:
    try:
        response = await admin_platform_service.replace_homepage_categories(
            actor_user_id=x_user_id,
            payload=payload,
        )
        await cache_service.invalidate_namespace("homepage")
        return response
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/homepage/secondary-chips", response_model=AdminHomepageConfigResponse)
async def replace_admin_homepage_secondary_chips(
    payload: HomepageSecondaryChipPatchRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> AdminHomepageConfigResponse:
    try:
        response = await admin_platform_service.replace_homepage_secondary_chips(
            actor_user_id=x_user_id,
            payload=payload,
        )
        await cache_service.invalidate_namespace("homepage")
        return response
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/homepage/placements", response_model=AdminHomepageConfigResponse)
async def replace_admin_homepage_placements(
    payload: HomepagePlacementPatchRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> AdminHomepageConfigResponse:
    try:
        return await admin_platform_service.replace_homepage_story_placements(
            actor_user_id=x_user_id,
            payload=payload,
            response_cache_service=cache_service,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/homepage/settings", response_model=AdminHomepageConfigResponse)
async def update_admin_homepage_settings(
    payload: HomepageSettingsPatchRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> AdminHomepageConfigResponse:
    try:
        return await admin_platform_service.update_homepage_settings(
            actor_user_id=x_user_id,
            payload=payload,
            response_cache_service=cache_service,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/dashboard/summary", response_model=DashboardSummaryResponse)
async def get_dashboard_summary(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> DashboardSummaryResponse:
    try:
        ingestion_status = await ingestion_service.get_status()
        return await admin_platform_service.get_dashboard_summary(
            actor_user_id=x_user_id,
            ingestion_status=ingestion_status,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/workflow-activity", response_model=WorkflowActivityListResponse)
async def list_workflow_activity(
    x_user_id: str | None = Header(default=None),
    actor: str | None = Query(default=None),
    role: str | None = Query(default=None),
    event_type: str | None = Query(default=None),
    date_from: str | None = Query(default=None),
    date_to: str | None = Query(default=None),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> WorkflowActivityListResponse:
    try:
        parsed_from = None if date_from is None else _parse_iso_datetime(date_from)
        parsed_to = None if date_to is None else _parse_iso_datetime(date_to)
        return await admin_platform_service.list_workflow_activity(
            actor_user_id=x_user_id,
            actor_query=actor,
            actor_role=role,
            event_type=event_type,
            date_from=parsed_from,
            date_to=parsed_to,
            offset=offset,
            limit=limit,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/articles/{article_id}/detail", response_model=ArticleWorkflowHistoryResponse)
async def get_admin_article_detail(
    article_id: str,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> ArticleWorkflowHistoryResponse:
    try:
        return await admin_platform_service.get_article_workflow_detail(
            actor_user_id=x_user_id,
            article_id=article_id,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except (AdminPermissionError,) as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except (AdminEntityNotFoundError, NewsArticleNotFoundError) as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.get("/verification/articles", response_model=VerificationDeskResponse)
async def get_verification_articles(
    verification_status: str | None = Query(default=None),
    article_status: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> VerificationDeskResponse:
    try:
        return await admin_platform_service.list_verification_articles(
            actor_user_id=x_user_id,
            verification_status=verification_status,
            article_status=article_status,
            limit=limit,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/sources", response_model=AdminSourcesResponse)
async def get_admin_sources(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminSourcesResponse:
    try:
        return await admin_platform_service.list_sources(actor_user_id=x_user_id)
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.post("/sources", response_model=NewsSourceInfo, status_code=status.HTTP_201_CREATED)
async def create_admin_source(
    payload: AdminCreateSourceRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> NewsSourceInfo:
    try:
        return await admin_platform_service.create_source(
            actor_user_id=x_user_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except IngestionAlreadyRunningError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except IngestionAlreadyRunningError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.patch("/sources/{source_id}", response_model=NewsSourceInfo)
async def update_admin_source(
    source_id: str,
    payload: AdminUpdateSourceRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> NewsSourceInfo:
    try:
        return await admin_platform_service.update_source(
            actor_user_id=x_user_id,
            source_id=source_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except IngestionAlreadyRunningError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/sources/{source_id}/test", response_model=IngestionRunRecord)
async def test_admin_source(
    source_id: str,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> IngestionRunRecord:
    try:
        await admin_platform_service.ensure_source_action_allowed(
            actor_user_id=x_user_id,
            source_id=source_id,
        )
        return await ingestion_service.run_manual(
            source_ids=[source_id],
            limit_per_source=1,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/sources/{source_id}/run", response_model=IngestionRunRecord)
async def run_admin_source(
    source_id: str,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> IngestionRunRecord:
    try:
        await admin_platform_service.ensure_source_action_allowed(
            actor_user_id=x_user_id,
            source_id=source_id,
        )
        return await ingestion_service.run_manual(source_ids=[source_id])
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/users", response_model=AdminUsersResponse)
async def get_admin_users(
    role: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminUsersResponse:
    try:
        return await admin_platform_service.list_users(
            actor_user_id=x_user_id,
            role=role,
            is_active=is_active,
            limit=limit,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/users/{user_id}", response_model=User)
async def update_admin_user(
    user_id: str,
    payload: AdminUpdateUserRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> User:
    try:
        return await admin_platform_service.update_user(
            actor_user_id=x_user_id,
            user_id=user_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/users/access-requests", response_model=AdminUserAccessRequestsResponse)
async def get_admin_user_access_requests(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminUserAccessRequestsResponse:
    try:
        return await admin_platform_service.list_user_access_requests(
            actor_user_id=x_user_id,
            status=status_filter,
            limit=limit,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/users/access-requests/{request_id}/review",
    response_model=AdminUserAccessRequestItem,
)
async def review_admin_user_access_request(
    request_id: str,
    payload: AdminReviewUserAccessRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminUserAccessRequestItem:
    try:
        return await admin_platform_service.review_user_access_request(
            actor_user_id=x_user_id,
            request_id=request_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get(
    "/newsroom/access-requests",
    response_model=AdminNewsroomAccessRequestsResponse,
)
async def get_admin_newsroom_access_requests(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminNewsroomAccessRequestsResponse:
    try:
        return await admin_platform_service.list_newsroom_access_requests(
            actor_user_id=x_user_id,
            status=status_filter,
            limit=limit,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/newsroom/access-requests/{request_id}/review",
    response_model=AdminNewsroomAccessRequestItem,
)
async def review_admin_newsroom_access_request(
    request_id: str,
    payload: AdminReviewNewsroomAccessRequest,
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AdminNewsroomAccessRequestItem:
    try:
        return await admin_platform_service.review_newsroom_access_request(
            actor_user_id=x_user_id,
            request_id=request_id,
            payload=payload,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/cache/diagnostics", response_model=CacheDiagnosticsResponse)
async def get_cache_diagnostics(
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
    cache_service: ResponseCacheService = Depends(get_response_cache_service),
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> CacheDiagnosticsResponse:
    try:
        ingestion_status = await ingestion_service.get_status()
        return await admin_platform_service.get_cache_diagnostics(
            actor_user_id=x_user_id,
            cache_service=cache_service,
            ingestion_status=ingestion_status,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/analytics/overview", response_model=AnalyticsOverviewResponse)
async def get_analytics_overview(
    days: int = Query(default=30, ge=1, le=365),
    x_user_id: str | None = Header(default=None),
    admin_platform_service: AdminPlatformService = Depends(get_admin_platform_service),
) -> AnalyticsOverviewResponse:
    try:
        return await admin_platform_service.get_analytics_overview(
            actor_user_id=x_user_id,
            window_days=days,
        )
    except MissingAdminContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except AdminEntityNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AdminPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except AdminValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
