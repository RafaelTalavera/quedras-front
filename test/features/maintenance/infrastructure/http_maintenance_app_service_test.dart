import 'dart:io';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:costanorte/features/maintenance/infrastructure/http_maintenance_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'HttpMaintenanceAppService lista locais e ordens com contrato novo',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '[{"id":1,"locationType":"ROOM","locationCategory":"CHALET","code":"CH-01","label":"Chalet 1","floor":null,"description":"Unidade externa","active":true,"createdAt":"2026-04-01T10:00:00Z","updatedAt":"2026-04-01T10:00:00Z","createdBy":"system","updatedBy":"system"}]',
          ),
        )
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '[{"id":10,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"CH-01","locationLabelSnapshot":"Chalet 1","providerId":2,"providerTypeSnapshot":"INTERNAL","providerNameSnapshot":"Equipe interna","serviceLabelSnapshot":"Manutencao geral","title":"Revisar fechadura","description":"A fechadura esta presa","priority":"HIGH","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"guestName":null,"requestedByUsername":"operador.demo","requestedByRole":"OPERATOR","estimatedExecutionMinutes":90,"assignedUsername":"operador.demo","assignedAt":"2026-04-05T08:10:00Z","status":"IN_PROGRESS","reportedAt":"2026-04-05T08:00:00Z","expectedCompletionAt":"2026-04-05T09:30:00Z","scheduledStartAt":"2026-04-05T08:00:00","scheduledEndAt":"2026-04-05T09:30:00","startedAt":"2026-04-05T08:05:00Z","completedAt":null,"resolutionNotes":null,"cancellationNotes":null,"attachments":[],"createdAt":"2026-04-05T08:00:00Z","updatedAt":"2026-04-05T08:05:00Z","cancelledAt":null,"createdBy":"operador.demo","updatedBy":"operador.demo","cancelledBy":null}]',
          ),
        );
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final List<MaintenanceLocation> locations = await service.listLocations();
      final List<MaintenanceOrder> orders = await service.listOrders(
        dateFrom: '2026-04-05',
        dateTo: '2026-04-05',
      );

      expect(
        locations.single.locationCategory,
        MaintenanceLocationCategory.chalet,
      );
      expect(orders.single.expectedCompletionAt, isNotNull);
      expect(orders.single.status, MaintenanceOrderStatus.inProgress);
      expect(client.calls.first.path, 'maintenance/locations');
      expect(
        client.calls.last.path,
        'maintenance/orders?dateFrom=2026-04-05&dateTo=2026-04-05',
      );
    },
  );

  test(
    'HttpMaintenanceAppService carrega resumo executivo diario com pendencias anteriores',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '{"carryOverOpenCount":1,"dayOpenCount":1,"totalOpenCount":2,"urgentCount":1,"scheduledCount":2,"inProgressCount":0,"unassignedCount":1,"carryOverOrders":[{"id":10,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"301","locationLabelSnapshot":"Apartamento 301","providerId":2,"providerTypeSnapshot":"INTERNAL","providerNameSnapshot":"Equipe interna","serviceLabelSnapshot":"Banho","title":"Revisar ducha","description":"Pendencia del dia anterior","priority":"URGENT","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"guestName":null,"requestedByUsername":"operador.demo","requestedByRole":"OPERATOR","estimatedExecutionMinutes":60,"assignedUsername":"operador.demo","assignedAt":"2026-04-02T18:10:00Z","status":"SCHEDULED","reportedAt":"2026-04-02T18:00:00Z","expectedCompletionAt":"2026-04-02T19:00:00Z","scheduledStartAt":"2026-04-02T18:00:00","scheduledEndAt":"2026-04-02T19:00:00","startedAt":null,"completedAt":null,"resolutionNotes":null,"cancellationNotes":null,"attachments":[],"createdAt":"2026-04-02T18:00:00Z","updatedAt":"2026-04-02T18:00:00Z","cancelledAt":null,"createdBy":"operador.demo","updatedBy":"operador.demo","cancelledBy":null}],"dayOpenOrders":[{"id":11,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"301","locationLabelSnapshot":"Apartamento 301","providerId":null,"providerTypeSnapshot":null,"providerNameSnapshot":null,"serviceLabelSnapshot":"Iluminacao","title":"Trocar lampada","description":"Solicitado na manha","priority":"MEDIUM","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"guestName":null,"requestedByUsername":"operador.demo","requestedByRole":"OPERATOR","estimatedExecutionMinutes":30,"assignedUsername":null,"assignedAt":null,"status":"SCHEDULED","reportedAt":"2026-04-03T09:00:00Z","expectedCompletionAt":"2026-04-03T10:00:00Z","scheduledStartAt":"2026-04-03T09:00:00","scheduledEndAt":"2026-04-03T10:00:00","startedAt":null,"completedAt":null,"resolutionNotes":null,"cancellationNotes":null,"attachments":[],"createdAt":"2026-04-03T09:00:00Z","updatedAt":"2026-04-03T09:00:00Z","cancelledAt":null,"createdBy":"operador.demo","updatedBy":"operador.demo","cancelledBy":null}]}',
          ),
        );
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final MaintenanceDailyExecutiveReport report = await service
          .getDailyExecutiveReport(date: '2026-04-03');

      expect(report.carryOverOpenCount, 1);
      expect(report.dayOpenCount, 1);
      expect(report.totalOpenCount, 2);
      expect(report.carryOverOrders.single.title, 'Revisar ducha');
      expect(report.dayOpenOrders.single.providerId, isNull);
      expect(
        client.calls.single.path,
        'maintenance/reports/summary/daily-executive?date=2026-04-03',
      );
    },
  );

  test(
    'HttpMaintenanceAppService envia categoria ao criar e atualizar local',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 201,
            body:
                '{"id":1,"locationType":"ROOM","locationCategory":"APARTMENT","code":"101","label":"Apartamento 101","floor":"1","description":"Suite","active":true,"createdAt":"2026-04-01T10:00:00Z","updatedAt":"2026-04-01T10:00:00Z","createdBy":"system","updatedBy":"system"}',
          ),
        )
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '{"id":1,"locationType":"ROOM","locationCategory":"CHALET","code":"CH-02","label":"Chalet 2","floor":null,"description":"Unidade externa","active":true,"createdAt":"2026-04-01T10:00:00Z","updatedAt":"2026-04-01T11:00:00Z","createdBy":"system","updatedBy":"system"}',
          ),
        );
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final MaintenanceLocation created = await service.createLocation(
        const CreateMaintenanceLocationModel(
          locationType: MaintenanceLocationType.room,
          locationCategory: MaintenanceLocationCategory.apartment,
          code: '101',
          label: 'Apartamento 101',
          floor: '1',
          description: 'Suite',
          active: true,
        ),
      );
      final MaintenanceLocation updated = await service.updateLocation(
        1,
        const UpdateMaintenanceLocationModel(
          locationType: MaintenanceLocationType.room,
          locationCategory: MaintenanceLocationCategory.chalet,
          code: 'CH-02',
          label: 'Chalet 2',
          floor: null,
          description: 'Unidade externa',
          active: true,
        ),
      );

      expect(created.locationCategory, MaintenanceLocationCategory.apartment);
      expect(updated.locationCategory, MaintenanceLocationCategory.chalet);
      expect(
        client.calls.first.body,
        '{"locationType":"ROOM","locationCategory":"APARTMENT","code":"101","label":"Apartamento 101","floor":"1","description":"Suite","active":true}',
      );
      expect(
        client.calls.last.body,
        '{"locationType":"ROOM","locationCategory":"CHALET","code":"CH-02","label":"Chalet 2","floor":null,"description":"Unidade externa","active":true}',
      );
    },
  );

  test(
    'HttpMaintenanceAppService preserva referencia interna vazia para geracao no backend',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 201,
            body:
                '{"id":2,"locationType":"ROOM","locationCategory":"APARTMENT","code":"LOC-APARTAMENTO-305","label":"Apartamento 305","floor":"3","description":null,"active":true,"createdAt":"2026-04-01T10:00:00Z","updatedAt":"2026-04-01T10:00:00Z","createdBy":"system","updatedBy":"system"}',
          ),
        );
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final MaintenanceLocation created = await service.createLocation(
        const CreateMaintenanceLocationModel(
          locationType: MaintenanceLocationType.room,
          locationCategory: MaintenanceLocationCategory.apartment,
          code: '',
          label: 'Apartamento 305',
          floor: '3',
          description: null,
          active: true,
        ),
      );

      expect(created.code, 'LOC-APARTAMENTO-305');
      expect(
        client.calls.single.body,
        '{"locationType":"ROOM","locationCategory":"APARTMENT","code":"","label":"Apartamento 305","floor":"3","description":null,"active":true}',
      );
    },
  );

  test('HttpMaintenanceAppService traduz falha de rede', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..nextError = const SocketException('Connection refused');
    final HttpMaintenanceAppService service = HttpMaintenanceAppService(
      apiClient: client,
    );

    await expectLater(
      () => service.listLocations(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.message,
          'message',
          'Nao foi possivel conectar ao backend configurado. Verifique a URL e a conectividade.',
        ),
      ),
    );
  });

  test(
    'HttpMaintenanceAppService aceita payload paginado e texto puro de erro',
    () async {
      final _FakeApiClient pagedClient = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '{"content":[{"id":10,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"CH-01","locationLabelSnapshot":"Chalet 1","providerId":2,"providerTypeSnapshot":"INTERNAL","providerNameSnapshot":"Equipe interna","serviceLabelSnapshot":"Manutencao geral","title":"Revisar fechadura","description":"A fechadura esta presa","priority":"HIGH","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"guestName":null,"requestedByUsername":"operador.demo","requestedByRole":"OPERATOR","estimatedExecutionMinutes":90,"assignedUsername":"operador.demo","assignedAt":"2026-04-05T08:10:00Z","status":"IN_PROGRESS","reportedAt":"2026-04-05T08:00:00Z","expectedCompletionAt":"2026-04-05T09:30:00Z","scheduledStartAt":"2026-04-05T08:00:00","scheduledEndAt":"2026-04-05T09:30:00","startedAt":"2026-04-05T08:05:00Z","completedAt":null,"resolutionNotes":null,"cancellationNotes":null,"attachments":[],"createdAt":"2026-04-05T08:00:00Z","updatedAt":"2026-04-05T08:05:00Z","cancelledAt":null,"createdBy":"operador.demo","updatedBy":"operador.demo","cancelledBy":null}],"totalElements":1,"totalPages":1,"number":0,"size":20}',
          ),
        );
      final HttpMaintenanceAppService pagedService = HttpMaintenanceAppService(
        apiClient: pagedClient,
      );

      final List<MaintenanceOrder> orders = await pagedService.listOrders(
        dateFrom: '2026-04-05',
        dateTo: '2026-04-05',
      );

      expect(orders, hasLength(1));
      expect(orders.single.id, 10);

      final _FakeApiClient plainTextErrorClient = _FakeApiClient()
        ..enqueue(const ApiResponse(statusCode: 500, body: 'backend exploded'));
      final HttpMaintenanceAppService plainTextErrorService =
          HttpMaintenanceAppService(apiClient: plainTextErrorClient);

      await expectLater(
        () => plainTextErrorService.listOrders(),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException error) => error.message,
                'message',
                'backend exploded',
              )
              .having(
                (ApiException error) => error.statusCode,
                'statusCode',
                500,
              ),
        ),
      );
    },
  );
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
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) {
    return _consume('DELETE', path, body: null);
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
