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

  test(
    'HttpMaintenanceAppService atualiza telefone do responsavel com resposta autoritativa',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '{"id":5,"providerType":"EXTERNAL","specialty":"AIR_CONDITIONING","name":"Servico de ar","serviceLabel":"Ar-condicionado","scopeDescription":"Hotel","contact":"5548999998888","whatsappNumber":"5548999998888","whatsappEnabled":true,"active":true,"createdAt":"2026-04-01T10:00:00Z","updatedAt":"2026-08-19T18:00:00Z","createdBy":"system","updatedBy":"supervisor.demo"}',
          ),
        );
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final MaintenanceProvider updated = await service.updateProvider(
        5,
        const UpdateMaintenanceProviderModel(
          providerType: MaintenanceProviderType.external,
          specialty: MaintenanceProviderSpecialty.airConditioning,
          name: 'Servico de ar',
          serviceLabel: 'Ar-condicionado',
          scopeDescription: 'Hotel',
          contact: '5548999998888',
          active: true,
          whatsappNumber: '5548999998888',
          whatsappEnabled: true,
        ),
      );

      expect(updated.whatsappNumber, '5548999998888');
      expect(updated.whatsappEnabled, isTrue);
      expect(client.calls.single.method, 'PUT');
      expect(client.calls.single.path, 'maintenance/providers/5');
      expect(client.calls.single.body, contains('"contact":"5548999998888"'));
      expect(
        client.calls.single.body,
        contains('"whatsappNumber":"5548999998888"'),
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

  test('HttpMaintenanceAppService exclui local e responsavel', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(const ApiResponse(statusCode: 204, body: ''))
      ..enqueue(const ApiResponse(statusCode: 204, body: ''));
    final HttpMaintenanceAppService service = HttpMaintenanceAppService(
      apiClient: client,
    );

    await service.deleteLocation(12);
    await service.deleteProvider(34);

    expect(client.calls, hasLength(2));
    expect(client.calls[0].method, 'DELETE');
    expect(client.calls[0].path, 'maintenance/locations/12');
    expect(client.calls[1].method, 'DELETE');
    expect(client.calls[1].path, 'maintenance/providers/34');
  });

  test('HttpMaintenanceAppService reagenda con version de agenda', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"id":10,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"208","locationLabelSnapshot":"Habitacion 208","providerId":2,"providerTypeSnapshot":"INTERNAL","providerNameSnapshot":"Equipo interno","serviceLabelSnapshot":"Mantenimiento general","orderKind":"CORRECTIVE","title":"Revisar cerradura","description":null,"priority":"MEDIUM","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"status":"SCHEDULED","reportedAt":"2026-04-10T09:00:00Z","scheduledStartAt":"2026-04-10T12:00:00","scheduledEndAt":"2026-04-10T13:30:00","scheduleVersion":2,"attachments":[]}',
        ),
      );
    final HttpMaintenanceAppService service = HttpMaintenanceAppService(
      apiClient: client,
    );

    final MaintenanceOrder order = await service.rescheduleOrder(
      10,
      const RescheduleMaintenanceOrderModel(
        scheduledStartAt: '2026-04-10T12:00:00',
        scheduledEndAt: '2026-04-10T13:30:00',
        reason: ' Cambio de disponibilidad ',
        expectedScheduleVersion: 1,
      ),
    );

    expect(order.scheduleVersion, 2);
    expect(client.calls.single.method, 'PATCH');
    expect(client.calls.single.path, 'maintenance/orders/10/reschedule');
    expect(
      client.calls.single.body,
      '{"scheduledStartAt":"2026-04-10T12:00:00","scheduledEndAt":"2026-04-10T13:30:00","reason":"Cambio de disponibilidad","expectedScheduleVersion":1}',
    );
  });

  test('HttpMaintenanceAppService consulta agenda e backlog por rango', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"rangeStart":"2026-05-01T00:00:00","rangeEndExclusive":"2026-05-08T00:00:00","scheduledOrders":[{"id":10,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"209","locationLabelSnapshot":"Habitacion 209","orderKind":"CORRECTIVE","title":"Revision nocturna","priority":"MEDIUM","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"status":"SCHEDULED","reportedAt":"2026-04-30T20:00:00Z","scheduledStartAt":"2026-04-30T23:00:00","scheduledEndAt":"2026-05-01T02:00:00","scheduleVersion":1,"attachments":[]}],"backlogOrders":[{"id":11,"locationId":1,"locationTypeSnapshot":"ROOM","locationCodeSnapshot":"209","locationLabelSnapshot":"Habitacion 209","orderKind":"CORRECTIVE","title":"Reparacion pendiente","priority":"HIGH","requestOrigin":"INTERNAL_ROLE","requestedForGuest":false,"status":"OPEN","reportedAt":"2026-04-30T21:00:00Z","scheduleVersion":0,"attachments":[]}],"backlogHasMore":true}',
        ),
      );
    final HttpMaintenanceAppService service = HttpMaintenanceAppService(
      apiClient: client,
    );

    final MaintenanceCalendar calendar = await service.getCalendar(
      rangeStart: '2026-05-01T00:00:00',
      rangeEndExclusive: '2026-05-08T00:00:00',
      priority: MaintenancePriority.high,
      backlogSize: 25,
    );

    expect(calendar.scheduledOrders.single.id, 10);
    expect(calendar.backlogOrders.single.id, 11);
    expect(calendar.backlogHasMore, isTrue);
    expect(
      client.calls.single.path,
      'maintenance/orders/calendar?rangeStart=2026-05-01T00%3A00%3A00&rangeEndExclusive=2026-05-08T00%3A00%3A00&priority=HIGH&backlogSize=25',
    );
  });

  test(
    'HttpMaintenanceAppService consume bandeja e acoes de notificacao',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 200,
            body:
                '{"page":0,"size":20,"hasNext":false,"items":[{"id":7,"orderId":10,"notificationType":"OVERDUE","status":"UNREAD","title":"Manutencao atrasada","body":"Habitacion 209 - Revision nocturna","dueAt":"2026-05-01T02:00:00-03:00","readAt":null,"resolvedAt":null,"dismissedAt":null,"createdAt":"2026-05-01T02:01:00-03:00"}]}',
          ),
        )
        ..enqueue(const ApiResponse(statusCode: 200, body: '{"count":1}'))
        ..enqueue(const ApiResponse(statusCode: 204, body: ''))
        ..enqueue(const ApiResponse(statusCode: 204, body: ''));
      final HttpMaintenanceAppService service = HttpMaintenanceAppService(
        apiClient: client,
      );

      final MaintenanceNotificationPage page = await service.listNotifications(
        status: MaintenanceNotificationStatus.unread,
      );
      final int count = await service.getUnreadNotificationCount();
      await service.markNotificationRead(7);
      await service.dismissNotification(7);

      expect(page.items.single.orderId, 10);
      expect(
        page.items.single.notificationType,
        MaintenanceNotificationType.overdue,
      );
      expect(count, 1);
      expect(
        client.calls[0].path,
        'notifications?module=maintenance&status=UNREAD&page=0&size=20',
      );
      expect(
        client.calls[1].path,
        'notifications/unread-count?module=maintenance',
      );
      expect(client.calls[2].method, 'PATCH');
      expect(client.calls[2].path, 'notifications/7/read');
      expect(client.calls[3].path, 'notifications/7/dismiss');
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
