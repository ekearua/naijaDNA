from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import (
    get_article_readability_service,
    get_news_service,
    get_response_cache_service,
    get_source_registry_service,
)
from app.schemas.news import (
    CreateNewsArticleRequest,
    HomepageContentResponse,
    NewsArticle,
    NewsListResponse,
    NewsReadableTextResponse,
    NewsSourcesResponse,
)
from app.services.article_readability_service import ArticleReadabilityService
from app.services.news_service import (
    DuplicateNewsArticleError,
    InvalidNewsPayloadError,
    NewsArticleNotFoundError,
    NewsPermissionError,
    NewsService,
    UserNotFoundError,
)
from app.services.response_cache_service import ResponseCacheService
from app.services.source_registry_service import SourceRegistryService

router = APIRouter(prefix="/news", tags=["news"])


@router.get("/homepage", response_model=HomepageContentResponse)
async def get_homepage_content(
    news_service: NewsService = Depends(get_news_service),
) -> HomepageContentResponse:
    return await news_service.get_homepage_content()


@router.get("/top", response_model=NewsListResponse)
async def get_top_stories(
    limit: int = Query(default=10, ge=1, le=50),
    category: str | None = Query(default=None),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsListResponse:
    """Return top stories for home hero sections."""
    cache_identifier = f"top:limit={limit}:category={(category or '').strip().lower()}"
    cached = await response_cache_service.get_json(
        namespace="news",
        identifier=cache_identifier,
    )
    if cached is not None:
        return NewsListResponse.model_validate(cached)

    items = await news_service.get_top_stories(limit=limit, category=category)
    response = NewsListResponse(items=items, total=len(items))
    await response_cache_service.set_json(
        namespace="news",
        identifier=cache_identifier,
        value=response.model_dump(mode="json"),
        ttl_seconds=response_cache_service.news_top_ttl_seconds,
    )
    return response


@router.get("/latest", response_model=NewsListResponse)
async def get_latest_stories(
    limit: int = Query(default=20, ge=1, le=100),
    category: str | None = Query(default=None),
    diversify_sources: bool = Query(default=True),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsListResponse:
    """Return most recent stories sorted by publish timestamp."""
    cache_identifier = (
        f"latest:limit={limit}:category={(category or '').strip().lower()}:"
        f"diversify={str(diversify_sources).lower()}"
    )
    cached = await response_cache_service.get_json(
        namespace="news",
        identifier=cache_identifier,
    )
    if cached is not None:
        return NewsListResponse.model_validate(cached)

    items = await news_service.get_latest_stories(
        limit=limit,
        category=category,
        diversify_sources=diversify_sources,
    )
    response = NewsListResponse(items=items, total=len(items))
    await response_cache_service.set_json(
        namespace="news",
        identifier=cache_identifier,
        value=response.model_dump(mode="json"),
        ttl_seconds=response_cache_service.news_latest_ttl_seconds,
    )
    return response


@router.get("/search", response_model=NewsListResponse)
async def search_news(
    q: str = Query(..., min_length=2, max_length=120),
    limit: int = Query(default=25, ge=1, le=100),
    category: str | None = Query(default=None),
    news_service: NewsService = Depends(get_news_service),
) -> NewsListResponse:
    """Search news by keyword in title/source/summary."""
    items = await news_service.search_stories(
        query=q,
        limit=limit,
        category=category,
    )
    return NewsListResponse(items=items, total=len(items))


@router.get("/sources", response_model=NewsSourcesResponse)
async def get_news_sources(
    source_registry_service: SourceRegistryService = Depends(get_source_registry_service),
) -> NewsSourcesResponse:
    """List configured source registry entries and operational metadata."""
    items = await source_registry_service.list_sources()
    return NewsSourcesResponse(items=items)


@router.get("/{article_id}", response_model=NewsArticle)
async def get_news_article(
    article_id: str,
    news_service: NewsService = Depends(get_news_service),
) -> NewsArticle:
    try:
        return await news_service.get_story(article_id)
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{article_id}/readable-text", response_model=NewsReadableTextResponse)
async def get_news_article_readable_text(
    article_id: str,
    news_service: NewsService = Depends(get_news_service),
    article_readability_service: ArticleReadabilityService = Depends(
        get_article_readability_service
    ),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsReadableTextResponse:
    cache_identifier = f"readable-text:{article_id.strip()}"
    cached = await response_cache_service.get_json(
        namespace="news",
        identifier=cache_identifier,
    )
    if cached is not None:
        return NewsReadableTextResponse.model_validate(cached)

    try:
        article = await news_service.get_story(article_id)
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    readable = await article_readability_service.get_readable_text(article)
    await response_cache_service.set_json(
        namespace="news",
        identifier=cache_identifier,
        value=readable.model_dump(mode="json"),
        ttl_seconds=response_cache_service.news_latest_ttl_seconds,
    )
    return readable


@router.post("", response_model=NewsArticle, status_code=status.HTTP_201_CREATED)
async def create_news_article(
    payload: CreateNewsArticleRequest,
    x_user_id: str | None = Header(default=None),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsArticle:
    """Create one user-submitted article."""
    try:
        article = await news_service.create_user_article(
            user_id=x_user_id or "",
            payload=payload,
        )
        await response_cache_service.invalidate_namespace("news")
        return article
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except DuplicateNewsArticleError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except NewsPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
