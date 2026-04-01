import 'package:naijapulse/core/utils/backend_time.dart';
import 'package:naijapulse/features/notifications/domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.body,
    required super.isRead,
    required super.createdAt,
    super.actorUserId,
    super.actorName,
    super.articleId,
    super.commentId,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      actorUserId: (json['actor_user_id'] ?? json['actorUserId']) as String?,
      actorName: (json['actor_name'] ?? json['actorName']) as String?,
      articleId: (json['article_id'] ?? json['articleId']) as String?,
      commentId: ((json['comment_id'] ?? json['commentId']) as num?)?.toInt(),
      isRead: (json['is_read'] ?? json['isRead']) as bool? ?? false,
      createdAt: parseBackendDateTime(json['created_at'] ?? json['createdAt']),
    );
  }
}
