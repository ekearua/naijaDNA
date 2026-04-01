from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

from app.schemas.news import NewsArticle


FeedEventType = Literal[
    "impression",
    "click",
    "dwell",
    "save",
    "share",
    "discuss",
    "hide",
    "report",
]

FeedFeedbackAction = Literal[
    "more_like_this",
    "less_like_this",
    "hide_article",
    "hide_source",
    "hide_category",
    "follow_topic",
    "unfollow_topic",
]


class InterestSelection(BaseModel):
    category_id: str = Field(..., min_length=1, max_length=80)
    weight: float = Field(default=0.8, ge=0.0, le=1.0)


class SetInterestsRequest(BaseModel):
    interests: List[InterestSelection] = Field(default_factory=list)
    topics: Optional[List[str]] = None
    replace_existing: bool = True


class PersonalizedInterest(BaseModel):
    category_id: str
    category_name: str
    color_hex: Optional[str] = None
    explicit_weight: float
    implicit_weight: float
    updated_at: datetime


class FollowedTopic(BaseModel):
    topic: str
    created_at: datetime


class PersonalizationProfileResponse(BaseModel):
    user_id: str
    interests: List[PersonalizedInterest]
    topics: List[FollowedTopic]


class FeedEventRequest(BaseModel):
    article_id: Optional[str] = Field(default=None, min_length=1, max_length=96)
    event_type: FeedEventType
    dwell_ms: Optional[int] = Field(default=None, ge=0)
    idempotency_key: Optional[str] = Field(default=None, min_length=1, max_length=160)


class FeedEventResponse(BaseModel):
    status: Literal["recorded", "idempotent"]
    event_type: FeedEventType
    updated_interest: Optional[PersonalizedInterest] = None


class FeedFeedbackRequest(BaseModel):
    action: FeedFeedbackAction
    article_id: Optional[str] = Field(default=None, min_length=1, max_length=96)
    source: Optional[str] = Field(default=None, min_length=1, max_length=255)
    category_id: Optional[str] = Field(default=None, min_length=1, max_length=80)
    topic: Optional[str] = Field(default=None, min_length=1, max_length=120)


class FeedFeedbackResponse(BaseModel):
    status: Literal["applied"]
    action: FeedFeedbackAction


class PersonalizedFeedResponse(BaseModel):
    items: List[NewsArticle]
    total: int = Field(..., ge=0)
    strategy: str = "hybrid_v1"
