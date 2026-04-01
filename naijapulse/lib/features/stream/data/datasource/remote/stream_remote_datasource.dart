import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/stream/data/models/stream_comment_model.dart';
import 'package:naijapulse/features/stream/data/datasource/local/stream_local_datasource.dart';
import 'package:naijapulse/features/stream/data/models/stream_livekit_connection_model.dart';
import 'package:naijapulse/features/stream/data/models/stream_session_model.dart';

abstract class StreamRemoteDataSource {
  Future<List<StreamSessionModel>> fetchLiveStreams({String? category});

  Future<List<StreamSessionModel>> fetchScheduledStreams({String? category});

  Future<StreamSessionModel> fetchStreamSession(String streamId);

  Future<List<StreamCommentModel>> fetchStreamComments(String streamId);

  Future<StreamCommentModel> createStreamComment({
    required String streamId,
    required String body,
  });

  Future<StreamLiveKitConnectionModel> fetchLiveKitConnection(String streamId);

  Future<StreamSessionModel> createLiveStream({
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  });

  Future<StreamSessionModel> scheduleStream({
    required String title,
    required String category,
    required DateTime scheduledFor,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  });

  Future<StreamSessionModel> startStream(String streamId);

  Future<StreamSessionModel> endStream(String streamId);

  Future<StreamSessionModel> updatePresence({
    required String streamId,
    required String action,
  });
}

class StreamRemoteDataSourceImpl implements StreamRemoteDataSource {
  const StreamRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthLocalDataSource authLocalDataSource,
    required StreamLocalDataSource localDataSource,
  }) : _apiClient = apiClient,
       _authLocalDataSource = authLocalDataSource,
       _localDataSource = localDataSource;

  final ApiClient _apiClient;
  final AuthLocalDataSource _authLocalDataSource;
  final StreamLocalDataSource _localDataSource;

  @override
  Future<List<StreamSessionModel>> fetchLiveStreams({String? category}) async {
    return _fetchStreamList('/streams/live', category: category);
  }

  @override
  Future<List<StreamSessionModel>> fetchScheduledStreams({
    String? category,
  }) async {
    return _fetchStreamList('/streams/scheduled', category: category);
  }

  @override
  Future<StreamSessionModel> fetchStreamSession(String streamId) async {
    final headers = await _authHeaders(required: false);
    try {
      final response = await _apiClient.get(
        '/streams/$streamId',
        headers: headers,
      );
      return StreamSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse stream session response: $error');
    }
  }

  @override
  Future<List<StreamCommentModel>> fetchStreamComments(String streamId) async {
    final headers = await _authHeaders(required: false);
    try {
      final response = await _apiClient.get(
        '/streams/$streamId/comments',
        headers: headers,
      );
      final rawItems = response['items'];
      if (rawItems is! List<dynamic>) {
        throw const ParseException(
          'Invalid response format for stream comments.',
        );
      }
      return rawItems
          .map(
            (item) => StreamCommentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse stream comments response: $error');
    }
  }

  @override
  Future<StreamCommentModel> createStreamComment({
    required String streamId,
    required String body,
  }) async {
    final headers = await _authHeaders(required: true);
    try {
      final response = await _apiClient.post(
        '/streams/$streamId/comments',
        headers: headers,
        data: {'body': body.trim()},
      );
      return StreamCommentModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse create comment response: $error');
    }
  }

  @override
  Future<StreamLiveKitConnectionModel> fetchLiveKitConnection(
    String streamId,
  ) async {
    final headers = await _authHeaders(required: false);
    final viewerId = await _localDataSource.getOrCreateViewerId();
    try {
      final response = await _apiClient.post(
        '/streams/$streamId/livekit-connection',
        headers: headers,
        data: {'viewer_id': viewerId},
      );
      return StreamLiveKitConnectionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException(
        'Could not parse LiveKit connection response: $error',
      );
    }
  }

  @override
  Future<StreamSessionModel> createLiveStream({
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) async {
    return _createStream(
      mode: 'go_live',
      title: title,
      category: category,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
    );
  }

  @override
  Future<StreamSessionModel> scheduleStream({
    required String title,
    required String category,
    required DateTime scheduledFor,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) async {
    return _createStream(
      mode: 'schedule',
      title: title,
      category: category,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
      scheduledFor: scheduledFor,
    );
  }

  @override
  Future<StreamSessionModel> startStream(String streamId) async {
    final headers = await _authHeaders(required: true);
    try {
      final response = await _apiClient.post(
        '/streams/$streamId/start',
        headers: headers,
      );
      return StreamSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse start stream response: $error');
    }
  }

  @override
  Future<StreamSessionModel> endStream(String streamId) async {
    final headers = await _authHeaders(required: true);
    try {
      final response = await _apiClient.post(
        '/streams/$streamId/end',
        headers: headers,
      );
      return StreamSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse end stream response: $error');
    }
  }

  @override
  Future<StreamSessionModel> updatePresence({
    required String streamId,
    required String action,
  }) async {
    final headers = await _authHeaders(required: false);
    final viewerId = await _localDataSource.getOrCreateViewerId();
    try {
      final response = await _apiClient.post(
        '/streams/$streamId/presence',
        headers: headers,
        data: {'action': action, 'viewer_id': viewerId},
      );
      final rawStream = response['stream'];
      if (rawStream is! Map<String, dynamic>) {
        throw const ParseException('Invalid stream presence response.');
      }
      return StreamSessionModel.fromJson(rawStream);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse stream presence response: $error');
    }
  }

  Future<List<StreamSessionModel>> _fetchStreamList(
    String path, {
    String? category,
  }) async {
    final headers = await _authHeaders(required: false);
    try {
      final response = await _apiClient.get(
        path,
        headers: headers,
        queryParameters: {
          'limit': 20,
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
        },
      );
      final rawItems = response['items'];
      if (rawItems is! List<dynamic>) {
        throw const ParseException('Invalid response format for streams.');
      }
      return rawItems
          .map(
            (item) => StreamSessionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse streams response: $error');
    }
  }

  Future<StreamSessionModel> _createStream({
    required String mode,
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
    DateTime? scheduledFor,
  }) async {
    final headers = await _authHeaders(required: true);
    try {
      final response = await _apiClient.post(
        '/streams',
        headers: headers,
        data: {
          'mode': mode,
          'title': title.trim(),
          'category': category.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
            'cover_image_url': coverImageUrl.trim(),
          if (streamUrl != null && streamUrl.trim().isNotEmpty)
            'stream_url': streamUrl.trim(),
          if (scheduledFor != null)
            'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        },
      );
      return StreamSessionModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse create stream response: $error');
    }
  }

  Future<Map<String, String>?> _authHeaders({required bool required}) async {
    final session = await _authLocalDataSource.getCachedSession();
    final userId = session?.userId.trim();
    if (userId != null && userId.isNotEmpty) {
      return {'x-user-id': userId};
    }
    if (required) {
      throw const ServerException(
        'You need to sign in before hosting or scheduling a stream.',
        statusCode: 401,
      );
    }
    return null;
  }
}
