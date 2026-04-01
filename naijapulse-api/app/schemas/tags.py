from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class FeedTag(BaseModel):
    id: str
    name: str
    color_hex: Optional[str] = None
    description: Optional[str] = None
    position: int = 0
    is_active: bool = True
    created_at: datetime


class FeedTagsResponse(BaseModel):
    items: List[FeedTag]
    total: int = Field(..., ge=0)


class CreateFeedTagRequest(BaseModel):
    id: Optional[str] = Field(default=None, max_length=80)
    name: str = Field(..., min_length=2, max_length=120)
    color_hex: Optional[str] = Field(default=None, min_length=4, max_length=7)
    description: Optional[str] = Field(default=None, max_length=500)
    position: int = Field(default=0, ge=0, le=9999)
    is_active: bool = True
