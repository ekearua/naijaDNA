import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/repository/auth_repository.dart';

class GetCachedSession {
  const GetCachedSession(this._repository);

  final AuthRepository _repository;

  Future<AuthSession?> call() {
    return _repository.getCachedSession();
  }
}
