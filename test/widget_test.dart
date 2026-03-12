import 'package:flutter_test/flutter_test.dart';

import 'package:quedras/app/quedras_app.dart';
import 'package:quedras/core/network/api_client.dart';

void main() {
  testWidgets('Carga shell inicial y permite navegar por secciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(QuedrasApp(apiClient: _FakeApiClient()));
    await tester.pumpAndSettle();

    expect(find.text('QUEDRAS'), findsOneWidget);
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
      body: '{"service":"quadras-api","status":"UP","environment":"test"}',
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
}
