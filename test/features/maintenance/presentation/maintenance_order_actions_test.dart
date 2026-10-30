import 'package:costanorte/core/sync/schedule_sync_service.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/maintenance/application/maintenance_app_service.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:costanorte/features/maintenance/presentation/maintenance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra agenda semanal y backlog de mantenimiento', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);

    expect(find.text('Agenda semanal de manutencao'), findsOneWidget);
    expect(find.text('Backlog sem agenda (0)'), findsOneWidget);
    expect(find.byTooltip('Periodo anterior'), findsOneWidget);
    expect(find.byTooltip('Proximo periodo'), findsOneWidget);
  });

  testWidgets('consulta intervalos diario y mensual segun el modo visible', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);
    expect(service.calendarRangeDays, 7);

    await tester.tap(find.text('Dia'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda diaria de manutencao'), findsOneWidget);
    expect(service.calendarRangeDays, 1);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda mensal de manutencao'), findsOneWidget);
    expect(service.calendarRangeDays, inInclusiveRange(28, 31));
  });

  testWidgets('envia filtros de local estado y prioridad al calendario', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);
    await tester.ensureVisible(find.byType(DropdownButton<int>).first);
    await tester.tap(find.byType(DropdownButton<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('101 - Quarto 101').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prestador teste').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendada').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urgente').last);
    await tester.pumpAndSettle();

    expect(service.calendarLocationId, 1);
    expect(service.calendarProviderId, 55);
    expect(service.calendarStatus, MaintenanceOrderStatus.scheduled);
    expect(service.calendarPriority, MaintenancePriority.urgent);
  });

  testWidgets('doble clic en Sem ordens abre crear orden para ese local', (
    WidgetTester tester,
  ) async {
    final _EmptyLocationService service = _EmptyLocationService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);

    await tester.ensureVisible(find.text('101').first);
    await tester.tap(find.text('101').first);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('101').first);
    await tester.pumpAndSettle();
    expect(find.text('Criar ordem - Quarto 101'), findsOneWidget);
    final Finder generalChoice = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('General'),
    );
    expect(generalChoice, findsOneWidget);

    await tester.tap(generalChoice);
    await tester.pumpAndSettle();

    expect(find.text('Nova ordem'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '101'), findsOneWidget);
  });

  testWidgets('inicia una orden arrastrada desde Estado das ordens', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);

    await tester.tap(find.text('Estado das ordens').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.order.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.startedOrderIds, <int>[service.order.id]);
  });

  testWidgets('agenda una orden con motivo y version esperada', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);
    await tester.tap(find.text('Estado das ordens').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.order.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo da alteracao'),
      'Ajuste solicitado pela operacao',
    );
    await tester.tap(find.text('Confirmar reagendamento'));
    await tester.pumpAndSettle();

    expect(service.rescheduledOrderIds, <int>[service.order.id]);
    expect(
      service.rescheduleInputs.single.reason,
      'Ajuste solicitado pela operacao',
    );
    expect(
      service.rescheduleInputs.single.expectedScheduleVersion,
      service.order.scheduleVersion,
    );
    expect(find.text('Agenda atualizada'), findsOneWidget);
  });

  testWidgets('recarga la agenda y avisa cuando reagendar devuelve 409', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService()
      ..simulateScheduleConflict = true;
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);
    await tester.tap(find.text('Estado das ordens').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.order.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo da alteracao'),
      'Ajuste concorrente',
    );
    await tester.tap(find.text('Confirmar reagendamento'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda alterada por outro usuario'), findsOneWidget);
  });

  testWidgets('inicia una orden arrastrada desde el mapa operacional', (
    WidgetTester tester,
  ) async {
    final _CarryOverOrderService service = _CarryOverOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);

    await tester.ensureVisible(find.text('101').first);
    await tester.tap(find.text('101').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.order.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.startedOrderIds, <int>[service.order.id]);
  });

  testWidgets('mapa operacional incluye ordenes visibles en backlog', (
    WidgetTester tester,
  ) async {
    final _BacklogOnlyOrderService service = _BacklogOnlyOrderService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(tester, service, syncService);

    await tester.ensureVisible(find.text('101').first);
    expect(find.text('2 abertas'), findsOneWidget);
  });

  testWidgets('aviso de fin permite concluir o reagendar la orden', (
    WidgetTester tester,
  ) async {
    final _OverdueOrderService service = _OverdueOrderService();
    final MaintenancePageController controller = MaintenancePageController();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

    await _pumpMaintenancePage(
      tester,
      service,
      syncService,
      controller: controller,
    );
    final Future<bool> opening = controller.openOrderFromNotification(
      service.overdueOrder.id,
      service.overdueOrder.scheduledEndAt!,
      notificationType: MaintenanceNotificationType.overdue,
    );
    await tester.pumpAndSettle();

    expect(find.text('Horario previsto encerrado'), findsOneWidget);
    expect(find.text('Reagendar'), findsOneWidget);
    final OutlinedButton completeButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Concluir'),
    );
    expect(completeButton.onPressed, isNotNull);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(await opening, isTrue);
  });
}

