import 'package:costanorte/features/laundry/application/hotel_laundry_app_service.dart';
import 'package:costanorte/features/laundry/domain/hotel_laundry_models.dart';
import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:costanorte/features/laundry/domain/provider_laundry_models.dart';
import 'package:costanorte/features/laundry/presentation/hotel_laundry_page.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra tablero y bandejas operativas V2', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hotel-laundry-v2')), findsOneWidget);
    expect(find.text('En lavandería'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hotel-laundry-dispatch')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('hotel-laundry-rewash')), findsOneWidget);
    expect(find.byKey(const ValueKey('hotel-laundry-receive')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hotel-laundry-opening-stock')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('DEV-7 · Lavanderia'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DEV-7 · Lavanderia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Documentos recentes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Documentos recentes'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RWS-12 · Lavanderia'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('hotel-laundry-retry-12')),
      findsOneWidget,
    );
    expect(find.text('Tentar envio novamente'), findsOneWidget);
  });

  testWidgets('administra lavanderias activas e inactivas', (
    WidgetTester tester,
  ) async {
    final _HotelService service = _HotelService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hotel-laundry-providers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hotel-laundry-new-provider')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hotel-laundry-provider-name')),
      'Lavanderia Nova',
    );
    tester
        .widget<SwitchListTile>(
          find.byKey(const ValueKey('hotel-laundry-provider-active')),
        )
        .onChanged!(false);
    await tester.pump();
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('hotel-laundry-provider-save')),
        )
        .onPressed!();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(service.created?.name, 'Lavanderia Nova');
    expect(service.created?.active, isFalse);
    expect(find.text('Lavanderia Nova'), findsOneWidget);
  });

  testWidgets('acepta solo dígitos al enviar prendas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-laundry-dispatch')));
    await tester.pumpAndSettle();
    final Finder quantity = find.byKey(const ValueKey('hotel-dispatch-item-8'));
    await tester.enterText(quantity, '12a@.3');
    expect(tester.widget<TextField>(quantity).controller?.text, '123');
  });

  testWidgets('envío y relavado limitan la fecha a hoy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    for (final Key action in <Key>[
      const ValueKey('hotel-laundry-dispatch'),
      const ValueKey('hotel-laundry-rewash'),
    ]) {
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hotel-dispatch-date')));
      await tester.pumpAndSettle();

      final CalendarDatePicker picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      final DateTime now = DateTime.now();
      expect(picker.lastDate, DateTime(now.year, now.month, now.day));

      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('presenta la consulta de stock en formato tabla', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('hotel-laundry-inventory-history')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hotel-inventory-history-table')),
      findsOneWidget,
    );
    expect(find.text('Ítem'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Fecha de transacción'), findsOneWidget);
    expect(find.text('Movimiento'), findsOneWidget);
    expect(find.text('Toalha'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Agregado'), findsOneWidget);
    expect(find.text('Dado de baja'), findsOneWidget);
  });

  testWidgets('acepta solo dígitos al enviar prendas para relavagem', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-laundry-rewash')));
    await tester.pumpAndSettle();
    final Finder quantity = find.byKey(const ValueKey('hotel-dispatch-item-8'));
    await tester.enterText(quantity, '12a@.3');
    expect(tester.widget<TextField>(quantity).controller?.text, '123');
  });

  testWidgets('acepta solo dígitos al recibir prendas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-laundry-receive')));
    await tester.pumpAndSettle();
    for (final Key quantityKey in <Key>[
      const ValueKey('hotel-receive-clean-8'),
      const ValueKey('hotel-receive-dirty-8'),
    ]) {
      final Finder quantity = find.byKey(quantityKey);
      await tester.enterText(quantity, '45b#-6');
      expect(tester.widget<TextField>(quantity).controller?.text, '456');
    }
    expect(find.text('Receber da lavanderia'), findsNWidgets(2));
  });

  testWidgets('recepción limita la fecha a hoy', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: _HotelService())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-laundry-receive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hotel-receive-date')));
    await tester.pumpAndSettle();

    final CalendarDatePicker picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    final DateTime now = DateTime.now();
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
  });

  testWidgets('muestra con AppAlerts las prendas que exceden el saldo', (
    WidgetTester tester,
  ) async {
    const String message =
        'No se puede registrar la recepción. Estas prendas superan el saldo pendiente de la lavandería:\n'
        '- Toalha: solicitado 5, disponible 2';
    final _HotelService service = _HotelService(
      manualReturnError: const ApiException(
        message,
        kind: ApiErrorKind.http,
        statusCode: 409,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HotelLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hotel-laundry-receive')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hotel-receive-clean-8')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey('hotel-receive-save')));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível registrar'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  });
}

final class _HotelService implements HotelLaundryAppService {
  _HotelService({this.manualReturnError});

  final ApiException? manualReturnError;
  final List<LaundryProvider> providers = <LaundryProvider>[
    const LaundryProvider(id: 3, name: 'Lavanderia', active: true),
  ];
  CreateLaundryProviderRequest? created;

  @override
  Future<List<LaundryProvider>> listProviders() async => providers;

  @override
  Future<LaundryProvider> createProvider(
    CreateLaundryProviderRequest request,
  ) async {
    created = request;
    final LaundryProvider provider = LaundryProvider(
      id: 4,
      name: request.name,
      contact: request.contact,
      active: request.active,
    );
    providers.add(provider);
    return provider;
  }

