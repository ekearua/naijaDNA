import 'package:flutter/foundation.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';
import 'package:naijapulse/features/auth/data/models/auth_session_model.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({
    required AuthLocalDataSource localDataSource,
    required AuthRemoteDataSource remoteDataSource,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource;

  final AuthLocalDataSource _localDataSource;
  final AuthRemoteDataSource _remoteDataSource;

  AuthSession? _session;
  bool _isInitialized = false;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    await refreshFromCache();
    await refreshEntitlementsFromServer();
  }

  Future<void> refreshFromCache() async {
    _session = await _localDataSource.getCachedSession();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setSession(AuthSession session) async {
    _session = session;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _session = null;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> refreshEntitlementsFromServer() async {
    final current = _session;
    if (current == null) {
      return;
    }

    final currentModel = AuthSessionModel.fromEntity(current);
    try {
      final refreshed = await _remoteDataSource.refreshSession(
        currentSession: currentModel,
      );
      await _localDataSource.cacheSession(refreshed);
      _session = refreshed;
      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      // Keep the cached session if the network refresh fails.
    }
  }
}
