import 'package:naijapulse/features/auth/domain/repository/auth_repository.dart';

class LogoutUser {
  const LogoutUser(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.logout();
  }
}
