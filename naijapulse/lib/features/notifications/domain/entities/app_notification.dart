import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.actorUserId,
    this.actorName,
    this.articleId,
    this.commentId,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String? actorUserId;
  final String? actorName;
  final String? articleId;
  final int? commentId;
  final bool isRead;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    body,
    actorUserId,
    actorName,
    articleId,
    commentId,
    isRead,
    createdAt,
  ];
}
