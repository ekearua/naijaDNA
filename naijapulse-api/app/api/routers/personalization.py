from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_personalization_service
from app.schemas.personalization import (
    FeedEventRequest,
    FeedEventResponse,
    FeedFeedbackRequest,
    FeedFeedbackResponse,
    PersonalizedFeedResponse,
    PersonalizationProfileResponse,
    SetInterestsRequest,
)
from app.services.personalization_service import (
    CategoryNotFoundError,
    InvalidEventPayloadError,
    InvalidFeedbackPayloadError,
    MissingUserContextError,
    PersonalizationService,
    UserNotFoundError,
)

router = APIRouter(tags=["personalization"])


@router.get("/preferences/interests", response_model=PersonalizationProfileResponse)
async def get_personalization_profile(
    x_user_id: str | None = Header(default=None),
    personalization_service: PersonalizationService = Depends(get_personalization_service),
) -> PersonalizationProfileResponse:
    """Read explicit interests, learned interest weights, and followed topics."""
    try:
        return await personalization_service.get_profile(user_id=x_user_id or "")
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/preferences/interests", response_model=PersonalizationProfileResponse)
async def set_personalization_interests(
    payload: SetInterestsRequest,
    x_user_id: str | None = Header(default=None),
    personalization_service: PersonalizationService = Depends(get_personalization_service),
) -> PersonalizationProfileResponse:
    """Set explicit category interests and optional topic follows."""
    try:
        return await personalization_service.set_interests(
            user_id=x_user_id or "",
            payload=payload,
        )
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except CategoryNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/feed/events", response_model=FeedEventResponse)
async def record_feed_event(
    payload: FeedEventRequest,
    x_user_id: str | None = Header(default=None),
    personalization_service: PersonalizationService = Depends(get_personalization_service),
) -> FeedEventResponse:
    """Record behavior events (impressions, clicks, saves, dwell, etc)."""
    try:
        return await personalization_service.record_feed_event(
            user_id=x_user_id or "",
            payload=payload,
        )
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidEventPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/feed/feedback", response_model=FeedFeedbackResponse)
async def apply_feed_feedback(
    payload: FeedFeedbackRequest,
    x_user_id: str | None = Header(default=None),
    personalization_service: PersonalizationService = Depends(get_personalization_service),
) -> FeedFeedbackResponse:
    """Apply direct feedback such as more_like_this, hide_source, follow_topic."""
    try:
        return await personalization_service.apply_feedback(
            user_id=x_user_id or "",
            payload=payload,
        )
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except CategoryNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidFeedbackPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/feed/personalized", response_model=PersonalizedFeedResponse)
async def get_personalized_feed(
    limit: int = Query(default=20, ge=1, le=100),
    category: str | None = Query(default=None),
    cursor: datetime | None = Query(default=None),
    x_user_id: str | None = Header(default=None),
    personalization_service: PersonalizationService = Depends(get_personalization_service),
) -> PersonalizedFeedResponse:
    """Return a hybrid-ranked personalized feed for one user."""
    try:
        return await personalization_service.get_personalized_feed(
            user_id=x_user_id or "",
            limit=limit,
            category=category,
            cursor=cursor,
        )
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
