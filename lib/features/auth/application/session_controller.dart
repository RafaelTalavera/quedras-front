import 'package:flutter/foundation.dart';

import '../domain/auth_session.dart';

final class SessionController extends ChangeNotifier {
  SessionController({AuthSession? initialSession}) : _session = initialSession;

  AuthSession? _session;

  AuthSession? get session => _session;

  bool get isAuthenticated => _session != null;

  String? get authorizationHeader => _session?.authorizationHeader;

  void startSession(AuthSession session) {
    _session = session;
    notifyListeners();
  }

  void clearSession() {
    if (_session == null) {
      return;
    }
    _session = null;
    notifyListeners();
  }
}
