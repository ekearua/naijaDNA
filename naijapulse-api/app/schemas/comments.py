from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


CommentStatus = str


class ArticleCommentReply(BaseModel):
    id: int
    article_id: str
    parent_comment_id: int
    user_id: Optional[str] = None
    author_name: str
    body: str
    status: CommentStatus = "visible"
    reply_count: int = Field(default=0, ge=0)
    like_count: int = Field(default=0, ge=0)
    report_count: int = Field(default=0, ge=0)
    viewer_has_liked: bool = False
    viewer_has_reported: bool = False
    created_at: datetime
    updated_at: datetime


class ArticleComment(BaseModel):
    id: int
    article_id: str
    parent_comment_id: Optional[int] = None
    user_id: Optional[str] = None
    author_name: str
    body: str
    status: CommentStatus = "visible"
    reply_count: int = Field(default=0, ge=0)
    like_count: int = Field(default=0, ge=0)
    report_count: int = Field(default=0, ge=0)
    viewer_has_liked: bool = False
    viewer_has_reported: bool = False
    moderation_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    replies: List[ArticleCommentReply] = Field(default_factory=list)


class ArticleCommentsResponse(BaseModel):
    items: List[ArticleComment]
    total: int = Field(..., ge=0)


class CreateArticleCommentRequest(BaseModel):
    body: str = Field(..., min_length=1, max_length=2000)


class CreateCommentReplyRequest(BaseModel):
    body: str = Field(..., min_length=1, max_length=2000)


class ReportCommentRequest(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=1000)


class CommentReactionResponse(BaseModel):
    comment_id: int
    reaction_type: str = "like"
    liked: bool
    like_count: int = Field(..., ge=0)


class ReportedCommentItem(BaseModel):
    id: int
    article_id: str
    article_title: str
    author_name: str
    body: str
    status: CommentStatus
    report_count: int = Field(default=0, ge=0)
    like_count: int = Field(default=0, ge=0)
    reply_count: int = Field(default=0, ge=0)
    moderation_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class ReportedCommentsResponse(BaseModel):
    items: List[ReportedCommentItem]
    total: int = Field(..., ge=0)


class ModerateCommentRequest(BaseModel):
    notes: Optional[str] = Field(default=None, max_length=1000)
