from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_users_service
from app.schemas.auth import (
    AdminAccessRequestCreate,
    AdminAccessRequestResponse,
    AuthResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
)
from app.services.users_service import (
    InvalidCredentialsError,
    InvalidUserPayloadError,
    PasswordResetTokenError,
    UserAlreadyExistsError,
    UsersService,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    users_service: UsersService = Depends(get_users_service),
) -> AuthResponse:
    """Register a user with email/password and issue an access token."""
    try:
        return await users_service.register_user(payload)
    except UserAlreadyExistsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/login", response_model=AuthResponse)
async def login(
    payload: LoginRequest,
    users_service: UsersService = Depends(get_users_service),
) -> AuthResponse:
    """Authenticate a user with email/password and issue an access token."""
    try:
        return await users_service.login_user(payload)
    except InvalidCredentialsError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    users_service: UsersService = Depends(get_users_service),
) -> ForgotPasswordResponse:
    try:
        return await users_service.request_password_reset(payload)
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/admin-request-access",
    response_model=AdminAccessRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def admin_request_access(
    payload: AdminAccessRequestCreate,
    users_service: UsersService = Depends(get_users_service),
) -> AdminAccessRequestResponse:
    try:
        return await users_service.create_admin_access_request(payload)
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/reset-password", response_model=ResetPasswordResponse)
async def reset_password(
    payload: ResetPasswordRequest,
    users_service: UsersService = Depends(get_users_service),
) -> ResetPasswordResponse:
    try:
        return await users_service.reset_password(payload)
    except PasswordResetTokenError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except InvalidUserPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
