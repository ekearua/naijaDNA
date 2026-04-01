from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


NotificationType = str


class NotificationItem(BaseModel):
    id: int
    type: NotificationType
    title: str
    body: str
    actor_user_id: Optional[str] = None
    actor_name: Optional[str] = None
    article_id: Optional[str] = None
    comment_id: Optional[int] = None
    is_read: bool = False
    created_at: datetime


class NotificationsResponse(BaseModel):
    items: List[NotificationItem]
    total: int = Field(..., ge=0)
    unread_count: int = Field(..., ge=0)


class NotificationReadResponse(BaseModel):
    status: str = "ok"
    notification_id: int


class NotificationReadAllResponse(BaseModel):
    status: str = "ok"
    marked_count: int = Field(..., ge=0)
