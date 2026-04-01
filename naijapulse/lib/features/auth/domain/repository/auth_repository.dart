import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthSession?> getCachedSession();

  Future<void> logout();
}
