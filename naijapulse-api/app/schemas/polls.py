from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class PollOption(BaseModel):
    id: str
    label: str
    votes: int = Field(..., ge=0)


class Poll(BaseModel):
    id: str
    question: str
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    options: List[PollOption]
    ends_at: datetime
    has_voted: bool = False
    selected_option_id: Optional[str] = None


class PollsResponse(BaseModel):
    items: List[Poll]
    total: int = Field(..., ge=0)


class VoteRequest(BaseModel):
    option_id: str
    idempotency_key: Optional[str] = None


class VoteResponse(BaseModel):
    poll: Poll
    outcome: Literal["applied", "idempotent", "already_voted", "closed"]


class CreatePollOptionRequest(BaseModel):
    id: str = Field(..., min_length=1, max_length=80)
    label: str = Field(..., min_length=1, max_length=255)


class CreatePollRequest(BaseModel):
    question: str = Field(..., min_length=8, max_length=500)
    ends_at: datetime
    category_id: Optional[str] = Field(default=None, max_length=80)
    options: List[CreatePollOptionRequest] = Field(..., min_length=2, max_length=8)
