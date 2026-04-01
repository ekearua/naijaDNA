from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field, HttpUrl


StreamStatus = Literal["scheduled", "live", "ended"]
StreamPresenceAction = Literal["join", "heartbeat", "leave"]
StreamCreateMode = Literal["go_live", "schedule"]


class StreamSession(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    category: str
    cover_image_url: Optional[HttpUrl] = None
    stream_url: Optional[HttpUrl] = None
    status: StreamStatus
    host_user_id: Optional[str] = None
    host_name: Optional[str] = None
    viewer_count: int = Field(default=0, ge=0)
    scheduled_for: Optional[datetime] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class StreamSessionsResponse(BaseModel):
    items: List[StreamSession]
    total: int = Field(..., ge=0)


class CreateStreamRequest(BaseModel):
    mode: StreamCreateMode = "go_live"
    title: str = Field(..., min_length=5, max_length=255)
    description: Optional[str] = Field(default=None, max_length=4000)
    category: str = Field(..., min_length=2, max_length=120)
    cover_image_url: Optional[HttpUrl] = None
    stream_url: Optional[HttpUrl] = None
    scheduled_for: Optional[datetime] = None


class StreamPresenceRequest(BaseModel):
    action: StreamPresenceAction
    viewer_id: Optional[str] = Field(default=None, min_length=4, max_length=128)


class StreamPresenceResponse(BaseModel):
    stream: StreamSession
    action: StreamPresenceAction


class LiveKitConnectionRequest(BaseModel):
    viewer_id: Optional[str] = Field(default=None, min_length=4, max_length=128)


class LiveKitConnectionResponse(BaseModel):
    ws_url: str
    token: str
    room_name: str
    participant_identity: str
    participant_name: str
    can_publish: bool = False
    can_subscribe: bool = True


class StreamComment(BaseModel):
    id: int
    stream_id: str
    user_id: Optional[str] = None
    author_name: str
    body: str
    created_at: datetime


class StreamCommentsResponse(BaseModel):
    items: List[StreamComment]
    total: int = Field(..., ge=0)


class CreateStreamCommentRequest(BaseModel):
    body: str = Field(..., min_length=1, max_length=2000)
