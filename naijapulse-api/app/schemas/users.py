from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, HttpUrl


class UserEntitlements(BaseModel):
    can_access_streams: bool = False
    can_host_streams: bool = False
    can_contribute_stories: bool = False


class UserAccessRequestCreate(BaseModel):
    access_type: Literal["stream_access", "stream_hosting", "contribution_access"]
    reason: str = Field(min_length=8, max_length=2000)


class UserAccessRequestItem(BaseModel):
    id: str
    user_id: str
    access_type: Literal["stream_access", "stream_hosting", "contribution_access"]
    status: Literal["pending", "approved", "rejected"] = "pending"
    reason: str
    review_note: Optional[str] = None
    reviewed_by_user_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class UserAccessRequestsResponse(BaseModel):
    items: list[UserAccessRequestItem] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)


class User(BaseModel):
    id: str
    email: Optional[str] = Field(default=None, max_length=255)
    display_name: Optional[str] = None
    avatar_url: Optional[HttpUrl] = None
    is_active: bool
    role: Literal["user", "contributor", "moderator", "editor", "admin"] = "user"
    stream_access_granted: bool = False
    stream_hosting_granted: bool = False
    contribution_access_granted: bool = False
    entitlements: UserEntitlements = Field(default_factory=UserEntitlements)
    created_at: datetime
    updated_at: datetime


class CreateUserRequest(BaseModel):
    id: Optional[str] = Field(default=None, min_length=1, max_length=128)
    email: Optional[str] = Field(default=None, min_length=3, max_length=255)
    display_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    avatar_url: Optional[HttpUrl] = None
    stream_access_granted: bool = False
    stream_hosting_granted: bool = False
    contribution_access_granted: bool = False


class UpdateUserRequest(BaseModel):
    email: Optional[str] = Field(default=None, min_length=3, max_length=255)
    display_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    avatar_url: Optional[HttpUrl] = None
    is_active: Optional[bool] = None
    stream_access_granted: Optional[bool] = None
    stream_hosting_granted: Optional[bool] = None
    contribution_access_granted: Optional[bool] = None


class UserPreferences(BaseModel):
    user_id: str
    breaking_news_alerts: bool
    live_stream_alerts: bool
    comment_replies: bool
    theme: Literal["system", "light", "dark"] = "system"
    text_size: Literal["small", "normal", "large"] = "small"
    created_at: datetime
    updated_at: datetime


class UpdateUserPreferencesRequest(BaseModel):
    breaking_news_alerts: Optional[bool] = None
    live_stream_alerts: Optional[bool] = None
    comment_replies: Optional[bool] = None
    theme: Optional[Literal["system", "light", "dark"]] = None
    text_size: Optional[Literal["small", "normal", "large"]] = None
