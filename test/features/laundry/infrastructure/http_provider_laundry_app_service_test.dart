import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/laundry/domain/provider_laundry_models.dart';
import 'package:costanorte/features/laundry/infrastructure/http_provider_laundry_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lista documentos seguros y paginados del proveedor', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"page":0,"size":20,"hasNext":false,"items":[{"id":11,"reference":"ENV-11","documentType":"STANDARD_DISPATCH","status":"SUBMITTED","effectiveAt":"2026-11-03T10:00:00Z","submittedAt":"2026-11-03T10:05:00Z","version":2}]}',
      ),
    );

    final page = await HttpProviderLaundryAppService(
      apiClient: client,
    ).listDocuments();

    expect(client.path, 'provider/documents?page=0&size=20');
    expect(page.items.single.reference, 'ENV-11');
    expect(page.items.single.status, 'SUBMITTED');
    expect(page.hasNext, isFalse);
  });

  test('consulta solo un bucket permitido de stock del proveedor', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"page":0,"size":50,"hasNext":false,"items":[{"balanceId":4,"itemId":8,"itemName":"Toalha","unitType":"PIECE","bucket":"PROVIDER_REWASH","providerId":3,"providerName":"Lavanderia","quantity":2.000,"oldestEffectiveAt":"2026-11-01T10:00:00Z","ageDays":2,"version":1}]}',
      ),
    );

    final page = await HttpProviderLaundryAppService(
      apiClient: client,
    ).listStock(bucket: ProviderLaundryStockBucket.rewash);

    expect(client.path, 'provider/stock?bucket=PROVIDER_REWASH&page=0&size=50');
    expect(page.items.single.itemName, 'Toalha');
    expect(page.items.single.quantity, 2);
  });

  test('rechaza payload paginado invalido', () async {
    final service = HttpProviderLaundryAppService(
      apiClient: _FakeApiClient(
        const ApiResponse(statusCode: 200, body: '{"items":{}}'),
      ),
    );

    await expectLater(
      service.listReturns(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('confirma documento con version e idempotencia', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":11,"reference":"ENV-11","documentType":"STANDARD_DISPATCH","status":"CONFIRMED","providerId":3,"providerName":"Lavanderia","effectiveAt":"2026-11-03T10:00:00Z","notes":null,"submittedAt":"2026-11-03T10:05:00Z","version":3,"lines":[{"id":1,"itemId":8,"itemName":"Toalha","quantity":5}],"confirmations":[]}',
      ),
    );

    final result = await HttpProviderLaundryAppService(
      apiClient: client,
    ).acknowledgeDocument(id: 11, version: 2);

    expect(client.method, 'POST');
    expect(client.path, 'dispatches/11/acknowledgements');
    expect(client.body, '{"version":2,"notes":null}');
    expect(client.headers?['Idempotency-Key'], isNotEmpty);
    expect(result.status, 'CONFIRMED');
    expect(result.lines.single.itemName, 'Toalha');
  });

  test('rechaza observacion vacia antes de llamar al backend', () {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(statusCode: 500, body: '{}'),
    );
    final service = HttpProviderLaundryAppService(apiClient: client);

    expect(
      () => service.observeDocument(id: 11, version: 2, notes: '  '),
      throwsArgumentError,
    );
    expect(client.method, isNull);
  });
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.response);

  final ApiResponse response;
  String? path;
  String? method;
  String? body;
  Map<String, String>? headers;

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async {
    method = 'GET';
    this.path = path;
    this.headers = headers;
    return response;
  }

  @override
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => throw UnimplementedError();

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    method = 'POST';
    this.path = path;
    this.headers = headers;
    this.body = body;
    return response;
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => throw UnimplementedError();
}
