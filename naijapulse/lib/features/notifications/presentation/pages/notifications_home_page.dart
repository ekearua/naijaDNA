import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/notifications/data/notification_action_service.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';
import 'package:naijapulse/features/notifications/data/datasource/remote/notifications_remote_datasource.dart';
import 'package:naijapulse/features/notifications/domain/entities/app_notification.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class NotificationsHomePage extends StatefulWidget {
  const NotificationsHomePage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  State<NotificationsHomePage> createState() => _NotificationsHomePageState();
}

class _NotificationsHomePageState extends State<NotificationsHomePage> {
  final NotificationsRemoteDataSource _remote =
      InjectionContainer.sl<NotificationsRemoteDataSource>();
  final NotificationsInboxController _inboxController =
      InjectionContainer.sl<NotificationsInboxController>();
  final NotificationActionService _notificationActionService =
      InjectionContainer.sl<NotificationActionService>();

  AuthSession? _session;
  List<AppNotification> _notifications = const <AppNotification>[];
  int _unreadCount = 0;
  bool _loading = true;
  bool _markingAllRead = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadSession();
    if (_session == null) {
      setState(() => _loading = false);
      return;
    }
    await _loadNotifications();
  }

  Future<void> _loadSession() async {
    try {
      _session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      _session = null;
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final response = await _remote.fetchNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = response.items;
        _unreadCount = response.unreadCount;
      });
      _inboxController.primeUnreadCount(response.unreadCount);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openLogin() async {
    await context.push(AppRouter.loginPath);
    await _bootstrap();
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || _notifications.isEmpty) {
      return;
    }
    setState(() => _markingAllRead = true);
    try {
      await _remote.markAllRead();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = _notifications
            .map(
              (item) => AppNotification(
                id: item.id,
                type: item.type,
                title: item.title,
                body: item.body,
                actorUserId: item.actorUserId,
                actorName: item.actorName,
                articleId: item.articleId,
                commentId: item.commentId,
                isRead: true,
                createdAt: item.createdAt,
              ),
            )
            .toList();
        _unreadCount = 0;
      });
      _inboxController.markAllReadLocally();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    await _notificationActionService.openNotification(item);
    if (!mounted || item.isRead) {
      return;
    }
    setState(() {
      _notifications = _notifications
          .map(
            (entry) => entry.id == item.id
                ? AppNotification(
                    id: entry.id,
                    type: entry.type,
                    title: entry.title,
                    body: entry.body,
                    actorUserId: entry.actorUserId,
                    actorName: entry.actorName,
                    articleId: entry.articleId,
                    commentId: entry.commentId,
                    isRead: true,
                    createdAt: entry.createdAt,
                  )
                : entry,
          )
          .toList();
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                Icons.notifications_outlined,
                size: AppIconSize.large,
                tone: AppIconTone.accent,
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to see your notifications.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _openLogin,
                child: const Text('Log in or Sign up'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadNotifications,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No notifications yet. Replies and editorial updates will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notification Center',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Unread: $_unreadCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppActionChip(
              icon: Icons.done_all_rounded,
              label: _markingAllRead
                  ? 'Marking...'
                  : _unreadCount > 0
                  ? 'Mark all read'
                  : 'All caught up',
              compact: true,
              selected: _unreadCount == 0,
              onTap: _markingAllRead ? null : _markAllRead,
            ),
          ),
          const SizedBox(height: 8),
          ..._notifications.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    _iconFor(item.type),
                    size: AppIconSize.small,
                    color: item.isRead
                        ? Theme.of(context).colorScheme.outline
                        : AppTheme.primary,
                  ),
                ),
                title: Text(
                  item.title,
                  style: item.isRead
                      ? null
                      : const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${item.body}\n${relativeTimeLabel(item.createdAt)}',
                ),
                trailing: item.isRead
                    ? const AppIcon(
                        Icons.chevron_right_rounded,
                        size: AppIconSize.small,
                        tone: AppIconTone.muted,
                      )
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                isThreeLine: true,
                onTap: () => _openNotification(item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'comment_reply':
        return Icons.reply_rounded;
      case 'comment_like':
        return Icons.thumb_up_alt_rounded;
      case 'article_approved':
        return Icons.verified_rounded;
      case 'article_published':
        return Icons.campaign_rounded;
      case 'article_rejected':
        return Icons.report_gmailerrorred_rounded;
      case 'article_archived':
        return Icons.archive_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
