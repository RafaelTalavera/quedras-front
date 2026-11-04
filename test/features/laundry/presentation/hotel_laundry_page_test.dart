import 'package:costanorte/features/laundry/application/hotel_laundry_app_service.dart';
import 'package:costanorte/features/laundry/domain/hotel_laundry_models.dart';
import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:costanorte/features/laundry/domain/provider_laundry_models.dart';
import 'package:costanorte/features/laundry/presentation/hotel_laundry_page.dart';
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
    expect(find.text('DisponÃ­vel'), findsOneWidget);
    expect(find.text('DEV-7 Â· Lavanderia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Documentos recentes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Documentos recentes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hotel-laundry-dispatch')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('hotel-laundry-rewash')), findsOneWidget);
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
}

final class _HotelService implements HotelLaundryAppService {
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
