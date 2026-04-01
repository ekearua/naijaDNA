import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/shell/widgets/app_bottom_nav_bar.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.currentIndex,
    required super.child,
    super.key,
  });

  final int currentIndex;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}

class _AppShellPageState extends State<AppShellPage> {
  AuthSession? _authSession;
  bool _loadingSession = true;
  late final AuthSessionController _authSessionController;
  late final NotificationsInboxController _notificationsInboxController;

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _notificationsInboxController =
        InjectionContainer.sl<NotificationsInboxController>();
    _authSessionController.addListener(_handleAuthChanged);
    _notificationsInboxController.addListener(_handleNotificationStateChanged);
    _loadSession();
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    _notificationsInboxController.removeListener(
      _handleNotificationStateChanged,
    );
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = _authSessionController.session;
      _loadingSession = false;
    });
  }

  void _handleNotificationStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadSession() async {
    AuthSession? session;
    try {
      session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      session = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = session ?? _authSessionController.session;
      _loadingSession = false;
    });
  }

  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _openProfileOrAuth() async {
    if (_authSession == null) {
      await context.push(AppRouter.loginPath);
      await _loadSession();
      return;
    }
    _onTabSelected(4);
  }

  Future<void> _openNotifications() async {
    await context.push(AppRouter.alertsPath);
    await _notificationsInboxController.refresh();
  }

  Future<void> _openSearch() async {
    await context.push(AppRouter.searchPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerForeground = isDark ? Colors.white : AppTheme.textPrimary;
    final systemOverlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );
    final headerSurface = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.88);
    final headerBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.textPrimary.withValues(alpha: 0.08);

    return AppShellScope(
      currentIndex: widget.navigationShell.currentIndex,
      child: Scaffold(
        extendBody: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          systemOverlayStyle: systemOverlayStyle,
          titleSpacing: 12,
          toolbarHeight: 64,
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.editorialGradient(theme.brightness),
            ),
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: headerSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: headerBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.newspaper_rounded,
                  color: headerForeground,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'NaijaPulse',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: headerForeground,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _HeaderActionButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onPressed: _openSearch,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _HeaderActionButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: _openNotifications,
                badgeCount: _notificationsInboxController.unreadCount,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _HeaderActionButton(
                icon: _authSession == null
                    ? Icons.login_rounded
                    : Icons.person_outline_rounded,
                tooltip: _authSession == null ? 'Log in' : 'Profile',
                onPressed: _loadingSession ? null : _openProfileOrAuth,
                isDark: isDark,
              ),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.scaffoldBackgroundColor,
                theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.08 : 0.3,
                ),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: widget.navigationShell,
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTabSelected,
          profileUnreadCount: _notificationsInboxController.unreadCount,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDark;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isDark ? Colors.white : AppTheme.textPrimary;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.textPrimary.withValues(alpha: 0.08);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: IconButton(
            onPressed: onPressed,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            icon: Icon(icon, color: foregroundColor),
            tooltip: tooltip,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
