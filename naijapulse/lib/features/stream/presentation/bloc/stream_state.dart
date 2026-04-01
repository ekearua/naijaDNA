import 'package:equatable/equatable.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';

enum StreamStatus { initial, loading, loaded, error }

enum StreamActionStatus { idle, submitting, success, failure }

class StreamState extends Equatable {
  const StreamState({
    this.status = StreamStatus.initial,
    this.actionStatus = StreamActionStatus.idle,
    this.liveStreams = const [],
    this.scheduledStreams = const [],
    this.selectedSession,
    this.errorMessage,
    this.actionMessage,
    this.pendingNavigationSessionId,
  });

  final StreamStatus status;
  final StreamActionStatus actionStatus;
  final List<StreamSession> liveStreams;
  final List<StreamSession> scheduledStreams;
  final StreamSession? selectedSession;
  final String? errorMessage;
  final String? actionMessage;
  final String? pendingNavigationSessionId;

  StreamState copyWith({
    StreamStatus? status,
    StreamActionStatus? actionStatus,
    List<StreamSession>? liveStreams,
    List<StreamSession>? scheduledStreams,
    StreamSession? selectedSession,
    String? errorMessage,
    String? actionMessage,
    String? pendingNavigationSessionId,
    bool clearSelectedSession = false,
    bool clearErrorMessage = false,
    bool clearActionMessage = false,
    bool clearPendingNavigation = false,
  }) {
    return StreamState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      liveStreams: liveStreams ?? this.liveStreams,
      scheduledStreams: scheduledStreams ?? this.scheduledStreams,
      selectedSession: clearSelectedSession
          ? null
          : (selectedSession ?? this.selectedSession),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      pendingNavigationSessionId: clearPendingNavigation
          ? null
          : (pendingNavigationSessionId ?? this.pendingNavigationSessionId),
    );
  }

  @override
  List<Object?> get props => [
    status,
    actionStatus,
    liveStreams,
    scheduledStreams,
    selectedSession,
    errorMessage,
    actionMessage,
    pendingNavigationSessionId,
  ];
}
