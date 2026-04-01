import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_livekit_connection.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';

abstract class StreamRepository {
  Future<List<StreamSession>> getLiveStreams({String? category});

  Future<List<StreamSession>> getScheduledStreams({String? category});

  Future<StreamSession> getStreamSession(String streamId);

  Future<List<StreamComment>> getStreamComments(String streamId);

  Future<StreamComment> sendStreamComment({
    required String streamId,
    required String body,
  });

  Future<StreamLiveKitConnection> getLiveKitConnection(String streamId);

  Future<StreamSession> createLiveStream({
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  });

  Future<StreamSession> scheduleStream({
    required String title,
    required String category,
    required DateTime scheduledFor,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  });

  Future<StreamSession> startStream(String streamId);

  Future<StreamSession> endStream(String streamId);

  Future<StreamSession> updatePresence({
    required String streamId,
    required String action,
  });
}
