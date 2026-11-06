import 'dart:convert';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/features/laundry/domain/hotel_laundry_models.dart';
import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:costanorte/features/laundry/infrastructure/http_hotel_laundry_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consulta catalogos por V2', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body: '[{"id":3,"name":"Lavanderia","contact":null,"active":true}]',
      ),
    );

    final providers = await HttpHotelLaundryAppService(
      apiClient: client,
    ).listProviders();

    expect(client.path, 'providers');
    expect(providers.single.name, 'Lavanderia');
  });

  test('consulta tablero V2 filtrado por proveedor', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"providerId":3,"totals":{"hotelAvailable":8,"hotelRewashQueue":1,"providerProcessing":4,"providerRewash":2,"missing":1,"damaged":0,"total":16},"items":[]}',
      ),
    );

    final totals = await HttpHotelLaundryAppService(
      apiClient: client,
    ).dashboard(providerId: 3);

    expect(client.path, 'dashboard?providerId=3');
    expect(totals.providerProcessing, 4);
    expect(totals.total, 16);
  });

  test('consulta bandeja V2 del hotel con filtros y proveedor', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"page":0,"size":20,"hasNext":false,"items":[{"id":11,"reference":"ENV-11","documentType":"STANDARD_DISPATCH","status":"SUBMITTED","providerId":3,"providerName":"Lavanderia","effectiveAt":"2026-11-03T10:00:00Z","submittedAt":"2026-11-03T10:05:00Z","version":1}]}',
      ),
    );

    final page = await HttpHotelLaundryAppService(apiClient: client)
        .listDocuments(
          providerId: 3,
          status: 'SUBMITTED',
          documentType: 'STANDARD_DISPATCH',
        );

    expect(
      client.path,
      'documents?providerId=3&status=SUBMITTED&type=STANDARD_DISPATCH&page=0&size=20',
    );
    expect(page.items.single.providerName, 'Lavanderia');
    expect(page.items.single.version, 1);
  });

  test('crea despacho V2 con fecha UTC e idempotencia', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 201,
        body:
            '{"id":11,"reference":"ENV-11","documentType":"STANDARD_DISPATCH","status":"DRAFT","providerId":3,"providerName":"Lavanderia","effectiveAt":"2026-11-03T10:00:00Z","submittedAt":null,"version":0,"lines":[]}',
      ),
    );

    final result = await HttpHotelLaundryAppService(apiClient: client)
        .createDispatch(
          rewash: false,
          input: HotelLaundryDispatchInput(
            version: 0,
            providerId: 3,
            effectiveAt: DateTime.parse('2026-11-03T07:00:00-03:00'),
            notes: ' Envio ',
            lines: const <HotelLaundryDispatchLineInput>[
              HotelLaundryDispatchLineInput(itemId: 8, quantity: 5),
            ],
          ),
        );

    final Map<String, dynamic> body =
        jsonDecode(client.body!) as Map<String, dynamic>;
    expect(client.method, 'POST');
    expect(client.path, 'dispatches');
    expect(client.headers?['Idempotency-Key'], startsWith('flutter-hotel-'));
    expect(body['effectiveAt'], '2026-11-03T10:00:00.000Z');
    expect(body['notes'], 'Envio');
    expect(result.status, 'DRAFT');
  });

  test('registra estoque inicial con idempotencia', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 201,
        body: '{"id":1,"reference":"OPEN-1","status":"APPROVED","lines":[]}',
      ),
    );

    await HttpHotelLaundryAppService(apiClient: client).createOpeningStock(
      HotelLaundryOpeningStockInput(
        version: 0,
        effectiveAt: DateTime.parse('2026-11-03T07:00:00-03:00'),
        notes: ' Estoque conferido ',
        lines: const <HotelLaundryDispatchLineInput>[
          HotelLaundryDispatchLineInput(itemId: 8, quantity: 12),
        ],
      ),
    );

    final Map<String, dynamic> body =
        jsonDecode(client.body!) as Map<String, dynamic>;
    expect(client.path, 'opening-stock');
    expect(client.headers?['Idempotency-Key'], startsWith('flutter-hotel-'));
    expect(body['effectiveAt'], '2026-11-03T10:00:00.000Z');
    expect(body['notes'], 'Estoque conferido');
    expect((body['lines'] as List<dynamic>).single['quantity'], 12.0);
  });

  test('consulta trazabilidad de inventario por fecha', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '[{"id":4,"effectiveAt":"2026-11-03T10:00:00Z","itemId":8,"itemName":"Toalha","quantity":12,"movementType":"OPENING_STOCK","notes":"Conteo","createdAt":"2026-11-03T11:00:00Z","createdBy":"admin"}]',
      ),
    );

    final movements = await HttpHotelLaundryAppService(
      apiClient: client,
    ).listInventoryMovements(date: DateTime(2026, 11, 3));

    expect(client.path, 'inventory/movements?date=2026-11-03');
    expect(movements.single.createdBy, 'admin');
    expect(movements.single.movementType, 'OPENING_STOCK');
  });

  test('retira inventario y da de baja producto con idempotencia', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(statusCode: 200, body: '{}'),
    );

    await HttpHotelLaundryAppService(apiClient: client).retireInventoryItem(
      HotelLaundryItemRetirementInput(
        itemId: 8,
        version: 3,
        effectiveAt: DateTime.parse('2026-11-03T07:00:00-03:00'),
        quantity: 5,
        notes: 'Producto fuera de uso',
      ),
    );

    final Map<String, dynamic> body =
        jsonDecode(client.body!) as Map<String, dynamic>;
    expect(client.path, 'inventory/items/8/retire');
    expect(client.headers?['Idempotency-Key'], startsWith('flutter-hotel-'));
    expect(body['version'], 3);
    expect(body['quantity'], 5.0);
    expect(body['notes'], 'Producto fuera de uso');
  });

  test('consulta saldo disponible con su version para dar de baja', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"page":0,"size":1,"hasNext":false,"items":[{"balanceId":4,"itemId":8,"itemName":"Toalha","unitType":"PIECE","bucket":"HOTEL_AVAILABLE","providerId":null,"providerName":null,"quantity":100,"oldestEffectiveAt":"2026-11-01T10:00:00Z","ageDays":4,"version":3}]}',
      ),
    );

    final HotelLaundryStockRow? stock = await HttpHotelLaundryAppService(
      apiClient: client,
    ).getAvailableStock(itemId: 8);

    expect(client.path, 'stock?itemId=8&bucket=HOTEL_AVAILABLE&page=0&size=1');
    expect(stock?.quantity, 100);
    expect(stock?.version, 3);
  });

  test('confirma devolucion V2 con clasificacion completa', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":7,"reference":"DEV-7","status":"CONFIRMED","providerId":3,"providerName":"Lavanderia","effectiveAt":"2026-11-04T10:00:00Z","notes":null,"submittedAt":"2026-11-04T10:05:00Z","confirmedAt":"2026-11-04T10:10:00Z","correctionNotes":null,"version":2,"lines":[{"id":2,"itemId":8,"itemName":"Toalha","declaredClean":3,"declaredRetained":1,"acceptedClean":2,"returnedDirty":1,"retained":1,"missing":0,"damaged":0}]}',
      ),
    );

    final result = await HttpHotelLaundryAppService(apiClient: client)
        .confirmReturn(
          id: 7,
          input: const HotelLaundryReturnConfirmationInput(
            version: 1,
            lines: <HotelLaundryReturnClassificationInput>[
              HotelLaundryReturnClassificationInput(
                itemId: 8,
                acceptedClean: 2,
                returnedDirty: 1,
                retained: 1,
                missing: 0,
                damaged: 0,
              ),
            ],
          ),
        );

    expect(client.path, 'returns/7/confirm');
    expect(client.headers?['Idempotency-Key'], isNotEmpty);
    expect(result.status, 'CONFIRMED');
    expect(result.lines.single.returnedDirty, 1);
  });

  test('crea y actualiza lavanderias por V2', () async {
    final _FakeApiClient client = _FakeApiClient(
      const ApiResponse(
        statusCode: 200,
        body:
            '{"id":9,"name":"Lavanderia Norte","contact":"11999990000","active":false}',
      ),
    );
    final HttpHotelLaundryAppService service = HttpHotelLaundryAppService(
      apiClient: client,
    );
    const CreateLaundryProviderRequest request = CreateLaundryProviderRequest(
      name: 'Lavanderia Norte',
      contact: '11999990000',
      active: false,
    );
    await service.createProvider(request);
    expect(client.method, 'POST');
    expect(client.path, 'providers');
    expect(jsonDecode(client.body!)['active'], isFalse);

    final LaundryProvider updated = await service.updateProvider(9, request);
    expect(client.method, 'PUT');
    expect(client.path, 'providers/9');
    expect(updated.active, isFalse);
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
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) =>
      throw UnimplementedError();
  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) => throw UnimplementedError();
  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    method = 'PUT';
    this.path = path;
    this.headers = headers;
    this.body = body;
    return response;
  }
}
