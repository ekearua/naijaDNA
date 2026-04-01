import 'dart:convert';

import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/features/auth/data/models/auth_session_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheSession(AuthSessionModel session);

  Future<AuthSessionModel?> getCachedSession();

  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const _sessionKey = 'auth_session_v1';

  const AuthLocalDataSourceImpl({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<void> cacheSession(AuthSessionModel session) async {
    final raw = jsonEncode(session.toCacheJson());
    final ok = await _sharedPreferences.setString(_sessionKey, raw);
    if (!ok) {
      throw const CacheException('Failed to persist auth session.');
    }
  }

  @override
  Future<AuthSessionModel?> getCachedSession() async {
    final raw = _sharedPreferences.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const CacheException('Invalid cached auth session payload.');
      }
      return AuthSessionModel.fromCacheJson(json);
    } catch (error) {
      throw CacheException('Failed to decode cached auth session: $error');
    }
  }

  @override
  Future<void> clearSession() async {
    await _sharedPreferences.remove(_sessionKey);
  }
}
