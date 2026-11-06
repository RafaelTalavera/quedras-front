import 'dart:convert';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:costanorte/features/laundry/infrastructure/http_laundry_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('envía filtros y deserializa lista de remesas', () async {
    final _FakeApiClient client = _FakeApiClient(
      ApiResponse(statusCode: 200, body: jsonEncode(<Object>[])),
    );
    await HttpLaundryAppService(apiClient: client).listShipments(
      status: LaundryShipmentStatus.sent,
      providerId: 3,
      dateFrom: '2026-10-01',
      dateTo: '2026-10-31',
    );
    expect(client.lastPath, contains('status=SENT'));
    expect(client.lastPath, contains('providerId=3'));
  });

  test('expone HTTP 409 para que la UI recargue sin reenviar', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 409,
        body: '{"message":"Versión desactualizada"}',
      ),
    );
    final HttpLaundryAppService service = HttpLaundryAppService(
      apiClient: client,
    );
    expect(
      () => service.receiveShipment(
        1,
        ReceiveLaundryShipmentRequest(
          receivedAt: DateTime.utc(2026),
          version: 0,
          lines: const <ReceiveLaundryLineRequest>[],
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test('crea y edita artículos con el mismo contrato tipado', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":6,"name":"Alfombra de baño","unitType":"PIECE","currentUnitPrice":9.0,"active":true}',
      ),
    );
    final HttpLaundryAppService service = HttpLaundryAppService(
      apiClient: client,
    );
    const LaundryItem item = LaundryItem(
      id: 6,
      name: 'Alfombra de baño',
      unitType: LaundryUnitType.piece,
      currentUnitPrice: 9,
      active: true,
    );

    await service.createItem(item);
    expect(client.lastMethod, 'POST');
    expect(client.lastPath, 'laundry/items');
    expect(jsonDecode(client.lastBody!)['unitType'], 'PIECE');
    expect(jsonDecode(client.lastBody!).containsKey('id'), isFalse);

    final LaundryItem updated = await service.updateItem(6, item);
    expect(client.lastMethod, 'PUT');
    expect(client.lastPath, 'laundry/items/6');
    expect(updated.currentUnitPrice, 9);
  });

  test('confirma el envío posterior del relavado', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":3,"shipmentNumber":"LAV-R3","providerId":1,"providerName":"Aguas Claras","kind":"REWASH","status":"SENT","sentAt":"2026-10-30T21:00:00Z","version":1,"totalQuantity":2,"billableAmount":0,"lines":[]}',
      ),
    );
    await HttpLaundryAppService(apiClient: client).dispatchShipment(
      3,
      DispatchLaundryShipmentRequest(
        sentAt: DateTime.parse('2026-10-30T18:00:00-03:00'),
        version: 0,
      ),
    );
    expect(client.lastMethod, 'POST');
    expect(client.lastPath, 'laundry/shipments/3/dispatch');
    expect(jsonDecode(client.lastBody!)['version'], 0);
  });
  test('crea y edita proveedores con estado activo', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":8,"name":"Lavanderia Norte","contact":"11999990000","active":false}',
      ),
    );
    final HttpLaundryAppService service = HttpLaundryAppService(
      apiClient: client,
    );
    const CreateLaundryProviderRequest request = CreateLaundryProviderRequest(
      name: 'Lavanderia Norte',
      contact: '11999990000',
      active: false,
    );

    await service.createProvider(request);
    expect(client.lastMethod, 'POST');
    expect(client.lastPath, 'laundry/providers');
    expect(jsonDecode(client.lastBody!)['active'], isFalse);

    final LaundryProvider updated = await service.updateProvider(8, request);
    expect(client.lastMethod, 'PUT');
    expect(client.lastPath, 'laundry/providers/8');
    expect(updated.active, isFalse);
  });
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.response);
  final ApiResponse response;
  String? lastPath;
  String? lastMethod;
  String? lastBody;
  Future<ApiResponse> _answer(
    String method,
    String path, [
    String? body,
  ]) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    return response;
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) =>
      _answer('GET', path);
  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => _answer('POST', path, body);
  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => _answer('PUT', path, body);
  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => _answer('PATCH', path, body);
  @override
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) =>
      _answer('DELETE', path);
}
