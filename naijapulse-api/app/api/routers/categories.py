from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_polls_service, get_response_cache_service
from app.schemas.categories import Category, CategoriesResponse, CreateCategoryRequest
from app.services.polls_service import (
    CategoryAlreadyExistsError,
    InvalidPollPayloadError,
    PollsService,
)
from app.services.response_cache_service import ResponseCacheService

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=CategoriesResponse)
async def list_categories(
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> CategoriesResponse:
    """List available poll/news categories."""
    cached = await response_cache_service.get_json(
        namespace="categories",
        identifier="list",
    )
    if cached is not None:
        return CategoriesResponse.model_validate(cached)

    items = await polls_service.list_categories()
    response = CategoriesResponse(items=items, total=len(items))
    await response_cache_service.set_json(
        namespace="categories",
        identifier="list",
        value=response.model_dump(mode="json"),
        ttl_seconds=response_cache_service.categories_ttl_seconds,
    )
    return response


@router.post("", response_model=Category, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CreateCategoryRequest,
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> Category:
    """Create a category that can be referenced by user-created polls."""
    try:
        category = await polls_service.create_category(
            name=payload.name,
            color_hex=payload.color_hex,
            description=payload.description,
            category_id=payload.id,
        )
        await response_cache_service.invalidate_namespace("categories")
        return category
    except CategoryAlreadyExistsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidPollPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
