import 'package:equatable/equatable.dart';

class StreamLiveKitConnection extends Equatable {
  const StreamLiveKitConnection({
    required this.wsUrl,
    required this.token,
    required this.roomName,
    required this.participantIdentity,
    required this.participantName,
    required this.canPublish,
    required this.canSubscribe,
  });

  final String wsUrl;
  final String token;
  final String roomName;
  final String participantIdentity;
  final String participantName;
  final bool canPublish;
  final bool canSubscribe;

  @override
  List<Object?> get props => [
    wsUrl,
    token,
    roomName,
    participantIdentity,
    participantName,
    canPublish,
    canSubscribe,
  ];
}
