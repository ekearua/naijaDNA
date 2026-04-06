from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_notifications_service
from app.schemas.notifications import (
    DeviceTokenDeleteRequest,
    DeviceTokenResponse,
    DeviceTokenUpsertRequest,
    NotificationReadAllResponse,
    NotificationReadResponse,
    NotificationsResponse,
)
from app.services.notifications_service import (
    InvalidNotificationPayloadError,
    MissingUserContextError,
    NotificationNotFoundError,
    NotificationsService,
    UserNotFoundError,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=NotificationsResponse)
async def get_notifications(
    x_user_id: str | None = Header(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    unread_only: bool = Query(default=False),
    notifications_service: NotificationsService = Depends(get_notifications_service),
) -> NotificationsResponse:
    try:
        return await notifications_service.list_notifications(
            user_id=x_user_id,
            limit=limit,
            unread_only=unread_only,
        )
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidNotificationPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/{notification_id}/read", response_model=NotificationReadResponse)
async def mark_notification_read(
    notification_id: int,
    x_user_id: str | None = Header(default=None),
    notifications_service: NotificationsService = Depends(get_notifications_service),
) -> NotificationReadResponse:
    try:
        await notifications_service.mark_read(
            user_id=x_user_id,
            notification_id=notification_id,
        )
        return NotificationReadResponse(notification_id=notification_id)
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidNotificationPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except NotificationNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/read-all", response_model=NotificationReadAllResponse)
async def mark_all_notifications_read(
    x_user_id: str | None = Header(default=None),
    notifications_service: NotificationsService = Depends(get_notifications_service),
) -> NotificationReadAllResponse:
    try:
        marked_count = await notifications_service.mark_all_read(user_id=x_user_id)
        return NotificationReadAllResponse(marked_count=marked_count)
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/devices", response_model=DeviceTokenResponse)
async def register_device_token(
    payload: DeviceTokenUpsertRequest,
    x_user_id: str | None = Header(default=None),
    notifications_service: NotificationsService = Depends(get_notifications_service),
) -> DeviceTokenResponse:
    try:
        await notifications_service.register_device_token(
            user_id=x_user_id,
            token=payload.token,
            platform=payload.platform,
        )
        return DeviceTokenResponse(token=payload.token)
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.delete("/devices", response_model=DeviceTokenResponse)
async def unregister_device_token(
    payload: DeviceTokenDeleteRequest,
    x_user_id: str | None = Header(default=None),
    notifications_service: NotificationsService = Depends(get_notifications_service),
) -> DeviceTokenResponse:
    try:
        await notifications_service.unregister_device_token(
            user_id=x_user_id,
            token=payload.token,
        )
        return DeviceTokenResponse(token=payload.token)
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
