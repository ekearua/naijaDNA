import 'package:naijapulse/features/news/domain/entities/reported_comment.dart';

class ReportedCommentModel extends ReportedComment {
  const ReportedCommentModel({
    required super.id,
    required super.articleId,
    required super.articleTitle,
    required super.authorName,
    required super.body,
    required super.status,
    required super.reportCount,
    required super.likeCount,
    required super.replyCount,
    required super.createdAt,
    required super.updatedAt,
    super.moderationReason,
  });

  factory ReportedCommentModel.fromJson(Map<String, dynamic> json) {
    return ReportedCommentModel(
      id: (json['id'] as num).toInt(),
      articleId: (json['article_id'] ?? json['articleId'] ?? '').toString(),
      articleTitle: (json['article_title'] ?? json['articleTitle'] ?? '')
          .toString(),
      authorName: (json['author_name'] ?? json['authorName'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      status: (json['status'] ?? 'flagged').toString(),
      reportCount: ((json['report_count'] ?? json['reportCount']) as num? ?? 0)
          .toInt(),
      likeCount: ((json['like_count'] ?? json['likeCount']) as num? ?? 0)
          .toInt(),
      replyCount: ((json['reply_count'] ?? json['replyCount']) as num? ?? 0)
          .toInt(),
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']).toString(),
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['updatedAt']).toString(),
      ),
      moderationReason:
          (json['moderation_reason'] ?? json['moderationReason']) as String?,
    );
  }
}
