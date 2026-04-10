import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/admin/presentation/admin_theme.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/logout_user.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  late final AuthSessionController _authSessionController;
  late final NotificationsInboxController _notificationsInboxController;

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _notificationsInboxController =
        InjectionContainer.sl<NotificationsInboxController>();
    _authSessionController.addListener(_handleSessionChanged);
    _notificationsInboxController.addListener(_handleNotificationsChanged);
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleSessionChanged);
    _notificationsInboxController.removeListener(_handleNotificationsChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _redirectIfUnauthorized();
  }

  void _handleNotificationsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _signOut() async {
    await InjectionContainer.sl<LogoutUser>()();
    if (!mounted) {
      return;
    }
    context.go(AppRouter.adminLoginPath);
  }

  void _redirectIfUnauthorized() {
    final session = _authSessionController.session;
    if (session != null &&
        (session.canManageEditorialContent || session.canModerateDiscussions) &&
        _canAccessPath(session, widget.location)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (session == null) {
        context.go(AppRouter.adminLoginPath);
        return;
      }
      if (!session.canManageEditorialContent &&
          !session.canModerateDiscussions) {
        context.go(AppRouter.homePath);
        return;
      }
      if (session.isModerator) {
        context.go(AppRouter.adminModerationPath);
        return;
      }
      context.go(AppRouter.adminDashboardPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _authSessionController.session;
    if (session == null) {
      _redirectIfUnauthorized();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.canManageEditorialContent && !session.canModerateDiscussions) {
      _redirectIfUnauthorized();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccessPath(session, widget.location)) {
      _redirectIfUnauthorized();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    final navigationItems = _navigationItemsFor(session);
    final currentItem =
        navigationItems
            .where((item) => widget.location.startsWith(item.path))
            .cast<_AdminNavItem?>()
            .firstWhere((item) => item != null, orElse: () => null) ??
        navigationItems.first;

    return Theme(
      data: AdminTheme.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F1EA),
        body: SafeArea(
          child: Row(
            children: [
              _AdminSidebar(
                items: navigationItems,
                currentPath: widget.location,
                compact: !isWide,
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 84,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B4F38), Color(0xFF0F6B4B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F6B4B,
                            ).withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'naijaDNA Admin',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentItem.label,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (session.canManageEditorialContent)
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go(AppRouter.adminArticlesPath),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: colorScheme.primary,
                              ),
                              icon: const Icon(Icons.edit_square),
                              label: const Text('Articles'),
                            ),
                          const SizedBox(width: 12),
                          _TopActionIcon(
                            icon: Icons.notifications_none_rounded,
                            badgeCount:
                                _notificationsInboxController.unreadCount,
                            onPressed: () => context.push(AppRouter.alertsPath),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _signOut,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign out'),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: Text(
                                    _avatarText(session),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      session.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            height: 1.1,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      session.role.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            height: 1.0,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AdminNavItem> _navigationItemsFor(AuthSession session) {
    if (session.isModerator) {
      return const <_AdminNavItem>[
        _AdminNavItem(
          label: 'Moderation',
          icon: Icons.forum_outlined,
          path: AppRouter.adminModerationPath,
        ),
      ];
    }
    const items = <_AdminNavItem>[
      _AdminNavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        path: AppRouter.adminDashboardPath,
      ),
      _AdminNavItem(
        label: 'Articles',
        icon: Icons.library_books_outlined,
        path: AppRouter.adminArticlesPath,
      ),
      _AdminNavItem(
        label: 'Moderation',
        icon: Icons.forum_outlined,
        path: AppRouter.adminModerationPath,
      ),
      _AdminNavItem(
        label: 'Verification',
        icon: Icons.verified_outlined,
        path: AppRouter.adminVerificationPath,
      ),
      _AdminNavItem(
        label: 'Homepage',
        icon: Icons.view_quilt_outlined,
        path: AppRouter.adminHomepagePath,
      ),
      _AdminNavItem(
        label: 'Workflow',
        icon: Icons.history_rounded,
        path: AppRouter.adminWorkflowActivityPath,
      ),
      _AdminNavItem(
        label: 'Live Updates',
        icon: Icons.timeline_rounded,
        path: AppRouter.adminLiveUpdatesPath,
      ),
      _AdminNavItem(
        label: 'Polls',
        icon: Icons.poll_outlined,
        path: AppRouter.adminPollsPath,
      ),
      _AdminNavItem(
        label: 'Sources',
        icon: Icons.rss_feed_rounded,
        path: AppRouter.adminSourcesPath,
        adminOnly: true,
      ),
      _AdminNavItem(
        label: 'Users',
        icon: Icons.people_outline_rounded,
        path: AppRouter.adminUsersPath,
        adminOnly: true,
      ),
      _AdminNavItem(
        label: 'Operations',
        icon: Icons.tune_rounded,
        path: AppRouter.adminOperationsPath,
      ),
      _AdminNavItem(
        label: 'Analytics',
        icon: Icons.insights_outlined,
        path: AppRouter.adminAnalyticsPath,
      ),
    ];
    return items
        .where((item) => !item.adminOnly || session.canManageAdminUsers)
        .toList(growable: false);
  }

  bool _canAccessPath(AuthSession session, String path) {
    if (!path.startsWith(AppRouter.adminEntryPath)) {
      return true;
    }
    if (session.isModerator) {
      return path.startsWith(AppRouter.adminModerationPath);
    }
    if (!session.canManageEditorialContent) {
      return false;
    }
    if (path.startsWith(AppRouter.adminSourcesPath) ||
        path.startsWith(AppRouter.adminUsersPath)) {
      return session.canManageSources || session.canManageAdminUsers;
    }
    return true;
  }

  String _avatarText(AuthSession session) {
    final source = session.displayName.trim().isNotEmpty
        ? session.displayName.trim()
        : session.email.trim();
    if (source.isEmpty) {
      return 'A';
    }
    return source.characters.first.toUpperCase();
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.items,
    required this.currentPath,
    required this.compact,
  });

  final List<_AdminNavItem> items;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 92.0 : 248.0;
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFDF8F3),
        border: Border(right: BorderSide(color: Color(0xFFE6DDD1))),
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Text(
              'Editorial Platform',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D1B18),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Workflow, trust, moderation, and operations.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6E675C)),
            ),
            const SizedBox(height: 22),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: items
                    .map((item) {
                      final selected =
                          currentPath == item.path ||
                          currentPath.startsWith('${item.path}/');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => context.go(item.path),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE6F2ED)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: compact
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: selected
                                      ? const Color(0xFF0F6B4B)
                                      : const Color(0xFF6E675C),
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selected
                                                ? const Color(0xFF0F6B4B)
                                                : const Color(0xFF3A362F),
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          compact
              ? Tooltip(
                  message: 'Back to App',
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRouter.homePath),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(40, 40),
                    ),
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => context.go(AppRouter.homePath),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to App'),
                ),
        ],
      ),
    );
  }
}

class _TopActionIcon extends StatelessWidget {
  const _TopActionIcon({
    required this.icon,
    required this.onPressed,
    required this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
          ),
          icon: Icon(icon),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFC53030),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminNavItem {
  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.path,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;
  final String path;
  final bool adminOnly;
}
