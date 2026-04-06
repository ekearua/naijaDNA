import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/shell/widgets/app_bottom_nav_bar.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
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
                  'naijaDNA',
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
              child: AppIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onPressed: _openSearch,
                style: AppIconButtonStyle.glass,
                semanticLabel: 'Search articles',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AppIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: _openNotifications,
                badgeCount: _notificationsInboxController.unreadCount,
                style: AppIconButtonStyle.glass,
                semanticLabel: 'Open notifications',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AppIconButton(
                icon: _authSession == null
                    ? Icons.login_rounded
                    : Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: _authSession != null,
                tooltip: _authSession == null ? 'Log in' : 'Profile',
                onPressed: _loadingSession ? null : _openProfileOrAuth,
                style: AppIconButtonStyle.glass,
                semanticLabel: _authSession == null
                    ? 'Open login'
                    : 'Open profile',
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
