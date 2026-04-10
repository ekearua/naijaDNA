from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_news_service, get_response_cache_service
from app.schemas.news import (
    AdminArticleWorkflowRequest,
    AdminCreateNewsArticleRequest,
    AdminUpdateNewsArticleRequest,
    NewsArticle,
    NewsListResponse,
)
from app.services.news_service import (
    DuplicateNewsArticleError,
    InvalidNewsPayloadError,
    NewsArticleNotFoundError,
    NewsPermissionError,
    NewsService,
    NewsStateError,
    UserNotFoundError,
)
from app.services.response_cache_service import ResponseCacheService

router = APIRouter(prefix="/admin/articles", tags=["admin-articles"])


@router.get("", response_model=NewsListResponse)
async def list_admin_articles(
    x_user_id: str | None = Header(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    statuses_filter: str | None = Query(default=None, alias="statuses"),
    query: str | None = Query(default=None, alias="q"),
    source: str | None = Query(default=None),
    tag: str | None = Query(default=None),
    published_from: str | None = Query(default=None),
    published_to: str | None = Query(default=None),
    sort: str | None = Query(default=None),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    news_service: NewsService = Depends(get_news_service),
) -> NewsListResponse:
    try:
        parsed_from = None if published_from is None else _parse_iso_datetime(published_from)
        parsed_to = None if published_to is None else _parse_iso_datetime(published_to)
        parsed_statuses = None
        if statuses_filter is not None and statuses_filter.strip():
            parsed_statuses = [
                item.strip()
                for item in statuses_filter.split(",")
                if item.strip()
            ]
        items, total = await news_service.list_admin_articles(
            actor_user_id=x_user_id or "",
            status=status_filter,
            statuses=parsed_statuses,
            query=query,
            source=source,
            tag=tag,
            published_from=parsed_from,
            published_to=parsed_to,
            sort=sort,
            offset=offset,
            limit=limit,
        )
        return NewsListResponse(items=items, total=total, offset=offset, limit=limit)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except NewsPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("", response_model=NewsArticle, status_code=status.HTTP_201_CREATED)
async def create_admin_article(
    payload: AdminCreateNewsArticleRequest,
    x_user_id: str | None = Header(default=None),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsArticle:
    try:
        article = await news_service.create_admin_article(
            actor_user_id=x_user_id or "",
            payload=payload,
        )
        await response_cache_service.invalidate_namespace("news")
        return article
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except NewsPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except DuplicateNewsArticleError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


def _parse_iso_datetime(value: str):
    try:
        return datetime.fromisoformat(value.strip())
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid datetime value '{value}'. Use ISO-8601 format.",
        ) from exc


@router.patch("/{article_id}", response_model=NewsArticle)
async def update_admin_article(
    article_id: str,
    payload: AdminUpdateNewsArticleRequest,
    x_user_id: str | None = Header(default=None),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsArticle:
    try:
        article = await news_service.update_admin_article(
            actor_user_id=x_user_id or "",
            article_id=article_id,
            payload=payload,
        )
        await response_cache_service.invalidate_namespace("news")
        return article
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except NewsPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/{article_id}/{action}", response_model=NewsArticle)
async def transition_admin_article(
    article_id: str,
    action: str,
    payload: AdminArticleWorkflowRequest,
    x_user_id: str | None = Header(default=None),
    news_service: NewsService = Depends(get_news_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> NewsArticle:
    try:
        article = await news_service.transition_admin_article(
            actor_user_id=x_user_id or "",
            article_id=article_id,
            action=action,
            notes=payload.notes,
            target_status=payload.target_status,
        )
        await response_cache_service.invalidate_namespace("news")
        return article
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except NewsPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except NewsStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidNewsPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
