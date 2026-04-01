import 'package:equatable/equatable.dart';

class ArticleComment extends Equatable {
  const ArticleComment({
    required this.id,
    required this.articleId,
    required this.authorName,
    required this.body,
    required this.status,
    required this.replyCount,
    required this.likeCount,
    required this.reportCount,
    required this.viewerHasLiked,
    required this.viewerHasReported,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    this.userId,
    this.moderationReason,
    this.replies = const <ArticleComment>[],
  });

  final int id;
  final String articleId;
  final int? parentCommentId;
  final String? userId;
  final String authorName;
  final String body;
  final String status;
  final int replyCount;
  final int likeCount;
  final int reportCount;
  final bool viewerHasLiked;
  final bool viewerHasReported;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? moderationReason;
  final List<ArticleComment> replies;

  bool get isRemoved => status == 'removed';
  bool get isFlagged => status == 'flagged';

  ArticleComment copyWith({
    int? likeCount,
    int? reportCount,
    bool? viewerHasLiked,
    bool? viewerHasReported,
    String? status,
    String? body,
    List<ArticleComment>? replies,
    String? moderationReason,
  }) {
    return ArticleComment(
      id: id,
      articleId: articleId,
      parentCommentId: parentCommentId,
      userId: userId,
      authorName: authorName,
      body: body ?? this.body,
      status: status ?? this.status,
      replyCount: replyCount,
      likeCount: likeCount ?? this.likeCount,
      reportCount: reportCount ?? this.reportCount,
      viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
      viewerHasReported: viewerHasReported ?? this.viewerHasReported,
      createdAt: createdAt,
      updatedAt: updatedAt,
      moderationReason: moderationReason ?? this.moderationReason,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
    id,
    articleId,
    parentCommentId,
    userId,
    authorName,
    body,
    status,
    replyCount,
    likeCount,
    reportCount,
    viewerHasLiked,
    viewerHasReported,
    createdAt,
    updatedAt,
    moderationReason,
    replies,
  ];
}
