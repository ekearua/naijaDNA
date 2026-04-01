import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ConnectivityStatus { unknown, online, offline }

class ConnectivityState extends Equatable {
  final ConnectivityStatus status;
  final DateTime? updatedAt;

  const ConnectivityState({
    this.status = ConnectivityStatus.unknown,
    this.updatedAt,
  });

  bool get isOnline => status == ConnectivityStatus.online;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? updatedAt,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [status, updatedAt];
}

class ConnectivityCubit extends Cubit<ConnectivityState> {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityCubit({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity(),
      super(const ConnectivityState());

  Future<void> start() async {
    // Emit an immediate status before subscribing to live connectivity updates.
    final initial = await _connectivity.checkConnectivity();
    _emitConnectivity(initial);
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      _emitConnectivity,
    );
  }

  void _emitConnectivity(List<ConnectivityResult> results) {
    // Treat any available transport as online for sync and fetch decisions.
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    emit(
      state.copyWith(
        status: isOnline
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
