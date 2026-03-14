import '../domain/auth_session.dart';

abstract interface class AuthAppService {
  Future<AuthSession> login({
    required String username,
    required String password,
  });
}
