import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/notifications/data/models/app_notification_model.dart';

class NotificationsResponseModel {
  const NotificationsResponseModel({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotificationModel> items;
  final int total;
  final int unreadCount;
}

abstract class NotificationsRemoteDataSource {
  Future<NotificationsResponseModel> fetchNotifications({
    int limit,
    bool unreadOnly,
  });

  Future<void> markRead(int notificationId);

  Future<int> markAllRead();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  const NotificationsRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthLocalDataSource authLocalDataSource,
  }) : _apiClient = apiClient,
       _authLocalDataSource = authLocalDataSource;

  final ApiClient _apiClient;
  final AuthLocalDataSource _authLocalDataSource;

  @override
  Future<NotificationsResponseModel> fetchNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to view notifications.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.get(
      '/notifications',
      headers: {'x-user-id': userId},
      queryParameters: {
        'limit': limit,
        'unread_only': unreadOnly,
      },
    );

    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for notifications.');
    }

    return NotificationsResponseModel(
      items: rawItems
          .map(
            (item) =>
                AppNotificationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      total: ((response['total'] as num?) ?? 0).toInt(),
      unreadCount: ((response['unread_count'] as num?) ?? 0).toInt(),
    );
  }

  @override
  Future<void> markRead(int notificationId) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to manage notifications.',
        statusCode: 401,
      );
    }

    await _apiClient.post(
      '/notifications/$notificationId/read',
      headers: {'x-user-id': userId},
    );
  }

  @override
  Future<int> markAllRead() async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to manage notifications.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.post(
      '/notifications/read-all',
      headers: {'x-user-id': userId},
    );
    return ((response['marked_count'] as num?) ?? 0).toInt();
  }

  Future<String?> _currentUserId() async {
    try {
      final session = await _authLocalDataSource.getCachedSession();
      final userId = session?.userId.trim();
      if (userId == null || userId.isEmpty) {
        return null;
      }
      return userId;
    } catch (_) {
      return null;
    }
  }
}
