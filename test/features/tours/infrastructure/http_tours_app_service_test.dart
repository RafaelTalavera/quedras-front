import 'dart:io';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/features/tours/domain/tours_models.dart';
import 'package:costanorte/features/tours/infrastructure/http_tours_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HttpToursAppService lista resumo y detalle de resumo', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"scheduledCount":3,"cancelledCount":1,"paidCount":2,"pendingCount":1,"totalHours":7.0,"grossAmount":1200.0,"paidAmount":900.0,"pendingAmount":300.0,"commissionAmount":170.0,"netAmount":1030.0,"averageTicket":400.0,"providerBreakdown":[{"code":"1","label":"Agencia A","active":true,"scheduledCount":2,"paidCount":1,"pendingCount":1,"totalHours":4.5,"grossAmount":700.0,"paidAmount":400.0,"pendingAmount":300.0,"commissionAmount":70.0}],"serviceTypeBreakdown":[{"code":"TOUR","label":"Tour","active":null,"scheduledCount":2,"paidCount":2,"pendingCount":0,"totalHours":5.5,"grossAmount":900.0,"paidAmount":900.0,"pendingAmount":0.0,"commissionAmount":140.0}],"paymentMethodBreakdown":[{"code":"PIX","label":"Pix","active":null,"scheduledCount":1,"paidCount":1,"pendingCount":0,"totalHours":2.5,"grossAmount":500.0,"paidAmount":500.0,"pendingAmount":0.0,"commissionAmount":100.0}]}',
        ),
      )
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"groupBy":"PROVIDER","code":"1","label":"Agencia A","active":true,"summary":{"code":"1","label":"Agencia A","active":true,"scheduledCount":2,"paidCount":1,"pendingCount":1,"totalHours":4.5,"grossAmount":700.0,"paidAmount":400.0,"pendingAmount":300.0,"commissionAmount":70.0},"items":[{"bookingId":10,"startAt":"2026-04-10T09:00:00","endAt":"2026-04-10T12:00:00","serviceType":"TOUR","providerId":1,"providerName":"Agencia A","providerOfferingId":null,"providerOfferingName":null,"clientName":"Ana","guestReference":"Apto 101","amount":400.0,"commissionAmount":40.0,"paid":true,"paymentMethod":"CARD","paymentDate":"2026-04-10","status":"SCHEDULED","description":"Passeio maritimo"}]}',
        ),
      );
    final HttpToursAppService service = HttpToursAppService(apiClient: client);

    final ToursSummaryReport summary = await service.getSummaryReport(
      dateFrom: '2026-04-01',
      dateTo: '2026-04-30',
    );
    final ToursSummaryDetail detail = await service.getSummaryDetail(
      groupBy: ToursSummaryGroupBy.provider,
      code: '1',
      dateFrom: '2026-04-01',
      dateTo: '2026-04-30',
    );

    expect(summary.scheduledCount, 3);
    expect(summary.providerBreakdown.single.label, 'Agencia A');
    expect(detail.groupBy, ToursSummaryGroupBy.provider);
    expect(detail.items.single.clientName, 'Ana');
    expect(
      client.calls.first.path,
      'tours/reports/summary?dateFrom=2026-04-01&dateTo=2026-04-30',
    );
    expect(
      client.calls.last.path,
      'tours/reports/summary/details?groupBy=PROVIDER&code=1&dateFrom=2026-04-01&dateTo=2026-04-30',
    );
  });

  test('HttpToursAppService traduce errores y red local', () async {
    final _FakeApiClient apiErrorClient = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 400,
          body: '{"message":"dateFrom must be before or equal to dateTo"}',
        ),
      );
    final HttpToursAppService apiErrorService = HttpToursAppService(
      apiClient: apiErrorClient,
    );

    await expectLater(
      () => apiErrorService.getSummaryReport(
        dateFrom: '2026-04-30',
        dateTo: '2026-04-01',
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'dateFrom must be before or equal to dateTo',
        ),
      ),
    );

    final _FakeApiClient networkClient = _FakeApiClient()
      ..nextError = const SocketException('Connection refused');
    final HttpToursAppService networkService = HttpToursAppService(
      apiClient: networkClient,
    );

    await expectLater(
      () => networkService.listProviders(),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Nao foi possivel conectar ao backend local. Verifique o servidor e a rede interna.',
        ),
      ),
    );
  });
}

final class _FakeApiClient implements ApiClient {
  final List<_Call> calls = <_Call>[];
  final List<ApiResponse> _responses = <ApiResponse>[];
  Object? nextError;

  void enqueue(ApiResponse response) {
    _responses.add(response);
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _consume('GET', path, body: null);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PATCH', path, body: body);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('POST', path, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PUT', path, body: body);
  }

  @override
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) {
    return _consume('DELETE', path, body: null);
  }

  Future<ApiResponse> _consume(
    String method,
    String path, {
    String? body,
  }) async {
    calls.add(_Call(method: method, path: path, body: body));
    final Object? queuedError = nextError;
    if (queuedError != null) {
      nextError = null;
      throw queuedError;
    }
    if (_responses.isEmpty) {
      return const ApiResponse(statusCode: 500, body: '{}');
    }
    return _responses.removeAt(0);
  }
}

final class _Call {
  const _Call({required this.method, required this.path, required this.body});

  final String method;
  final String path;
  final String? body;
}
