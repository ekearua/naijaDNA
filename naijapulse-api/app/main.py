"""FastAPI application entrypoint with app-wide service lifecycle wiring."""

import asyncio
import logging
from contextlib import asynccontextmanager, suppress

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import get_settings
from app.db.session import DatabaseSessionManager
from app.services.article_comments_service import ArticleCommentsService
from app.services.admin_platform_service import AdminPlatformService
from app.services.article_readability_service import ArticleReadabilityService
from app.services.email_service import EmailService
from app.services.ingestion_pipeline_service import IngestionPipelineService
from app.services.livekit_service import LiveKitService
from app.services.news_service import NewsService
from app.services.notifications_service import NotificationsService
from app.services.personalization_service import PersonalizationService
from app.services.polls_service import PollsService
from app.services.push_notification_service import PushNotificationService
from app.services.response_cache_service import ResponseCacheService
from app.services.source_registry_service import SourceRegistryService
from app.services.streams_service import StreamsService
from app.services.users_service import UsersService

settings = get_settings()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = DatabaseSessionManager(
        settings.database_url,
        echo=settings.database_echo,
    )
    session_factory = app.state.db.session_factory

    # Core services are created once on startup and reused per request.
    app.state.push_notification_service = PushNotificationService(
        service_account_json=settings.firebase_service_account_json,
    )
    app.state.email_service = EmailService(
        enabled=settings.email_enabled,
        smtp_host=settings.email_smtp_host,
        smtp_port=settings.email_smtp_port,
        smtp_username=settings.email_smtp_username,
        smtp_password=settings.email_smtp_password,
        smtp_security=settings.email_smtp_security,
        from_address=settings.email_from_address,
        from_name=settings.email_from_name,
        reply_to=settings.email_reply_to,
        support_address=settings.email_support_address,
    )
    app.state.notifications_service = NotificationsService(
        session_factory=session_factory,
        push_service=app.state.push_notification_service,
    )
    app.state.news_service = NewsService(
        session_factory=session_factory,
        notifications_service=app.state.notifications_service,
    )
    app.state.article_readability_service = ArticleReadabilityService()
    app.state.article_comments_service = ArticleCommentsService(
        session_factory=session_factory,
        notifications_service=app.state.notifications_service,
    )
    app.state.admin_platform_service = AdminPlatformService(
        session_factory=session_factory,
        news_service=app.state.news_service,
        email_service=app.state.email_service,
        settings=settings,
    )
    app.state.users_service = UsersService(
        session_factory=session_factory,
        token_secret=settings.auth_token_secret,
        access_token_ttl_seconds=settings.auth_access_token_ttl_seconds,
        email_service=app.state.email_service,
        email_web_base_url=settings.email_web_base_url,
        email_admin_web_base_url=settings.email_admin_web_base_url,
    )
    app.state.polls_service = PollsService(session_factory=session_factory)
    app.state.personalization_service = PersonalizationService(
        session_factory=session_factory
    )
    app.state.response_cache_service = ResponseCacheService(
        rest_url=settings.upstash_redis_rest_url,
        rest_token=settings.upstash_redis_rest_token,
        enabled=settings.response_cache_enabled,
        news_top_ttl_seconds=settings.cache_news_top_ttl_seconds,
        news_latest_ttl_seconds=settings.cache_news_latest_ttl_seconds,
        polls_active_ttl_seconds=settings.cache_polls_active_ttl_seconds,
        categories_ttl_seconds=settings.cache_categories_ttl_seconds,
        tags_ttl_seconds=settings.cache_tags_ttl_seconds,
    )
    await app.state.response_cache_service.startup()
    await app.state.article_readability_service.startup()
    app.state.streams_service = StreamsService(
        session_factory=session_factory,
        viewer_presence_ttl_seconds=settings.stream_viewer_presence_ttl_seconds,
    )
    app.state.livekit_service = LiveKitService(
        url=settings.livekit_url,
        api_key=settings.livekit_api_key,
        api_secret=settings.livekit_api_secret,
        token_ttl_seconds=settings.livekit_token_ttl_seconds,
    )
    app.state.source_registry_service = SourceRegistryService(
        session_factory=session_factory,
        settings=settings,
    )
    await app.state.source_registry_service.initialize_defaults()
    await app.state.polls_service.initialize_defaults()
    await app.state.news_service.initialize_defaults()
    app.state.ingestion_pipeline_service = IngestionPipelineService(
        news_service=app.state.news_service,
        source_registry_service=app.state.source_registry_service,
        response_cache_service=app.state.response_cache_service,
        max_recent_runs=settings.ingestion_max_recent_runs,
        default_limit_per_source=settings.ingestion_default_limit_per_source,
    )
    app.state.startup_ingestion_task = None
    # Pull fresh news once on boot in a detached task so request handling starts immediately.
    if settings.run_ingestion_on_startup:

        async def _startup_ingestion() -> None:
            try:
                await asyncio.wait_for(
                    app.state.ingestion_pipeline_service.run_manual(
                        limit_per_source=settings.ingestion_startup_limit_per_source
                    ),
                    timeout=settings.ingestion_startup_timeout_seconds,
                )
            except asyncio.TimeoutError:
                logger.warning(
                    "Startup ingestion timed out after %ss; server remains healthy and ready.",
                    settings.ingestion_startup_timeout_seconds,
                )
            except Exception:
                logger.exception("Startup ingestion failed; server remains healthy and ready.")

        app.state.startup_ingestion_task = asyncio.create_task(_startup_ingestion())

    scheduler = AsyncIOScheduler(timezone="UTC")
    app.state.scheduler = scheduler
    if settings.enable_ingestion_scheduler:
        # Single periodic job for pull-based ingestion.
        scheduler.add_job(
            app.state.ingestion_pipeline_service.run_scheduled,
            trigger="interval",
            seconds=settings.ingestion_interval_seconds,
            id="news_ingestion_job",
            replace_existing=True,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=60,
        )
        scheduler.start()

    yield

    # Ensure scheduler threads are stopped during application shutdown.
    if scheduler.running:
        scheduler.shutdown(wait=False)
    startup_task = getattr(app.state, "startup_ingestion_task", None)
    if startup_task is not None and not startup_task.done():
        startup_task.cancel()
        with suppress(asyncio.CancelledError):
            await startup_task
    await app.state.response_cache_service.shutdown()
    await app.state.article_readability_service.shutdown()
    await app.state.db.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.api_prefix)
