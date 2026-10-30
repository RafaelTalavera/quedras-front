import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:costanorte/app/costanorte_app.dart';
import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/push/push_notification_service.dart';
import 'package:costanorte/features/auth/application/auth_app_service.dart';
import 'package:costanorte/features/auth/domain/auth_session.dart';
import 'package:costanorte/features/reservations/application/reservation_app_service.dart';

void main() {
  testWidgets('Login inicial, navegacion autenticada y logout', (
    WidgetTester tester,
  ) async {
    final _FakeAuthAppService authAppService = _FakeAuthAppService();
    final _FakePushNotificationService pushService =
        _FakePushNotificationService();
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CostaNorteApp(
        apiClient: _FakeApiClient(),
        authAppService: authAppService,
        reservationAppService: InMemoryReservationAppService(),
        pushNotificationService: pushService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'operador.demo');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('Acessar sistema'));
    await tester.pumpAndSettle();

    expect(authAppService.lastUsername, 'operador.demo');
    expect(pushService.startedWithAuthorization, 'Bearer test-jwt');
    expect(find.text('Quadras de tenis'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(pushService.stopCalls, 1);
  });
}

final class _FakePushNotificationService implements PushNotificationService {
  String? startedWithAuthorization;
  int stopCalls = 0;

  @override
  Stream<void> get notificationsChanged => const Stream<void>.empty();

  @override
  Stream<PushMaintenanceOpenRequest> get openedMaintenanceOrders =>
      const Stream<PushMaintenanceOpenRequest>.empty();

  @override
  void dispose() {}

  @override
  Future<void> heartbeat() async {}

  @override
  Future<void> startSession(
    String authorizationHeader,
    ApiClient apiClient,
  ) async {
    startedWithAuthorization = authorizationHeader;
  }

  @override
  Future<void> stopSession() async {
    stopCalls++;
  }

  @override
  PushMaintenanceOpenRequest? takePendingMaintenanceOrder() => null;
}

final class _FakeAuthAppService implements AuthAppService {
  String? lastUsername;
  String? lastPassword;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    lastPassword = password;
    return const AuthSession(
      accessToken: 'test-jwt',
      tokenType: 'Bearer',
      expiresInSeconds: 1800,
      username: 'operador.demo',
      role: 'OPERATOR',
    );
  }
}

class _FakeApiClient implements ApiClient {
  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async {
    return const ApiResponse(
      statusCode: 200,
      body: '{"service":"costanorte-api","status":"UP","environment":"test"}',
    );
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return const ApiResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return const ApiResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return const ApiResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return const ApiResponse(statusCode: 200, body: '{}');
  }
}
