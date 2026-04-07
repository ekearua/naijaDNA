from fastapi import Request

from app.services.article_comments_service import ArticleCommentsService
from app.services.admin_platform_service import AdminPlatformService
from app.services.article_readability_service import ArticleReadabilityService
from app.services.ingestion_pipeline_service import IngestionPipelineService
from app.services.live_updates_service import LiveUpdatesService
from app.services.livekit_service import LiveKitService
from app.services.news_service import NewsService
from app.services.notifications_service import NotificationsService
from app.services.personalization_service import PersonalizationService
from app.services.polls_service import PollsService
from app.services.response_cache_service import ResponseCacheService
from app.services.source_registry_service import SourceRegistryService
from app.services.streams_service import StreamsService
from app.services.users_service import UsersService


def get_news_service(request: Request) -> NewsService:
    """Resolve singleton NewsService from app state."""
    return request.app.state.news_service


def get_article_readability_service(request: Request) -> ArticleReadabilityService:
    """Resolve singleton ArticleReadabilityService from app state."""
    return request.app.state.article_readability_service


def get_article_comments_service(request: Request) -> ArticleCommentsService:
    """Resolve singleton ArticleCommentsService from app state."""
    return request.app.state.article_comments_service


def get_admin_platform_service(request: Request) -> AdminPlatformService:
    """Resolve singleton AdminPlatformService from app state."""
    return request.app.state.admin_platform_service


def get_polls_service(request: Request) -> PollsService:
    """Resolve singleton PollsService from app state."""
    return request.app.state.polls_service


def get_source_registry_service(request: Request) -> SourceRegistryService:
    """Resolve singleton SourceRegistryService from app state."""
    return request.app.state.source_registry_service


def get_ingestion_pipeline_service(request: Request) -> IngestionPipelineService:
    """Resolve singleton IngestionPipelineService from app state."""
    return request.app.state.ingestion_pipeline_service


def get_users_service(request: Request) -> UsersService:
    """Resolve singleton UsersService from app state."""
    return request.app.state.users_service


def get_personalization_service(request: Request) -> PersonalizationService:
    """Resolve singleton PersonalizationService from app state."""
    return request.app.state.personalization_service


def get_streams_service(request: Request) -> StreamsService:
    """Resolve singleton StreamsService from app state."""
    return request.app.state.streams_service


def get_notifications_service(request: Request) -> NotificationsService:
    """Resolve singleton NotificationsService from app state."""
    return request.app.state.notifications_service


def get_livekit_service(request: Request) -> LiveKitService:
    """Resolve singleton LiveKitService from app state."""
    return request.app.state.livekit_service


def get_live_updates_service(request: Request) -> LiveUpdatesService:
    """Resolve singleton LiveUpdatesService from app state."""
    return request.app.state.live_updates_service


def get_response_cache_service(request: Request) -> ResponseCacheService:
    """Resolve singleton ResponseCacheService from app state."""
    return request.app.state.response_cache_service
