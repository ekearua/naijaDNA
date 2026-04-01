import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/usecases/create_live_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/end_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_live_streams.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_scheduled_streams.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_stream_session.dart';
import 'package:naijapulse/features/stream/domain/usecases/schedule_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/start_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/update_stream_presence.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_event.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_state.dart';

export 'stream_event.dart';
export 'stream_state.dart';

class StreamBloc extends Bloc<StreamEvent, StreamState> {
  StreamBloc({
    required GetLiveStreams getLiveStreams,
    required GetScheduledStreams getScheduledStreams,
    required GetStreamSession getStreamSession,
    required CreateLiveStream createLiveStream,
    required ScheduleStream scheduleStream,
    required StartStream startStream,
    required EndStream endStream,
    required UpdateStreamPresence updateStreamPresence,
  }) : _getLiveStreams = getLiveStreams,
       _getScheduledStreams = getScheduledStreams,
       _getStreamSession = getStreamSession,
       _createLiveStream = createLiveStream,
       _scheduleStream = scheduleStream,
       _startStream = startStream,
       _endStream = endStream,
       _updateStreamPresence = updateStreamPresence,
       super(const StreamState()) {
    on<LoadStreamsRequested>(_onLoadStreamsRequested);
    on<LoadStreamSessionRequested>(_onLoadStreamSessionRequested);
    on<CreateLiveStreamRequested>(_onCreateLiveStreamRequested);
    on<ScheduleStreamRequested>(_onScheduleStreamRequested);
    on<StartStreamRequested>(_onStartStreamRequested);
    on<EndStreamRequested>(_onEndStreamRequested);
    on<UpdateStreamPresenceRequested>(_onUpdateStreamPresenceRequested);
    on<ClearStreamActionRequested>(_onClearStreamActionRequested);
  }

  final GetLiveStreams _getLiveStreams;
  final GetScheduledStreams _getScheduledStreams;
  final GetStreamSession _getStreamSession;
  final CreateLiveStream _createLiveStream;
  final ScheduleStream _scheduleStream;
  final StartStream _startStream;
  final EndStream _endStream;
  final UpdateStreamPresence _updateStreamPresence;

