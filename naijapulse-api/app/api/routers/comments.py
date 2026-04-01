from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import get_article_comments_service
from app.schemas.comments import (
    ArticleComment,
    ArticleCommentsResponse,
    CommentReactionResponse,
    CreateArticleCommentRequest,
    CreateCommentReplyRequest,
    ModerateCommentRequest,
    ReportedCommentsResponse,
    ReportCommentRequest,
)
from app.services.article_comments_service import (
    ArticleCommentNotFoundError,
    ArticleCommentPermissionError,
    ArticleCommentsService,
    CommentModerationError,
    InvalidArticleCommentPayloadError,
    MissingUserContextError,
    NewsArticleNotFoundError,
    UserNotFoundError,
)

router = APIRouter(tags=["comments"])


@router.get("/news/{article_id}/comments", response_model=ArticleCommentsResponse)
async def get_article_comments(
    article_id: str,
    limit: int = Query(default=100, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> ArticleCommentsResponse:
    try:
        items = await comments_service.list_comments(
            article_id=article_id,
            limit=limit,
            viewer_user_id=x_user_id,
        )
        return ArticleCommentsResponse(items=items, total=len(items))
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post(
    "/news/{article_id}/comments",
    response_model=ArticleComment,
    status_code=status.HTTP_201_CREATED,
)
async def create_article_comment(
    article_id: str,
    payload: CreateArticleCommentRequest,
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> ArticleComment:
    try:
        return await comments_service.create_comment(
            article_id=article_id,
            body=payload.body,
            user_id=x_user_id,
        )
    except NewsArticleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ArticleCommentPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidArticleCommentPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post(
    "/comments/{comment_id}/reply",
    response_model=ArticleComment,
    status_code=status.HTTP_201_CREATED,
)
async def reply_to_comment(
    comment_id: int,
    payload: CreateCommentReplyRequest,
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> ArticleComment:
    try:
        reply = await comments_service.reply_to_comment(
            parent_comment_id=comment_id,
            body=payload.body,
            user_id=x_user_id,
        )
        # Return reply wrapped in the same base shape the client already understands.
        return ArticleComment(
            id=reply.id,
            article_id=reply.article_id,
            parent_comment_id=reply.parent_comment_id,
            user_id=reply.user_id,
            author_name=reply.author_name,
            body=reply.body,
            status=reply.status,
            reply_count=reply.reply_count,
            like_count=reply.like_count,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
            replies=[],
        )
    except ArticleCommentNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ArticleCommentPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidArticleCommentPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/comments/{comment_id}/report", status_code=status.HTTP_204_NO_CONTENT)
async def report_comment(
    comment_id: int,
    payload: ReportCommentRequest,
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> None:
    try:
        await comments_service.report_comment(
            comment_id=comment_id,
            user_id=x_user_id,
            reason=payload.reason,
        )
    except ArticleCommentNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post(
    "/comments/{comment_id}/reactions/like",
    response_model=CommentReactionResponse,
)
async def toggle_comment_like(
    comment_id: int,
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> CommentReactionResponse:
    try:
        return await comments_service.toggle_like(
            comment_id=comment_id,
            user_id=x_user_id,
        )
    except ArticleCommentNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ArticleCommentPermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.get("/admin/comments/reported", response_model=ReportedCommentsResponse)
async def get_reported_comments(
    limit: int = Query(default=100, ge=1, le=200),
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> ReportedCommentsResponse:
    try:
        items = await comments_service.list_reported_comments(
            actor_user_id=x_user_id,
            limit=limit,
        )
        return ReportedCommentsResponse(items=items, total=len(items))
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except CommentModerationError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.post("/admin/comments/{comment_id}/{action}", response_model=ArticleComment)
async def moderate_reported_comment(
    comment_id: int,
    action: str,
    payload: ModerateCommentRequest,
    x_user_id: str | None = Header(default=None),
    comments_service: ArticleCommentsService = Depends(get_article_comments_service),
) -> ArticleComment:
    try:
        return await comments_service.moderate_comment(
            actor_user_id=x_user_id,
            comment_id=comment_id,
            action=action,
            notes=payload.notes,
        )
    except ArticleCommentNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except MissingUserContextError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except CommentModerationError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except InvalidArticleCommentPayloadError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
