import 'package:naijapulse/features/news/domain/entities/article_comment.dart';

class ArticleCommentModel extends ArticleComment {
  const ArticleCommentModel({
    required super.id,
    required super.articleId,
    required super.authorName,
    required super.body,
    required super.status,
    required super.replyCount,
    required super.likeCount,
    required super.reportCount,
    required super.viewerHasLiked,
    required super.viewerHasReported,
    required super.createdAt,
    required super.updatedAt,
    super.parentCommentId,
    super.userId,
    super.moderationReason,
    super.replies,
  });

  factory ArticleCommentModel.fromJson(Map<String, dynamic> json) {
    final repliesRaw = json['replies'];
    return ArticleCommentModel(
      id: (json['id'] as num).toInt(),
      articleId: (json['article_id'] ?? json['articleId'] ?? '').toString(),
      parentCommentId:
          ((json['parent_comment_id'] ?? json['parentCommentId']) as num?)
              ?.toInt(),
      userId: (json['user_id'] ?? json['userId']) as String?,
      authorName: (json['author_name'] ?? json['authorName'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      status: (json['status'] ?? 'visible').toString(),
      replyCount: ((json['reply_count'] ?? json['replyCount']) as num? ?? 0)
          .toInt(),
      likeCount: ((json['like_count'] ?? json['likeCount']) as num? ?? 0)
          .toInt(),
      reportCount: ((json['report_count'] ?? json['reportCount']) as num? ?? 0)
          .toInt(),
      viewerHasLiked:
          (json['viewer_has_liked'] ?? json['viewerHasLiked'] ?? false) == true,
      viewerHasReported:
          (json['viewer_has_reported'] ?? json['viewerHasReported'] ?? false) ==
          true,
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']).toString(),
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['updatedAt']).toString(),
      ),
      moderationReason:
          (json['moderation_reason'] ?? json['moderationReason']) as String?,
      replies: repliesRaw is List
          ? repliesRaw
                .map(
                  (item) => ArticleCommentModel.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList()
          : const <ArticleComment>[],
    );
  }
}
