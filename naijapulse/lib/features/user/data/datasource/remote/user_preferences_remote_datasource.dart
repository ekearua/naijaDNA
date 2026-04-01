import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/user/data/models/user_personalization_profile_model.dart';
import 'package:naijapulse/features/user/data/models/user_settings_model.dart';

abstract class UserPreferencesRemoteDataSource {
  Future<UserPersonalizationProfileModel> fetchProfile({
    required String userId,
  });

  Future<UserPersonalizationProfileModel> setInterests({
    required String userId,
    required List<String> enabledCategoryIds,
    List<String>? topics,
  });

  Future<UserSettingsModel> fetchSettings({required String userId});

  Future<UserSettingsModel> updateSettings({
    required String userId,
    bool? breakingNewsAlerts,
    bool? liveStreamAlerts,
    bool? commentReplies,
    String? theme,
    String? textSize,
  });

  Future<Map<String, dynamic>> createAccessRequest({
    required String userId,
    required String accessType,
    required String reason,
  });

  Future<List<Map<String, dynamic>>> fetchAccessRequests({
    required String userId,
  });
}

class UserPreferencesRemoteDataSourceImpl
    implements UserPreferencesRemoteDataSource {
  const UserPreferencesRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserPersonalizationProfileModel> fetchProfile({
    required String userId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/preferences/interests',
        headers: _headers(userId),
      );
      return UserPersonalizationProfileModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse personalization profile: $error');
    }
  }

  @override
  Future<UserPersonalizationProfileModel> setInterests({
    required String userId,
    required List<String> enabledCategoryIds,
    List<String>? topics,
  }) async {
    try {
      final response = await _apiClient.post(
        '/preferences/interests',
        headers: _headers(userId),
        data: {
          'interests': enabledCategoryIds
              .map((categoryId) => {'category_id': categoryId, 'weight': 0.9})
              .toList(),
          'topics': topics,
          'replace_existing': true,
        },
      );
      return UserPersonalizationProfileModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException(
        'Could not parse updated personalization profile: $error',
      );
    }
  }

  @override
  Future<UserSettingsModel> fetchSettings({required String userId}) async {
    try {
      final response = await _apiClient.get(
        '/users/${userId.trim()}/preferences',
      );
      return UserSettingsModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse user settings: $error');
    }
  }

  @override
  Future<UserSettingsModel> updateSettings({
    required String userId,
    bool? breakingNewsAlerts,
    bool? liveStreamAlerts,
    bool? commentReplies,
    String? theme,
    String? textSize,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (breakingNewsAlerts != null) {
        payload['breaking_news_alerts'] = breakingNewsAlerts;
      }
      if (liveStreamAlerts != null) {
        payload['live_stream_alerts'] = liveStreamAlerts;
      }
      if (commentReplies != null) {
        payload['comment_replies'] = commentReplies;
      }
      if (theme != null) {
        payload['theme'] = theme;
      }
      if (textSize != null) {
        payload['text_size'] = textSize;
      }

      final response = await _apiClient.patch(
        '/users/${userId.trim()}/preferences',
        data: payload,
      );
      return UserSettingsModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse updated user settings: $error');
    }
  }

  @override
  Future<Map<String, dynamic>> createAccessRequest({
    required String userId,
    required String accessType,
    required String reason,
  }) async {
    try {
      return await _apiClient.post(
        '/users/${userId.trim()}/access-requests',
        data: {'access_type': accessType.trim(), 'reason': reason.trim()},
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse access request response: $error');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAccessRequests({
    required String userId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/users/${userId.trim()}/access-requests',
      );
      final items = response['items'];
      if (items is! List<dynamic>) {
        throw const ParseException('Invalid access request response.');
      }
      return items.whereType<Map<String, dynamic>>().toList(growable: false);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse access requests: $error');
    }
  }

  Map<String, String> _headers(String userId) {
    return {'x-user-id': userId.trim()};
  }
}
