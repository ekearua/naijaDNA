from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_live_updates_service
from app.schemas.live_updates import (
    CreateLiveUpdateEntryRequest,
    CreateLiveUpdatePageRequest,
    LiveUpdatePageDetail,
    LiveUpdatePageListResponse,
    UpdateLiveUpdateEntryRequest,
    UpdateLiveUpdatePageRequest,
)
from app.services.live_updates_service import (
    LiveUpdateNotFoundError,
    LiveUpdateValidationError,
    LiveUpdatesPermissionError,
    LiveUpdatesService,
    MissingLiveUpdatesContextError,
)


router = APIRouter(tags=["live-updates"])


@router.get("/live-updates", response_model=LiveUpdatePageListResponse)
async def list_live_update_pages(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageListResponse:
    try:
        return await live_updates_service.list_public_pages(
            status=status_filter,
            limit=limit,
        )
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/live-updates/{slug}", response_model=LiveUpdatePageDetail)
async def get_live_update_page(
    slug: str,
    after: datetime | None = Query(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.get_public_page(slug=slug, after=after)
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.get("/admin/live-updates/pages", response_model=LiveUpdatePageListResponse)
async def list_admin_live_update_pages(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageListResponse:
    try:
        return await live_updates_service.list_admin_pages(
            actor_user_id=x_user_id,
            status=status_filter,
            limit=limit,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/admin/live-updates/pages",
    response_model=LiveUpdatePageDetail,
    status_code=status.HTTP_201_CREATED,
)
async def create_admin_live_update_page(
    payload: CreateLiveUpdatePageRequest,
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.create_page(
            actor_user_id=x_user_id,
            payload=payload,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/admin/live-updates/pages/{page_id}", response_model=LiveUpdatePageDetail)
async def get_admin_live_update_page(
    page_id: str,
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.get_admin_page(
            actor_user_id=x_user_id,
            page_id=page_id,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.patch("/admin/live-updates/pages/{page_id}", response_model=LiveUpdatePageDetail)
async def update_admin_live_update_page(
    page_id: str,
    payload: UpdateLiveUpdatePageRequest,
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.update_page(
            actor_user_id=x_user_id,
            page_id=page_id,
            payload=payload,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/admin/live-updates/pages/{page_id}/entries",
    response_model=LiveUpdatePageDetail,
    status_code=status.HTTP_201_CREATED,
)
async def create_admin_live_update_entry(
    page_id: str,
    payload: CreateLiveUpdateEntryRequest,
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.create_entry(
            actor_user_id=x_user_id,
            page_id=page_id,
            payload=payload,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/admin/live-updates/entries/{entry_id}", response_model=LiveUpdatePageDetail)
async def update_admin_live_update_entry(
    entry_id: str,
    payload: UpdateLiveUpdateEntryRequest,
    x_user_id: str | None = Header(default=None),
    live_updates_service: LiveUpdatesService = Depends(get_live_updates_service),
) -> LiveUpdatePageDetail:
    try:
        return await live_updates_service.update_entry(
            actor_user_id=x_user_id,
            entry_id=entry_id,
            payload=payload,
        )
    except MissingLiveUpdatesContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except LiveUpdatesPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveUpdateNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except LiveUpdateValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
