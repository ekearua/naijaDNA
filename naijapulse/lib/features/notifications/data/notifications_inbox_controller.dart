import 'package:flutter/foundation.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/notifications/data/datasource/remote/notifications_remote_datasource.dart';

class NotificationsInboxController extends ChangeNotifier {
  NotificationsInboxController({
    required NotificationsRemoteDataSource remoteDataSource,
    required AuthSessionController authSessionController,
  }) : _remoteDataSource = remoteDataSource,
       _authSessionController = authSessionController;

  final NotificationsRemoteDataSource _remoteDataSource;
  final AuthSessionController _authSessionController;

  int _unreadCount = 0;
  bool _initialized = false;
  bool _refreshing = false;

  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _authSessionController.addListener(_handleAuthChanged);
    await refresh();
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final response = await _remoteDataSource.fetchNotifications(limit: 1);
      _setUnreadCount(response.unreadCount);
    } catch (_) {
      if (_authSessionController.session == null) {
        _setUnreadCount(0);
      }
    } finally {
      _refreshing = false;
    }
  }

  void primeUnreadCount(int unreadCount) {
    _setUnreadCount(unreadCount);
  }

  void markOneReadLocally() {
    if (_unreadCount <= 0) {
      return;
    }
    _setUnreadCount(_unreadCount - 1);
  }

  void markAllReadLocally() {
    _setUnreadCount(0);
  }

  void _handleAuthChanged() {
    if (_authSessionController.session == null) {
      _setUnreadCount(0);
      return;
    }
    refresh();
  }

  void _setUnreadCount(int value) {
    final normalized = value < 0 ? 0 : value;
    if (_unreadCount == normalized) {
      return;
    }
    _unreadCount = normalized;
    notifyListeners();
  }
}
