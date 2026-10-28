import 'package:costanorte/core/sync/schedule_sync_service.dart';
import 'package:costanorte/features/maintenance/application/maintenance_app_service.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:costanorte/features/maintenance/presentation/maintenance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

Future<void> _pumpMaintenancePage(
  WidgetTester tester,
  _CarryOverOrderService service,
  ScheduleSyncService syncService,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MaintenancePage(
          maintenanceAppService: service,
          scheduleSyncService: syncService,
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
  Future<List<MaintenanceProvider>> listProviders() async =>
      const <MaintenanceProvider>[];

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
}

class _EmptyLocationService extends _CarryOverOrderService {
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
