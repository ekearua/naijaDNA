import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required AuthSessionController authSessionController,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _authSessionController = authSessionController;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final AuthSessionController _authSessionController;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      await _localDataSource.cacheSession(session);
      await _authSessionController.setSession(session);
      return session;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException('Login failed: $error');
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final session = await _remoteDataSource.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _localDataSource.cacheSession(session);
      await _authSessionController.setSession(session);
      return session;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException('Registration failed: $error');
    }
  }

  @override
  Future<AuthSession?> getCachedSession() async {
    try {
      final session = await _localDataSource.getCachedSession();
      if (session != _authSessionController.session) {
        if (session == null) {
          await _authSessionController.clearSession();
        } else {
          await _authSessionController.setSession(session);
        }
      }
      return session;
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to read cached auth session: $error');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _localDataSource.clearSession();
      await _authSessionController.clearSession();
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to clear auth session: $error');
    }
  }
}
