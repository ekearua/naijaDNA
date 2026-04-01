from fastapi import APIRouter, Depends, Header, HTTPException, status

from app.api.deps import get_polls_service, get_response_cache_service
from app.schemas.polls import (
    CreatePollRequest,
    Poll,
    PollsResponse,
    VoteRequest,
    VoteResponse,
)
from app.services.polls_service import (
    CategoryNotFoundError,
    InvalidPollOptionError,
    InvalidPollPayloadError,
    PollNotFoundError,
    PollsService,
    UserNotFoundError,
)
from app.services.response_cache_service import ResponseCacheService

router = APIRouter(prefix="/polls", tags=["polls"])


@router.get("/active", response_model=PollsResponse)
async def get_active_polls(
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> PollsResponse:
    """Return currently active polls for home/polls screens."""
    cached = await response_cache_service.get_json(
        namespace="polls",
        identifier="active",
    )
    if cached is not None:
        return PollsResponse.model_validate(cached)

    items = await polls_service.get_active_polls()
    response = PollsResponse(items=items, total=len(items))
    await response_cache_service.set_json(
        namespace="polls",
        identifier="active",
        value=response.model_dump(mode="json"),
        ttl_seconds=response_cache_service.polls_active_ttl_seconds,
    )
    return response


@router.get("/{poll_id}", response_model=Poll)
async def get_poll(
    poll_id: str,
    polls_service: PollsService = Depends(get_polls_service),
) -> Poll:
    """Return one poll by id."""
    try:
        return await polls_service.get_poll(poll_id)
    except PollNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("", response_model=Poll, status_code=status.HTTP_201_CREATED)
async def create_poll(
    payload: CreatePollRequest,
    x_user_id: str | None = Header(default=None),
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> Poll:
    """Create a new poll from user-submitted content."""
    try:
        poll = await polls_service.create_poll(payload=payload, created_by=x_user_id)
        await response_cache_service.invalidate_namespace("polls")
        return poll
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except CategoryNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidPollPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/{poll_id}/vote", response_model=VoteResponse)
async def vote_poll(
    poll_id: str,
    payload: VoteRequest,
    x_device_id: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None),
    polls_service: PollsService = Depends(get_polls_service),
    response_cache_service: ResponseCacheService = Depends(get_response_cache_service),
) -> VoteResponse:
    """Submit one vote for a poll option."""
    try:
        poll, outcome = await polls_service.vote(
            poll_id=poll_id,
            option_id=payload.option_id,
            idempotency_key=payload.idempotency_key,
            voter_id=x_device_id,
            user_id=x_user_id,
        )
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PollNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidPollOptionError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    await response_cache_service.invalidate_namespace("polls")
    return VoteResponse(poll=poll, outcome=outcome)