  Future<void> _onLoadStreamsRequested(
    LoadStreamsRequested event,
    Emitter<StreamState> emit,
  ) async {
    if (!event.silent) {
      emit(
        state.copyWith(status: StreamStatus.loading, clearErrorMessage: true),
      );
    }

    try {
      final liveStreams = await _getLiveStreams(category: event.category);
      final scheduledStreams = await _getScheduledStreams(
        category: event.category,
      );
      emit(
        state.copyWith(
          status: StreamStatus.loaded,
          liveStreams: liveStreams,
          scheduledStreams: scheduledStreams,
          selectedSession: _refreshSelectedSession(
            current: state.selectedSession,
            liveStreams: liveStreams,
            scheduledStreams: scheduledStreams,
          ),
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: StreamStatus.error,
          errorMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onLoadStreamSessionRequested(
    LoadStreamSessionRequested event,
    Emitter<StreamState> emit,
  ) async {
    final initialSession =
        event.initialSession ?? _findSessionById(event.streamId, state);
    if (initialSession != null) {
      emit(state.copyWith(selectedSession: initialSession));
    }

    try {
      final session = await _getStreamSession(event.streamId);
      emit(
        state.copyWith(
          status: StreamStatus.loaded,
          selectedSession: session,
          liveStreams: _mergeLiveList(state.liveStreams, session),
          scheduledStreams: _mergeScheduledList(
            state.scheduledStreams,
            session,
          ),
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      if (initialSession == null) {
        emit(
          state.copyWith(
            status: StreamStatus.error,
            errorMessage: mapFailure(error).message,
          ),
        );
      }
    }
  }

  Future<void> _onCreateLiveStreamRequested(
    CreateLiveStreamRequested event,
    Emitter<StreamState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: StreamActionStatus.submitting,
        clearActionMessage: true,
        clearPendingNavigation: true,
      ),
    );
    try {
      final session = await _createLiveStream(
        title: event.title,
        category: event.category,
        description: event.description,
        coverImageUrl: event.coverImageUrl,
        streamUrl: event.streamUrl,
      );
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.success,
          actionMessage: 'Live stream started.',
          selectedSession: session,
          liveStreams: _insertOrReplaceLive(state.liveStreams, session),
          scheduledStreams: _removeById(state.scheduledStreams, session.id),
          pendingNavigationSessionId: session.id,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.failure,
          actionMessage: mapFailure(error).message,
          clearPendingNavigation: true,
        ),
      );
    }
  }

  Future<void> _onScheduleStreamRequested(
    ScheduleStreamRequested event,
    Emitter<StreamState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: StreamActionStatus.submitting,
        clearActionMessage: true,
        clearPendingNavigation: true,
      ),
    );
    try {
      final session = await _scheduleStream(
        title: event.title,
        category: event.category,
        scheduledFor: event.scheduledFor,
        description: event.description,
        coverImageUrl: event.coverImageUrl,
        streamUrl: event.streamUrl,
      );
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.success,
          actionMessage: 'Stream scheduled successfully.',
          selectedSession: session,
          scheduledStreams: _insertOrReplaceScheduled(
            state.scheduledStreams,
            session,
          ),
          liveStreams: _removeById(state.liveStreams, session.id),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.failure,
          actionMessage: mapFailure(error).message,
          clearPendingNavigation: true,
        ),
      );
    }
  }

  Future<void> _onStartStreamRequested(
    StartStreamRequested event,
    Emitter<StreamState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: StreamActionStatus.submitting,
        clearActionMessage: true,
      ),
    );
    try {
      final session = await _startStream(event.streamId);
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.success,
          actionMessage: 'Stream is live now.',
          selectedSession: session,
          liveStreams: _insertOrReplaceLive(state.liveStreams, session),
          scheduledStreams: _removeById(state.scheduledStreams, session.id),
          pendingNavigationSessionId: session.id,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.failure,
          actionMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onEndStreamRequested(
    EndStreamRequested event,
    Emitter<StreamState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: StreamActionStatus.submitting,
        clearActionMessage: true,
      ),
    );
    try {
      final session = await _endStream(event.streamId);
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.success,
          actionMessage: 'Stream ended.',
          selectedSession: session,
          liveStreams: _removeById(state.liveStreams, session.id),
          scheduledStreams: _removeById(state.scheduledStreams, session.id),
          clearPendingNavigation: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: StreamActionStatus.failure,
          actionMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onUpdateStreamPresenceRequested(
    UpdateStreamPresenceRequested event,
    Emitter<StreamState> emit,
  ) async {
    try {
      final session = await _updateStreamPresence(
        streamId: event.streamId,
        action: event.action,
      );
      emit(
        state.copyWith(
          selectedSession: state.selectedSession?.id == session.id
              ? session
              : state.selectedSession,
          liveStreams: _mergeLiveList(state.liveStreams, session),
          scheduledStreams: _mergeScheduledList(
            state.scheduledStreams,
            session,
          ),
        ),
      );
    } catch (_) {
      // Presence refresh should not disrupt the screen if the network blips.
    }
  }

  void _onClearStreamActionRequested(
    ClearStreamActionRequested event,
    Emitter<StreamState> emit,
  ) {
    emit(
      state.copyWith(
        actionStatus: StreamActionStatus.idle,
        clearActionMessage: true,
        clearPendingNavigation: true,
      ),
    );
  }

  StreamSession? _findSessionById(String streamId, StreamState state) {
    for (final session in [...state.liveStreams, ...state.scheduledStreams]) {
      if (session.id == streamId) {
        return session;
      }
    }
    if (state.selectedSession?.id == streamId) {
      return state.selectedSession;
    }
    return null;
  }

  StreamSession? _refreshSelectedSession({
    required StreamSession? current,
    required List<StreamSession> liveStreams,
    required List<StreamSession> scheduledStreams,
  }) {
    if (current == null) {
      return null;
    }
    for (final session in [...liveStreams, ...scheduledStreams]) {
      if (session.id == current.id) {
        return session;
      }
    }
    return current;
  }

  List<StreamSession> _mergeLiveList(
    List<StreamSession> sessions,
    StreamSession session,
  ) => session.isLive
      ? _insertOrReplaceLive(sessions, session)
      : _removeById(sessions, session.id);

  List<StreamSession> _mergeScheduledList(
    List<StreamSession> sessions,
    StreamSession session,
  ) => session.isScheduled
      ? _insertOrReplaceScheduled(sessions, session)
      : _removeById(sessions, session.id);

  List<StreamSession> _insertOrReplaceLive(
    List<StreamSession> sessions,
    StreamSession session,
  ) {
    final updated = _removeById(sessions, session.id);
    if (!session.isLive) {
      return updated;
    }
    return [session, ...updated]..sort((a, b) {
      final aTime = a.startedAt ?? a.createdAt;
      final bTime = b.startedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

  List<StreamSession> _insertOrReplaceScheduled(
    List<StreamSession> sessions,
    StreamSession session,
  ) {
    final updated = _removeById(sessions, session.id);
    if (!session.isScheduled) {
      return updated;
    }
    return [session, ...updated]..sort((a, b) {
      final aTime = a.scheduledFor ?? a.createdAt;
      final bTime = b.scheduledFor ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
  }

  List<StreamSession> _removeById(List<StreamSession> sessions, String id) {
    return sessions.where((session) => session.id != id).toList();
  }
}
