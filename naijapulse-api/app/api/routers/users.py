from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_users_service
from app.schemas.users import (
    CreateUserRequest,
    UserAccessRequestCreate,
    UserAccessRequestItem,
    UserAccessRequestsResponse,
    UpdateUserPreferencesRequest,
    UpdateUserRequest,
    User,
    UserPreferences,
)
from app.services.users_service import (
    AccessRequestAlreadyPendingError,
    InvalidUserPayloadError,
    UserAlreadyExistsError,
    UserNotFoundError,
    UsersService,
)

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=User, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: CreateUserRequest,
    users_service: UsersService = Depends(get_users_service),
) -> User:
    """Create a new user account/profile record."""
    try:
        return await users_service.create_user(payload)
    except UserAlreadyExistsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{user_id}", response_model=User)
async def get_user(
    user_id: str,
    users_service: UsersService = Depends(get_users_service),
) -> User:
    """Return one user by id."""
    try:
        return await users_service.get_user(user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/{user_id}", response_model=User)
async def update_user(
    user_id: str,
    payload: UpdateUserRequest,
    users_service: UsersService = Depends(get_users_service),
) -> User:
    """Update selected user fields."""
    try:
        return await users_service.update_user(user_id, payload)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserAlreadyExistsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{user_id}/preferences", response_model=UserPreferences)
async def get_user_preferences(
    user_id: str,
    users_service: UsersService = Depends(get_users_service),
) -> UserPreferences:
    """Return concrete persisted settings for one user."""
    try:
        return await users_service.get_user_preferences(user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/{user_id}/preferences", response_model=UserPreferences)
async def update_user_preferences(
    user_id: str,
    payload: UpdateUserPreferencesRequest,
    users_service: UsersService = Depends(get_users_service),
) -> UserPreferences:
    """Update persisted user settings (alerts/theme/text-size)."""
    try:
        return await users_service.update_user_preferences(user_id, payload)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{user_id}/access-requests", response_model=UserAccessRequestsResponse)
async def get_user_access_requests(
    user_id: str,
    users_service: UsersService = Depends(get_users_service),
) -> UserAccessRequestsResponse:
    try:
        return await users_service.list_user_access_requests(user_id=user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/{user_id}/access-requests",
    response_model=UserAccessRequestItem,
    status_code=status.HTTP_201_CREATED,
)
async def create_user_access_request(
    user_id: str,
    payload: UserAccessRequestCreate,
    users_service: UsersService = Depends(get_users_service),
) -> UserAccessRequestItem:
    try:
        return await users_service.create_user_access_request(
            user_id=user_id,
            payload=payload,
        )
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except AccessRequestAlreadyPendingError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
