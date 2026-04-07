from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

from app.schemas.news import NewsArticle
from app.schemas.polls import Poll


LiveUpdatePageStatus = Literal["draft", "live", "ended", "archived"]
LiveUpdateBlockType = Literal[
    "text",
    "image",
    "article_embed",
    "poll_embed",
    "milestone",
]


class LiveUpdateAuthor(BaseModel):
    id: Optional[str] = None
    display_name: str


class LiveUpdateEntry(BaseModel):
    id: str
    page_id: str
    block_type: LiveUpdateBlockType
    headline: Optional[str] = None
    body: Optional[str] = None
    image_url: Optional[str] = None
    image_caption: Optional[str] = None
    linked_article: Optional[NewsArticle] = None
    linked_poll: Optional[Poll] = None
    published_at: datetime
    is_pinned: bool = False
    is_visible: bool = True
    author: Optional[LiveUpdateAuthor] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class LiveUpdatePageSummary(BaseModel):
    id: str
    slug: str
    title: str
    summary: str
    hero_kicker: Optional[str] = None
    category: str
    cover_image_url: Optional[str] = None
    status: LiveUpdatePageStatus
    is_featured: bool = False
    is_breaking: bool = False
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    last_published_entry_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    entry_count: int = Field(default=0, ge=0)


class LiveUpdatePageDetail(BaseModel):
    page: LiveUpdatePageSummary
    entries: List[LiveUpdateEntry] = Field(default_factory=list)


class LiveUpdatePageListResponse(BaseModel):
    items: List[LiveUpdatePageSummary] = Field(default_factory=list)
    total: int = Field(default=0, ge=0)


class CreateLiveUpdatePageRequest(BaseModel):
    title: str = Field(..., min_length=4, max_length=255)
    summary: str = Field(..., min_length=8, max_length=5000)
    slug: Optional[str] = Field(default=None, min_length=4, max_length=160)
    hero_kicker: Optional[str] = Field(default=None, max_length=120)
    category: str = Field(..., min_length=2, max_length=120)
    cover_image_url: Optional[str] = Field(default=None, max_length=4096)
    status: LiveUpdatePageStatus = "draft"
    is_featured: bool = False
    is_breaking: bool = False
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None


class UpdateLiveUpdatePageRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=4, max_length=255)
    summary: Optional[str] = Field(default=None, min_length=8, max_length=5000)
    slug: Optional[str] = Field(default=None, min_length=4, max_length=160)
    hero_kicker: Optional[str] = Field(default=None, max_length=120)
    category: Optional[str] = Field(default=None, min_length=2, max_length=120)
    cover_image_url: Optional[str] = Field(default=None, max_length=4096)
    status: Optional[LiveUpdatePageStatus] = None
    is_featured: Optional[bool] = None
    is_breaking: Optional[bool] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None


class CreateLiveUpdateEntryRequest(BaseModel):
    block_type: LiveUpdateBlockType
    headline: Optional[str] = Field(default=None, max_length=255)
    body: Optional[str] = Field(default=None, max_length=12000)
    image_url: Optional[str] = Field(default=None, max_length=4096)
    image_caption: Optional[str] = Field(default=None, max_length=4000)
    linked_article_id: Optional[str] = Field(default=None, max_length=96)
    linked_poll_id: Optional[str] = Field(default=None, max_length=80)
    published_at: Optional[datetime] = None
    is_pinned: bool = False
    is_visible: bool = True


class UpdateLiveUpdateEntryRequest(BaseModel):
    headline: Optional[str] = Field(default=None, max_length=255)
    body: Optional[str] = Field(default=None, max_length=12000)
    image_url: Optional[str] = Field(default=None, max_length=4096)
    image_caption: Optional[str] = Field(default=None, max_length=4000)
    linked_article_id: Optional[str] = Field(default=None, max_length=96)
    linked_poll_id: Optional[str] = Field(default=None, max_length=80)
    published_at: Optional[datetime] = None
    is_pinned: Optional[bool] = None
    is_visible: Optional[bool] = None
