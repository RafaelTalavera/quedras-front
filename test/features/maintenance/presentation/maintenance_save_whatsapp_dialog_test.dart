import 'package:costanorte/core/sync/schedule_sync_service.dart';
import 'package:costanorte/features/maintenance/application/maintenance_app_service.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:costanorte/features/maintenance/presentation/maintenance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ordem nao-AA abre dialogo WhatsApp depois de salvar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final _FakeMaintenanceService service = _FakeMaintenanceService();
    final ScheduleSyncService syncService = ScheduleSyncService(
      baseUrl: 'http://localhost/',
      authorizationHeaderProvider: () => null,
    );
    addTearDown(syncService.dispose);

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

    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Titulo'),
      'Router sem sinal',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descricao'),
      'Sem conexao no apartamento',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(service.createdOrders, hasLength(1));
    expect(service.createdOrders.single.providerId, 2);
    expect(find.text('Preparar aviso por WhatsApp'), findsOneWidget);
    expect(find.textContaining('Router sem sinal'), findsOneWidget);
    expect(find.text('Copiar texto'), findsOneWidget);
    expect(find.text('WhatsApp Web'), findsOneWidget);
  });
}

class _FakeMaintenanceService extends Fake implements MaintenanceAppService {
  final List<CreateMaintenanceOrderModel> createdOrders =
      <CreateMaintenanceOrderModel>[];

  final List<MaintenanceProvider> providers = <MaintenanceProvider>[
    MaintenanceProvider.fromJson(<String, dynamic>{
      'id': 1,
      'providerType': 'EXTERNAL',
      'specialty': 'AIR_CONDITIONING',
      'name': 'AA',
      'serviceLabel': 'AA',
      'whatsappNumber': '5548999998888',
      'whatsappEnabled': true,
      'active': true,
    }),
    MaintenanceProvider.fromJson(<String, dynamic>{
      'id': 2,
      'providerType': 'EXTERNAL',
      'specialty': 'INTERNET',
      'name': 'Internet',
      'serviceLabel': 'Internet',
      'whatsappEnabled': false,
      'active': true,
    }),
  ];

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
  Future<List<MaintenanceProvider>> listProviders() async => providers;

  @override
  Future<MaintenanceOrder> createOrder(
    CreateMaintenanceOrderModel model,
  ) async {
    createdOrders.add(model);
    final MaintenanceProvider provider = providers.firstWhere(
      (MaintenanceProvider item) => item.id == model.providerId,
    );
    return MaintenanceOrder.fromJson(<String, dynamic>{
      'id': 10,
      'locationId': model.locationId,
      'locationTypeSnapshot': 'ROOM',
      'locationCodeSnapshot': '101',
      'locationLabelSnapshot': 'Quarto 101',
      'providerId': model.providerId,
      'providerTypeSnapshot': provider.providerType.apiValue,
      'providerNameSnapshot': provider.name,
      'serviceLabelSnapshot': provider.serviceLabel,
      'title': model.title,
      'description': model.description,
      'status': 'OPEN',
      'requestOrigin': model.requestOrigin.apiValue,
      'reportedAt': DateTime.now().toIso8601String(),
    });
  }

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
