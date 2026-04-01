from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_polls_service, get_response_cache_service
from app.schemas.tags import CreateFeedTagRequest, FeedTag, FeedTagsResponse
from app.services.polls_service import (
    FeedTagAlreadyExistsError,
    InvalidPollPayloadError,
    PollsService,
)
from app.services.response_cache_service import ResponseCacheService

router = APIRouter(prefix="/tags", tags=["tags"])


@router.get("", response_model=FeedTagsResponse)
async def list_feed_tags(
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> FeedTagsResponse:
    """List active feed tags shown in the home trust/tag strip."""
    cached = await response_cache_service.get_json(
        namespace="tags",
        identifier="list",
    )
    if cached is not None:
        return FeedTagsResponse.model_validate(cached)

    items = await polls_service.list_feed_tags()
    response = FeedTagsResponse(items=items, total=len(items))
    await response_cache_service.set_json(
        namespace="tags",
        identifier="list",
        value=response.model_dump(mode="json"),
        ttl_seconds=response_cache_service.tags_ttl_seconds,
    )
    return response


@router.post("", response_model=FeedTag, status_code=status.HTTP_201_CREATED)
async def create_feed_tag(
    payload: CreateFeedTagRequest,
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> FeedTag:
    """Create one feed tag for homepage trust/tag strip rendering."""
    try:
        tag = await polls_service.create_feed_tag(
            name=payload.name,
            color_hex=payload.color_hex,
            description=payload.description,
            tag_id=payload.id,
            position=payload.position,
            is_active=payload.is_active,
        )
        await response_cache_service.invalidate_namespace("tags")
        return tag
    except FeedTagAlreadyExistsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidPollPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
