import 'package:equatable/equatable.dart';

class ReportedComment extends Equatable {
  const ReportedComment({
    required this.id,
    required this.articleId,
    required this.articleTitle,
    required this.authorName,
    required this.body,
    required this.status,
    required this.reportCount,
    required this.likeCount,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
    this.moderationReason,
  });

  final int id;
  final String articleId;
  final String articleTitle;
  final String authorName;
  final String body;
  final String status;
  final int reportCount;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? moderationReason;

  bool get isRemoved => status == 'removed';

  @override
  List<Object?> get props => [
    id,
    articleId,
    articleTitle,
    authorName,
    body,
    status,
    reportCount,
    likeCount,
    replyCount,
    createdAt,
    updatedAt,
    moderationReason,
  ];
}