Future<void> _pumpMaintenancePage(
  WidgetTester tester,
  _CarryOverOrderService service,
  ScheduleSyncService syncService, {
  MaintenancePageController? controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MaintenancePage(
          maintenanceAppService: service,
          scheduleSyncService: syncService,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CarryOverOrderService extends Fake implements MaintenanceAppService {
  late final MaintenanceOrder order =
      MaintenanceOrder.fromJson(<String, dynamic>{
        'id': 87,
        'locationId': 1,
        'locationTypeSnapshot': 'ROOM',
        'locationCodeSnapshot': '101',
        'locationLabelSnapshot': 'Quarto 101',
        'title': 'Pendencia arrastrada',
        'status': 'SCHEDULED',
        'requestOrigin': 'INTERNAL_ROLE',
        'reportedAt': '2026-09-20T08:00:00Z',
      });
  final List<int> startedOrderIds = <int>[];
  final List<int> rescheduledOrderIds = <int>[];
  final List<RescheduleMaintenanceOrderModel> rescheduleInputs =
      <RescheduleMaintenanceOrderModel>[];
  bool simulateScheduleConflict = false;
  DateTime? calendarRangeStart;
  DateTime? calendarRangeEndExclusive;
  int? calendarLocationId;
  int? calendarProviderId;
  MaintenanceOrderStatus? calendarStatus;
  MaintenancePriority? calendarPriority;

  int get calendarRangeDays =>
      calendarRangeEndExclusive!.difference(calendarRangeStart!).inDays;

  @override
  Future<List<MaintenanceLocation>> listLocations() async =>
      <MaintenanceLocation>[
        MaintenanceLocation.fromJson(<String, dynamic>{
          'id': 1,
          'locationType': 'ROOM',
          'locationCategory': 'APARTMENT',
          'code': '101',
          'label': 'Quarto 101',
          'active': true,
        }),
      ];

  @override
  Future<List<MaintenanceOrder>> listOrders({
    String? dateFrom,
    String? dateTo,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
  }) async => const <MaintenanceOrder>[];

  @override
  Future<MaintenanceCalendar> getCalendar({
    required String rangeStart,
    required String rangeEndExclusive,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
    int? backlogSize,
  }) async {
    calendarRangeStart = DateTime.parse(rangeStart);
    calendarRangeEndExclusive = DateTime.parse(rangeEndExclusive);
    calendarLocationId = locationId;
    calendarProviderId = providerId;
    calendarStatus = status;
    calendarPriority = priority;
    return MaintenanceCalendar(
      rangeStart: calendarRangeStart!,
      rangeEndExclusive: calendarRangeEndExclusive!,
      scheduledOrders: <MaintenanceOrder>[order],
      backlogOrders: const <MaintenanceOrder>[],
      backlogHasMore: false,
    );
  }

  @override
  Future<List<MaintenanceProvider>> listProviders() async =>
      <MaintenanceProvider>[
        MaintenanceProvider.fromJson(<String, dynamic>{
          'id': 55,
          'providerType': 'EXTERNAL',
          'specialty': 'GENERAL',
          'name': 'Prestador teste',
          'serviceLabel': 'Manutencao geral',
          'active': true,
        }),
      ];

  @override
  Future<MaintenanceDailyExecutiveReport> getDailyExecutiveReport({
    required String date,
  }) async => MaintenanceDailyExecutiveReport(
    carryOverOpenCount: 1,
    dayOpenCount: 0,
    totalOpenCount: 1,
    urgentCount: 0,
    scheduledCount: 1,
    inProgressCount: 0,
    unassignedCount: 0,
    carryOverOrders: <MaintenanceOrder>[order],
    dayOpenOrders: const <MaintenanceOrder>[],
  );

  @override
  Future<MaintenanceOrder> startOrder(
    int orderId, {
    StartMaintenanceOrderModel? input,
  }) async {
    startedOrderIds.add(orderId);
    return order;
  }

  @override
  Future<MaintenanceOrder> rescheduleOrder(
    int orderId,
    RescheduleMaintenanceOrderModel input,
  ) async {
    rescheduledOrderIds.add(orderId);
    rescheduleInputs.add(input);
    if (simulateScheduleConflict) {
      throw const ApiException(
        'Agenda desatualizada.',
        kind: ApiErrorKind.http,
        statusCode: 409,
      );
    }
    return order;
  }
}

class _EmptyLocationService extends _CarryOverOrderService {
  @override
  Future<MaintenanceCalendar> getCalendar({
    required String rangeStart,
    required String rangeEndExclusive,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
    int? backlogSize,
  }) async => MaintenanceCalendar(
    rangeStart: DateTime.parse(rangeStart),
    rangeEndExclusive: DateTime.parse(rangeEndExclusive),
    scheduledOrders: const <MaintenanceOrder>[],
    backlogOrders: const <MaintenanceOrder>[],
    backlogHasMore: false,
  );

  @override
  Future<MaintenanceDailyExecutiveReport> getDailyExecutiveReport({
    required String date,
  }) async => const MaintenanceDailyExecutiveReport(
    carryOverOpenCount: 0,
    dayOpenCount: 0,
    totalOpenCount: 0,
    urgentCount: 0,
    scheduledCount: 0,
    inProgressCount: 0,
    unassignedCount: 0,
    carryOverOrders: <MaintenanceOrder>[],
    dayOpenOrders: <MaintenanceOrder>[],
  );
}

class _BacklogOnlyOrderService extends _EmptyLocationService {
  late final MaintenanceOrder secondOrder =
      MaintenanceOrder.fromJson(<String, dynamic>{
        'id': 88,
        'locationId': 1,
        'locationTypeSnapshot': 'ROOM',
        'locationCodeSnapshot': '101',
        'locationLabelSnapshot': 'Quarto 101',
        'title': 'Segunda pendencia sem agenda',
        'status': 'ASSIGNED',
        'requestOrigin': 'INTERNAL_ROLE',
        'reportedAt': '2026-09-21T08:00:00Z',
      });

  @override
  Future<MaintenanceCalendar> getCalendar({
    required String rangeStart,
    required String rangeEndExclusive,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
    int? backlogSize,
  }) async => MaintenanceCalendar(
    rangeStart: DateTime.parse(rangeStart),
    rangeEndExclusive: DateTime.parse(rangeEndExclusive),
    scheduledOrders: const <MaintenanceOrder>[],
    backlogOrders: <MaintenanceOrder>[order, secondOrder],
    backlogHasMore: false,
  );
}

class _OverdueOrderService extends _CarryOverOrderService {
  late final MaintenanceOrder overdueOrder =
      MaintenanceOrder.fromJson(<String, dynamic>{
        'id': 89,
        'locationId': 1,
        'locationTypeSnapshot': 'ROOM',
        'locationCodeSnapshot': '101',
        'locationLabelSnapshot': 'Quarto 101',
        'title': 'Ordem com horario encerrado',
        'status': 'SCHEDULED',
        'requestOrigin': 'INTERNAL_ROLE',
        'reportedAt': '2026-09-20T07:00:00Z',
        'scheduledStartAt': '2026-09-20T08:00:00',
        'scheduledEndAt': '2026-09-20T09:00:00',
      });

  @override
  Future<MaintenanceCalendar> getCalendar({
    required String rangeStart,
    required String rangeEndExclusive,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
    int? backlogSize,
  }) async => MaintenanceCalendar(
    rangeStart: DateTime.parse(rangeStart),
    rangeEndExclusive: DateTime.parse(rangeEndExclusive),
    scheduledOrders: <MaintenanceOrder>[overdueOrder],
    backlogOrders: const <MaintenanceOrder>[],
    backlogHasMore: false,
  );

  @override
  Future<MaintenanceDailyExecutiveReport> getDailyExecutiveReport({
    required String date,
  }) async => MaintenanceDailyExecutiveReport(
    carryOverOpenCount: 1,
    dayOpenCount: 0,
    totalOpenCount: 1,
    urgentCount: 0,
    scheduledCount: 1,
    inProgressCount: 0,
    unassignedCount: 1,
    carryOverOrders: <MaintenanceOrder>[overdueOrder],
    dayOpenOrders: const <MaintenanceOrder>[],
  );
}
