import 'package:flutter_test/flutter_test.dart';

import 'package:costanorte/app/costanorte_app.dart';
import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/features/reservations/application/reservation_app_service.dart';

void main() {
  testWidgets('Carga shell inicial y permite navegar por secciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CostaNorteApp(
        apiClient: _FakeApiClient(),
        reservationAppService: InMemoryReservationAppService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COSTANORTE'), findsOneWidget);
    expect(find.text('Panel operativo del hotel'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda de cancha'), findsOneWidget);
  });
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
