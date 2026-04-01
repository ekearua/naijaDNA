import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';
import 'package:naijapulse/features/stream/data/datasource/remote/stream_remote_datasource.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_livekit_connection.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class StreamRepositoryImpl implements StreamRepository {
  const StreamRepositoryImpl({required StreamRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final StreamRemoteDataSource _remoteDataSource;

  @override
  Future<List<StreamSession>> getLiveStreams({String? category}) {
    return _remoteDataSource.fetchLiveStreams(category: category);
  }

  @override
  Future<List<StreamSession>> getScheduledStreams({String? category}) {
    return _remoteDataSource.fetchScheduledStreams(category: category);
  }

  @override
  Future<StreamSession> getStreamSession(String streamId) {
    return _remoteDataSource.fetchStreamSession(streamId);
  }

  @override
  Future<List<StreamComment>> getStreamComments(String streamId) {
    return _remoteDataSource.fetchStreamComments(streamId);
  }

  @override
  Future<StreamComment> sendStreamComment({
    required String streamId,
    required String body,
  }) {
    return _remoteDataSource.createStreamComment(
      streamId: streamId,
      body: body,
    );
  }

  @override
  Future<StreamLiveKitConnection> getLiveKitConnection(String streamId) {
    return _remoteDataSource.fetchLiveKitConnection(streamId);
  }

  @override
  Future<StreamSession> createLiveStream({
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) {
    return _remoteDataSource.createLiveStream(
      title: title,
      category: category,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
    );
  }

  @override
  Future<StreamSession> scheduleStream({
    required String title,
    required String category,
    required DateTime scheduledFor,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) {
    return _remoteDataSource.scheduleStream(
      title: title,
      category: category,
      scheduledFor: scheduledFor,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
    );
  }

  @override
  Future<StreamSession> startStream(String streamId) {
    return _remoteDataSource.startStream(streamId);
  }

  @override
  Future<StreamSession> endStream(String streamId) {
    return _remoteDataSource.endStream(streamId);
  }

  @override
  Future<StreamSession> updatePresence({
    required String streamId,
    required String action,
  }) {
    return _remoteDataSource.updatePresence(streamId: streamId, action: action);
  }
}
