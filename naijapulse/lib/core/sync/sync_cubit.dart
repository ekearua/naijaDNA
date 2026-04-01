import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/connectivity/connectivity_cubit.dart';
import 'package:naijapulse/core/error/failures.dart';

enum SyncStatus { idle, syncing, synced, paused, failed }

class SyncState extends Equatable {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final bool isOnline;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.errorMessage,
    this.isOnline = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool? isOnline,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [status, lastSyncedAt, errorMessage, isOnline];
}

class SyncCubit extends Cubit<SyncState> {
  final ConnectivityCubit _connectivityCubit;
  final Future<void> Function() _syncAction;

  StreamSubscription<ConnectivityState>? _connectivitySubscription;
  Timer? _timer;
  bool _isSyncing = false;

  SyncCubit({
    required ConnectivityCubit connectivityCubit,
    required Future<void> Function() syncAction,
  }) : _connectivityCubit = connectivityCubit,
       _syncAction = syncAction,
       super(
         SyncState(
           status: connectivityCubit.state.isOnline
               ? SyncStatus.idle
               : SyncStatus.paused,
           isOnline: connectivityCubit.state.isOnline,
         ),
       );

  Future<void> start() async {
    // Listen for connectivity changes once and schedule feed refreshes for daytime slots.
    _connectivitySubscription ??= _connectivityCubit.stream.listen(
      _onConnectivityChanged,
    );
    _scheduleNextPlannedSync();

    if (_connectivityCubit.state.isOnline) {
      // Prime local cache with fresh data when the shell starts.
      await syncNow(trigger: 'startup');
      return;
    }
    emit(state.copyWith(status: SyncStatus.paused, isOnline: false));
  }

  Future<void> syncNow({String trigger = 'manual'}) async {
    if (_isSyncing) {
      // Avoid overlapping sync cycles while one request batch is in-flight.
      return;
    }

    if (!_connectivityCubit.state.isOnline) {
      emit(
        state.copyWith(
          status: SyncStatus.paused,
          isOnline: false,
          errorMessage: 'Offline. Sync will resume when internet is available.',
        ),
      );
      return;
    }

    _isSyncing = true;
    emit(
      state.copyWith(
        status: SyncStatus.syncing,
        isOnline: true,
        errorMessage: null,
      ),
    );

    try {
      await _syncAction();
      emit(
        state.copyWith(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          isOnline: true,
          errorMessage: null,
        ),
      );
    } catch (error) {
      final failure = mapFailure(error);
      emit(
        state.copyWith(
          status: SyncStatus.failed,
          errorMessage: '$trigger sync failed: ${failure.message}',
          isOnline: true,
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _onConnectivityChanged(
    ConnectivityState connectivityState,
  ) async {
    if (connectivityState.isOnline) {
      // Sync immediately on reconnection so stale cache is refreshed quickly.
      emit(
        state.copyWith(
          isOnline: true,
          status: state.status == SyncStatus.paused
              ? SyncStatus.idle
              : state.status,
          errorMessage: null,
        ),
      );
      await syncNow(trigger: 'reconnected');
      _scheduleNextPlannedSync();
      return;
    }
    emit(
      state.copyWith(
        isOnline: false,
        status: SyncStatus.paused,
        errorMessage: 'Offline. Waiting for internet to sync.',
      ),
    );
  }

  void _scheduleNextPlannedSync() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = _nextScheduledSlot(after: now);
    _timer = Timer(next.difference(now), () async {
      await syncNow(trigger: 'scheduled');
      _scheduleNextPlannedSync();
    });
  }

  DateTime _nextScheduledSlot({required DateTime after}) {
    const syncHours = <int>[
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
    ];

    for (final hour in syncHours) {
      final candidate = DateTime(after.year, after.month, after.day, hour);
      if (candidate.isAfter(after)) {
        return candidate;
      }
    }

    return DateTime(after.year, after.month, after.day + 1, syncHours.first);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _connectivitySubscription?.cancel();
    return super.close();
  }
}
