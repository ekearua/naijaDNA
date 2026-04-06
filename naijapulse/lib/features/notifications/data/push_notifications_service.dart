import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/notifications/data/datasource/remote/notifications_remote_datasource.dart';
import 'package:naijapulse/features/notifications/data/notification_action_service.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lastPushTokenKey = 'push.last_token';
const _lastPushUserIdKey = 'push.last_user_id';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationsService {
  PushNotificationsService({
    required FirebaseMessaging messaging,
    required NotificationsRemoteDataSource remoteDataSource,
    required NotificationsInboxController notificationsInboxController,
    required NotificationActionService notificationActionService,
    required AuthSessionController authSessionController,
    required SharedPreferences sharedPreferences,
  }) : _messaging = messaging,
       _remoteDataSource = remoteDataSource,
       _notificationsInboxController = notificationsInboxController,
       _notificationActionService = notificationActionService,
       _authSessionController = authSessionController,
       _sharedPreferences = sharedPreferences;

  final FirebaseMessaging _messaging;
  final NotificationsRemoteDataSource _remoteDataSource;
  final NotificationsInboxController _notificationsInboxController;
  final NotificationActionService _notificationActionService;
  final AuthSessionController _authSessionController;
  final SharedPreferences _sharedPreferences;

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_supportsFcmOnCurrentPlatform) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _authSessionController.addListener(_handleAuthSessionChanged);
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _onMessageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _onTokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
    );

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _deferPayloadOpen(initialMessage.data);
    }
    await _syncCurrentToken();
  }

  Future<void> dispose() async {
    _authSessionController.removeListener(_handleAuthSessionChanged);
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
    await _onTokenRefreshSubscription?.cancel();
  }

  bool get _supportsFcmOnCurrentPlatform {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _notificationsInboxController.refresh();
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await _notificationsInboxController.refresh();
    _deferPayloadOpen(message.data);
  }

  Future<void> _handleTokenRefresh(String token) async {
    await _registerToken(token);
  }

  Future<void> _handleAuthSessionChanged() async {
    final currentUserId = _authSessionController.session?.userId.trim();
    if (currentUserId == null || currentUserId.isEmpty) {
      await _unregisterCachedToken();
      return;
    }
    await _syncCurrentToken();
  }

  Future<void> _syncCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final userId = _authSessionController.session?.userId.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final previousToken = _sharedPreferences.getString(_lastPushTokenKey);
    final previousUserId = _sharedPreferences.getString(_lastPushUserIdKey);
    final normalizedToken = token.trim();

    if (previousToken != null &&
        previousUserId != null &&
        previousUserId == userId &&
        previousToken != normalizedToken) {
      try {
        await _remoteDataSource.unregisterDeviceToken(
          token: previousToken,
          userIdOverride: previousUserId,
        );
      } catch (_) {}
    }

    await _remoteDataSource.registerDeviceToken(
      token: normalizedToken,
      platform: 'android',
      userIdOverride: userId,
    );
    await _sharedPreferences.setString(_lastPushTokenKey, normalizedToken);
    await _sharedPreferences.setString(_lastPushUserIdKey, userId);
  }

  Future<void> _unregisterCachedToken() async {
    final previousToken = _sharedPreferences.getString(_lastPushTokenKey);
    final previousUserId = _sharedPreferences.getString(_lastPushUserIdKey);
    if (previousToken == null ||
        previousToken.isEmpty ||
        previousUserId == null ||
        previousUserId.isEmpty) {
      return;
    }

    try {
      await _remoteDataSource.unregisterDeviceToken(
        token: previousToken,
        userIdOverride: previousUserId,
      );
    } catch (_) {}
    await _sharedPreferences.remove(_lastPushTokenKey);
    await _sharedPreferences.remove(_lastPushUserIdKey);
  }

  void _deferPayloadOpen(Map<String, dynamic> payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_notificationActionService.openFromPayload(payload));
    });
  }
}
