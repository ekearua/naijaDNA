import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/app_runtime.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/notifications/data/datasource/remote/notifications_remote_datasource.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';
import 'package:naijapulse/features/notifications/domain/entities/app_notification.dart';

class NotificationActionService {
  NotificationActionService({
    required NotificationsRemoteDataSource remoteDataSource,
    required NotificationsInboxController inboxController,
    required AuthSessionController authSessionController,
  }) : _remoteDataSource = remoteDataSource,
       _inboxController = inboxController,
       _authSessionController = authSessionController;

  final NotificationsRemoteDataSource _remoteDataSource;
  final NotificationsInboxController _inboxController;
  final AuthSessionController _authSessionController;

  Future<void> openNotification(AppNotification item) async {
    if (!item.isRead && item.id > 0) {
      try {
        await _remoteDataSource.markRead(item.id);
        _inboxController.markOneReadLocally();
      } catch (_) {}
    }

    final articleId = item.articleId;
    if (articleId == null || articleId.isEmpty) {
      return;
    }

    final router = _activeRouter;
    final session = _authSessionController.session;
    final canOpenAdminArticle =
        (session?.canManageEditorialContent ?? false) &&
        AppRuntime.supportsAdminRoutes;

    if ((item.type == 'comment_reply' || item.type == 'comment_like') &&
        item.commentId != null) {
      await router.push(
        AppRouter.articleDiscussionPath(articleId, commentId: item.commentId),
      );
      return;
    }

    if (item.type == 'article_published') {
      await router.push(
        canOpenAdminArticle
            ? AppRouter.adminArticleDetailPath(articleId)
            : AppRouter.newsDetailPath(articleId),
      );
      return;
    }

    if (item.type.startsWith('article_')) {
      await router.push(
        canOpenAdminArticle
            ? AppRouter.adminArticleDetailPath(articleId)
            : AppRouter.newsSubmitPath,
      );
      return;
    }

    await router.push(AppRouter.newsDetailPath(articleId));
  }

  Future<void> openFromPayload(Map<String, dynamic> payload) async {
    final type = (payload['type'] ?? '').toString().trim();
    final articleId = (payload['article_id'] ?? '').toString().trim();
    if (type.isEmpty || articleId.isEmpty) {
      return;
    }

    final notificationId = int.tryParse(
      (payload['notification_id'] ?? '').toString(),
    );
    final commentId = int.tryParse((payload['comment_id'] ?? '').toString());
    await openNotification(
      AppNotification(
        id: notificationId ?? 0,
        type: type,
        title: (payload['title'] ?? '').toString(),
        body: (payload['body'] ?? '').toString(),
        articleId: articleId,
        commentId: commentId,
        isRead: notificationId == null || notificationId <= 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  GoRouter get _activeRouter => AppRuntime.supportsAdminRoutes
      ? AppRouter.adminRouter
      : AppRouter.clientRouter;
}
