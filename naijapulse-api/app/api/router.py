from fastapi import APIRouter

from app.api.routers.auth import router as auth_router
from app.api.routers.admin_ingestion import router as ingestion_router
from app.api.routers.admin_articles import router as admin_articles_router
from app.api.routers.admin_platform import router as admin_platform_router
from app.api.routers.categories import router as categories_router
from app.api.routers.comments import router as comments_router
from app.api.routers.health import router as health_router
from app.api.routers.live_updates import router as live_updates_router
from app.api.routers.news import router as news_router
from app.api.routers.notifications import router as notifications_router
from app.api.routers.personalization import router as personalization_router
from app.api.routers.polls import router as polls_router
from app.api.routers.tags import router as tags_router
from app.api.routers.streams import router as streams_router
from app.api.routers.users import router as users_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(news_router)
api_router.include_router(live_updates_router)
api_router.include_router(admin_articles_router)
api_router.include_router(admin_platform_router)
api_router.include_router(comments_router)
api_router.include_router(polls_router)
api_router.include_router(categories_router)
api_router.include_router(tags_router)
api_router.include_router(streams_router)
api_router.include_router(notifications_router)
api_router.include_router(personalization_router)
api_router.include_router(users_router)
# Admin ingestion endpoints are grouped but still exposed under the same API prefix.
api_router.include_router(ingestion_router)
