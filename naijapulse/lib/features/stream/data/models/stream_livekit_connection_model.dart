import 'package:naijapulse/features/stream/domain/entities/stream_livekit_connection.dart';

class StreamLiveKitConnectionModel extends StreamLiveKitConnection {
  const StreamLiveKitConnectionModel({
    required super.wsUrl,
    required super.token,
    required super.roomName,
    required super.participantIdentity,
    required super.participantName,
    required super.canPublish,
    required super.canSubscribe,
  });

  factory StreamLiveKitConnectionModel.fromJson(Map<String, dynamic> json) {
    return StreamLiveKitConnectionModel(
      wsUrl: (json['wsUrl'] ?? json['ws_url'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      roomName: (json['roomName'] ?? json['room_name'] ?? '').toString(),
      participantIdentity:
          (json['participantIdentity'] ?? json['participant_identity'] ?? '')
              .toString(),
      participantName:
          (json['participantName'] ?? json['participant_name'] ?? '')
              .toString(),
      canPublish:
          json['canPublish'] as bool? ?? json['can_publish'] as bool? ?? false,
      canSubscribe:
          json['canSubscribe'] as bool? ??
          json['can_subscribe'] as bool? ??
          true,
    );
  }
}
