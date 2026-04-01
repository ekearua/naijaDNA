from pydantic import BaseModel, Field

from app.schemas.users import User


class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, min_length=1, max_length=120)


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=128)


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    reset_path: str | None = Field(default=None, min_length=1, max_length=512)


class AdminAccessRequestCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    work_email: str = Field(min_length=3, max_length=255)
    requested_role: str = Field(min_length=2, max_length=120)
    bureau: str | None = Field(default=None, min_length=1, max_length=120)
    reason: str = Field(min_length=8, max_length=2000)


class AdminAccessRequestResponse(BaseModel):
    message: str
    request_id: str
    status: str


class ForgotPasswordResponse(BaseModel):
    message: str
    expires_in_seconds: int
    reset_token: str | None = None
    reset_url: str | None = None


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=16, max_length=4096)
    password: str = Field(min_length=8, max_length=128)


class ResetPasswordResponse(BaseModel):
    message: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int
    user: User