  @override
  Future<LaundryProvider> updateProvider(
    int id,
    CreateLaundryProviderRequest request,
  ) async => LaundryProvider(
    id: id,
    name: request.name,
    contact: request.contact,
    active: request.active,
  );

  @override
  Future<List<LaundryItem>> listItems() async => const <LaundryItem>[
    LaundryItem(
      id: 8,
      name: 'Toalha',
      unitType: LaundryUnitType.piece,
      currentUnitPrice: 4.5,
      active: true,
    ),
  ];

  @override
  Future<HotelLaundryStockTotals> dashboard({int? providerId}) async =>
      const HotelLaundryStockTotals(
        hotelAvailable: 8,
        hotelRewashQueue: 1,
        providerProcessing: 4,
        providerRewash: 2,
        missing: 1,
        damaged: 0,
        total: 16,
      );

  @override
  Future<List<HotelLaundryOperationalDailyRow>> operationalSummary() async =>
      <HotelLaundryOperationalDailyRow>[
        HotelLaundryOperationalDailyRow(
          date: DateTime.utc(2026, 11, 4),
          itemId: 8,
          itemName: 'Toalha',
          unitType: 'PIECE',
          sentQuantity: 4,
          receivedQuantity: 2,
          rewashedQuantity: 1,
        ),
      ];

  @override
  Future<List<HotelLaundryInventoryMovement>> listInventoryMovements({
    required DateTime date,
  }) async => <HotelLaundryInventoryMovement>[
    HotelLaundryInventoryMovement(
      id: 1,
      effectiveAt: DateTime(2026, 11, 5, 9, 30),
      itemId: 8,
      itemName: 'Toalha',
      quantity: 12,
      movementType: 'OPENING_STOCK',
      createdAt: DateTime(2026, 11, 5, 9, 31),
      createdBy: 'admin',
    ),
    HotelLaundryInventoryMovement(
      id: 2,
      effectiveAt: DateTime(2026, 11, 5, 10, 30),
      itemId: 8,
      itemName: 'Toalha',
      quantity: 2,
      movementType: 'ITEM_RETIREMENT',
      createdAt: DateTime(2026, 11, 5, 10, 31),
      createdBy: 'admin',
    ),
  ];

  @override
  Future<HotelLaundryStockRow?> getAvailableStock({
    required int itemId,
  }) async => HotelLaundryStockRow(itemId: itemId, quantity: 100, version: 3);

  @override
  Future<void> createOpeningStock(HotelLaundryOpeningStockInput input) async {}

  @override
  Future<void> retireInventoryItem(
    HotelLaundryItemRetirementInput input,
  ) async {}

  @override
  Future<void> createManualReturn(HotelLaundryManualReturnInput input) async {
    if (manualReturnError case final ApiException error) throw error;
  }

  @override
  Future<HotelLaundryResultPage<HotelLaundryDocumentSummary>> listDocuments({
    int? providerId,
    String? status,
    String? documentType,
    int page = 0,
    int size = 20,
  }) async => HotelLaundryResultPage<HotelLaundryDocumentSummary>(
    page: page,
    size: size,
    hasNext: false,
    items: <HotelLaundryDocumentSummary>[
      HotelLaundryDocumentSummary(
        id: 11,
        reference: 'ENV-11',
        documentType: 'STANDARD_DISPATCH',
        status: 'SUBMITTED',
        providerId: 3,
        providerName: 'Lavanderia',
        effectiveAt: DateTime.utc(2026, 11, 3),
        version: 1,
      ),
      HotelLaundryDocumentSummary(
        id: 12,
        reference: 'RWS-12',
        documentType: 'REWASH_DISPATCH',
        status: 'DRAFT',
        providerId: 3,
        providerName: 'Lavanderia',
        effectiveAt: DateTime.utc(2026, 11, 4),
        version: 0,
      ),
    ],
  );

  @override
  Future<HotelLaundryResultPage<HotelLaundryReturnSummary>> listReturns({
    int? providerId,
    String? status,
    int page = 0,
    int size = 20,
  }) async => HotelLaundryResultPage<HotelLaundryReturnSummary>(
    page: page,
    size: size,
    hasNext: false,
    items: <HotelLaundryReturnSummary>[
      HotelLaundryReturnSummary(
        id: 7,
        reference: 'DEV-7',
        status: 'SUBMITTED',
        providerId: 3,
        providerName: 'Lavanderia',
        effectiveAt: DateTime.utc(2026, 11, 4),
        version: 1,
      ),
    ],
  );

  @override
  Future<HotelLaundryDocumentSummary> createDispatch({
    required HotelLaundryDispatchInput input,
    required bool rewash,
  }) => throw UnimplementedError();
  @override
  Future<HotelLaundryDocumentSummary> submitDocument({
    required int id,
    required int version,
  }) => throw UnimplementedError();
  @override
  Future<ProviderLaundryReturn> getReturn(int id) => throw UnimplementedError();
  @override
  Future<ProviderLaundryReturn> confirmReturn({
    required int id,
    required HotelLaundryReturnConfirmationInput input,
  }) => throw UnimplementedError();
}
