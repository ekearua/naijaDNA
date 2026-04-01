from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_livekit_service, get_streams_service
from app.schemas.streams import (
    CreateStreamRequest,
    CreateStreamCommentRequest,
    LiveKitConnectionRequest,
    LiveKitConnectionResponse,
    StreamComment,
    StreamCommentsResponse,
    StreamPresenceRequest,
    StreamPresenceResponse,
    StreamSession,
    StreamSessionsResponse,
)
from app.services.livekit_service import (
    LiveKitConfigurationError,
    LiveKitIdentityError,
    LiveKitService,
    LiveKitStateError,
)
from app.services.streams_service import (
    InvalidStreamPayloadError,
    StreamCommentPermissionError,
    StreamNotFoundError,
    StreamPermissionError,
    StreamStateError,
    StreamViewerIdentityError,
    StreamsService,
    UserNotFoundError,
)

router = APIRouter(prefix="/streams", tags=["streams"])


@router.get("/live", response_model=StreamSessionsResponse)
async def get_live_streams(
    limit: int = Query(default=20, ge=1, le=50),
    category: str | None = Query(default=None),
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSessionsResponse:
    try:
        items = await streams_service.list_live_streams(
            category=category,
            limit=limit,
            user_id=x_user_id,
        )
        return StreamSessionsResponse(items=items, total=len(items))
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/scheduled", response_model=StreamSessionsResponse)
async def get_scheduled_streams(
    limit: int = Query(default=20, ge=1, le=50),
    category: str | None = Query(default=None),
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSessionsResponse:
    try:
        items = await streams_service.list_scheduled_streams(
            category=category,
            limit=limit,
            user_id=x_user_id,
        )
        return StreamSessionsResponse(items=items, total=len(items))
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/{stream_id}", response_model=StreamSession)
async def get_stream(
    stream_id: str,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSession:
    try:
        return await streams_service.get_stream(stream_id, user_id=x_user_id)
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/{stream_id}/comments", response_model=StreamCommentsResponse)
async def get_stream_comments(
    stream_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamCommentsResponse:
    try:
        items = await streams_service.list_comments(
            stream_id=stream_id,
            limit=limit,
            user_id=x_user_id,
        )
        return StreamCommentsResponse(items=items, total=len(items))
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.post(
    "/{stream_id}/comments",
    response_model=StreamComment,
    status_code=status.HTTP_201_CREATED,
)
async def create_stream_comment(
    stream_id: str,
    payload: CreateStreamCommentRequest,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamComment:
    try:
        return await streams_service.create_comment(
            stream_id=stream_id,
            body=payload.body,
            user_id=x_user_id,
        )
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamCommentPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except InvalidStreamPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except StreamStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("", response_model=StreamSession, status_code=status.HTTP_201_CREATED)
async def create_stream(
    payload: CreateStreamRequest,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSession:
    try:
        return await streams_service.create_stream(
            payload=payload,
            host_user_id=x_user_id,
        )
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidStreamPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.post("/{stream_id}/start", response_model=StreamSession)
async def start_stream(
    stream_id: str,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSession:
    try:
        return await streams_service.start_stream(
            stream_id=stream_id,
            host_user_id=x_user_id,
        )
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except StreamStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{stream_id}/end", response_model=StreamSession)
async def end_stream(
    stream_id: str,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamSession:
    try:
        return await streams_service.end_stream(
            stream_id=stream_id,
            host_user_id=x_user_id,
        )
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except StreamStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{stream_id}/presence", response_model=StreamPresenceResponse)
async def update_stream_presence(
    stream_id: str,
    payload: StreamPresenceRequest,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
) -> StreamPresenceResponse:
    try:
        stream = await streams_service.update_presence(
            stream_id=stream_id,
            action=payload.action,
            viewer_id=payload.viewer_id,
            user_id=x_user_id,
        )
        return StreamPresenceResponse(stream=stream, action=payload.action)
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamViewerIdentityError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except StreamStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{stream_id}/livekit-connection", response_model=LiveKitConnectionResponse)
async def create_livekit_connection(
    stream_id: str,
    payload: LiveKitConnectionRequest,
    x_user_id: str | None = Header(default=None),
    streams_service: StreamsService = Depends(get_streams_service),
    livekit_service: LiveKitService = Depends(get_livekit_service),
) -> LiveKitConnectionResponse:
    try:
        stream = await streams_service.get_stream(stream_id, user_id=x_user_id)
        connection = livekit_service.build_connection(
            stream=stream,
            user_id=x_user_id,
            viewer_id=payload.viewer_id,
        )
        return LiveKitConnectionResponse(**connection)
    except StreamNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StreamPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LiveKitConfigurationError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
    except LiveKitIdentityError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except LiveKitStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
