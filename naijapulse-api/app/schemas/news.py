from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, HttpUrl


ArticleStatus = str
VerificationStatus = str


class NewsArticle(BaseModel):
    id: str
    title: str
    source: str
    category: str
    tags: List[str] = Field(default_factory=list)
    summary: Optional[str] = None
    comment_count: Optional[int] = None
    url: Optional[HttpUrl] = None
    source_domain: Optional[str] = None
    source_type: str = "rss"
    image_url: Optional[HttpUrl] = None
    submitted_by: Optional[str] = None
    created_by_user_id: Optional[str] = None
    reviewed_by_user_id: Optional[str] = None
    published_by_user_id: Optional[str] = None
    is_user_generated: bool = False
    status: str = "published"
    verification_status: str = "unverified"
    is_featured: bool = False
    review_notes: Optional[str] = None
    published_at: datetime
    fact_checked: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class NewsListResponse(BaseModel):
    items: List[NewsArticle]
    total: int = Field(..., ge=0)
    offset: int = Field(default=0, ge=0)
    limit: int = Field(default=0, ge=0)


class HomepageCategoryFeed(BaseModel):
    key: str
    label: str
    color_hex: Optional[str] = None
    position: int = Field(default=0, ge=0)
    items: List[NewsArticle] = Field(default_factory=list)


class HomepageSecondaryChipFeed(BaseModel):
    key: str
    label: str
    chip_type: str
    color_hex: Optional[str] = None
    position: int = Field(default=0, ge=0)
    items: List[NewsArticle] = Field(default_factory=list)


class HomepageContentResponse(BaseModel):
    generated_at: datetime
    top_stories: List[NewsArticle] = Field(default_factory=list)
    latest_stories: List[NewsArticle] = Field(default_factory=list)
    categories: List[HomepageCategoryFeed] = Field(default_factory=list)
    secondary_chips: List[HomepageSecondaryChipFeed] = Field(default_factory=list)


class NewsSourceInfo(BaseModel):
    id: str
    name: str
    type: str
    country: Optional[str] = None
    enabled: bool = True
    requires_api_key: bool = False
    configured: bool = False
    feed_url: Optional[str] = None
    api_base_url: Optional[str] = None
    poll_interval_sec: int = Field(default=900, ge=60)
    last_run_at: Optional[datetime] = None
    notes: Optional[str] = None


class NewsSourcesResponse(BaseModel):
    items: List[NewsSourceInfo]


class CreateNewsArticleRequest(BaseModel):
    title: str = Field(..., min_length=5, max_length=500)
    category: str = Field(..., min_length=2, max_length=120)
    tags: List[str] = Field(default_factory=list)
    summary: Optional[str] = Field(default=None, max_length=5000)
    content_url: Optional[HttpUrl] = None
    image_url: Optional[HttpUrl] = None
    published_at: Optional[datetime] = None


class AdminCreateNewsArticleRequest(BaseModel):
    title: str = Field(..., min_length=5, max_length=500)
    source: str = Field(..., min_length=2, max_length=255)
    category: str = Field(..., min_length=2, max_length=120)
    tags: List[str] = Field(default_factory=list)
    summary: Optional[str] = Field(default=None, max_length=5000)
    source_url: HttpUrl
    image_url: Optional[HttpUrl] = None
    status: str = Field(default="draft", min_length=4, max_length=32)
    verification_status: str = Field(
        default="unverified",
        min_length=4,
        max_length=32,
    )
    is_featured: bool = False
    review_notes: Optional[str] = Field(default=None, max_length=5000)
    published_at: Optional[datetime] = None


class AdminUpdateNewsArticleRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=5, max_length=500)
    source: Optional[str] = Field(default=None, min_length=2, max_length=255)
    category: Optional[str] = Field(default=None, min_length=2, max_length=120)
    tags: Optional[List[str]] = None
    summary: Optional[str] = Field(default=None, max_length=5000)
    source_url: Optional[HttpUrl] = None
    image_url: Optional[HttpUrl] = None
    verification_status: Optional[str] = Field(
        default=None,
        min_length=4,
        max_length=32,
    )
    is_featured: Optional[bool] = None
    review_notes: Optional[str] = Field(default=None, max_length=5000)


class AdminArticleWorkflowRequest(BaseModel):
    notes: Optional[str] = Field(default=None, max_length=5000)
    target_status: Optional[str] = Field(default=None, min_length=4, max_length=32)


class NewsReadableTextResponse(BaseModel):
    article_id: str
    title: str
    source: str
    article_url: Optional[HttpUrl] = None
    text: str
    word_count: int = Field(..., ge=0)
    extraction_method: str
    used_fallback: bool = False
