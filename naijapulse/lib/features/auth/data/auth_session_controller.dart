import 'package:flutter/foundation.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({required AuthLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final AuthLocalDataSource _localDataSource;

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
}
