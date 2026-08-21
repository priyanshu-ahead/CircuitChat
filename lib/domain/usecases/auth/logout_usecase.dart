import '../../../data/repositories/auth_repository.dart';

/// Business rule: logout from server + clear all local credentials.
class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
