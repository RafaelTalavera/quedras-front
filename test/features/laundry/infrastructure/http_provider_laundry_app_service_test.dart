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
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.response);

  final ApiResponse response;
  String? path;

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async {
    this.path = path;
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
  }) => throw UnimplementedError();

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => throw UnimplementedError();
}
