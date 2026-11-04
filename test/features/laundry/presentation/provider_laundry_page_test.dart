import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/laundry/application/provider_laundry_app_service.dart';
import 'package:costanorte/features/laundry/domain/provider_laundry_models.dart';
import 'package:costanorte/features/laundry/presentation/provider_laundry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra bandejas y saldos sin precios', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderLaundryPage(service: _FakeProviderService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('provider-laundry-portal')),
      findsOneWidget,
    );
    expect(find.text('Portal da lavanderia'), findsOneWidget);
    expect(find.text('ENV-11'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DEV-7'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DEV-7'), findsOneWidget);
    expect(find.text('Em processamento'), findsOneWidget);
    expect(find.text('Em relavagem'), findsOneWidget);
    expect(find.textContaining(r'R$'), findsNothing);
  });

  testWidgets('muestra error y permite reintentar', (tester) async {
    final service = _FakeProviderService(failFirst: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProviderLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('provider-laundry-error')),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('provider-laundry-portal')),
      findsOneWidget,
    );
  });

  testWidgets('abre detalle y confirma el documento completo', (tester) async {
    final service = _FakeProviderService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProviderLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENV-11'));
    await tester.pumpAndSettle();
    expect(find.text('Toalha de banho'), findsOneWidget);
    expect(find.textContaining(r'R$'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('provider-document-acknowledge')),
    );
    await tester.pumpAndSettle();

    expect(service.acknowledgedId, 11);
    expect(service.acknowledgedVersion, 1);
    expect(find.text('Envio confirmado.'), findsOneWidget);
  });

  testWidgets('crea una devolucion agregada como borrador', (tester) async {
    final service = _FakeProviderService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProviderLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('provider-return-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('return-clean-1')), '3');
    await tester.tap(find.byKey(const ValueKey('provider-return-save')));
    await tester.pumpAndSettle();

    expect(service.createdInput?.version, 0);
    expect(service.createdInput?.lines.single.itemId, 1);
    expect(service.createdInput?.lines.single.declaredClean, 3);
    expect(find.text('Devolução criada.'), findsOneWidget);
  });

  testWidgets('envia un borrador existente con su version', (tester) async {
    final service = _FakeProviderService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProviderLaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('DEV-7'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('DEV-7'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-return-submit')));
    await tester.pumpAndSettle();

    expect(service.submittedId, 7);
    expect(service.submittedVersion, 0);
    expect(find.text('Devolução enviada ao hotel.'), findsOneWidget);
  });
}

final class _FakeProviderService implements ProviderLaundryAppService {
  _FakeProviderService({this.failFirst = false});

  final bool failFirst;
  bool _failed = false;
  int? acknowledgedId;
  int? acknowledgedVersion;
  ProviderLaundryReturnInput? createdInput;
  int? submittedId;
  int? submittedVersion;

  void _maybeFail() {
    if (failFirst && !_failed) {
      _failed = true;
      throw const ApiException('Falha temporária.', kind: ApiErrorKind.network);
    }
  }

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryDocumentSummary>>
  listDocuments({int page = 0, int size = 20}) async {
    _maybeFail();
    return ProviderLaundryResultPage(
      page: 0,
      size: 20,
      hasNext: false,
      items: <ProviderLaundryDocumentSummary>[
        ProviderLaundryDocumentSummary(
          id: 11,
          reference: 'ENV-11',
          documentType: 'STANDARD_DISPATCH',
          status: 'SUBMITTED',
          effectiveAt: DateTime.utc(2026, 11, 3),
          version: 1,
        ),
      ],
    );
  }

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryReturnSummary>> listReturns({
    int page = 0,
    int size = 20,
  }) async => ProviderLaundryResultPage(
    page: 0,
    size: 20,
    hasNext: false,
    items: <ProviderLaundryReturnSummary>[
      ProviderLaundryReturnSummary(
        id: 7,
        reference: 'DEV-7',
        status: 'DRAFT',
        effectiveAt: DateTime.utc(2026, 11, 3),
        version: 0,
      ),
    ],
  );

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryStockRow>> listStock({
    required ProviderLaundryStockBucket bucket,
    int page = 0,
    int size = 50,
  }) async => ProviderLaundryResultPage(
    page: 0,
    size: 50,
    hasNext: false,
    items: <ProviderLaundryStockRow>[
      ProviderLaundryStockRow(
        itemId: bucket.index + 1,
        itemName: 'Toalha',
        unitType: 'PIECE',
        bucket: bucket.apiValue,
        quantity: bucket == ProviderLaundryStockBucket.processing ? 5 : 2,
        ageDays: 3,
        version: 1,
      ),
    ],
  );

  @override
  Future<ProviderLaundryDocument> getDocument(int id) async =>
      _document(status: 'SUBMITTED');

  @override
  Future<ProviderLaundryDocument> acknowledgeDocument({
    required int id,
    required int version,
    String? notes,
  }) async {
    acknowledgedId = id;
    acknowledgedVersion = version;
    return _document(status: 'CONFIRMED');
  }

  @override
  Future<ProviderLaundryDocument> observeDocument({
    required int id,
    required int version,
    required String notes,
  }) async => _document(status: 'OBSERVED');

  ProviderLaundryDocument _document({required String status}) =>
      ProviderLaundryDocument(
        id: 11,
        reference: 'ENV-11',
        documentType: 'STANDARD_DISPATCH',
        status: status,
        providerId: 3,
        providerName: 'Lavanderia Demo',
        effectiveAt: DateTime.utc(2026, 11, 3),
        version: 1,
        lines: const <ProviderLaundryDocumentLine>[
          ProviderLaundryDocumentLine(
            id: 1,
            itemId: 8,
            itemName: 'Toalha de banho',
            quantity: 5,
          ),
        ],
        confirmations: const <ProviderLaundryConfirmation>[],
      );

  @override
  Future<ProviderLaundryReturn> getReturn(int id) async => _returnManifest();

  @override
  Future<ProviderLaundryReturn> createReturn(
    ProviderLaundryReturnInput input,
  ) async {
    createdInput = input;
    return _returnManifest();
  }

  @override
  Future<ProviderLaundryReturn> updateReturn({
    required int id,
    required ProviderLaundryReturnInput input,
  }) async => _returnManifest();

  @override
  Future<ProviderLaundryReturn> submitReturn({
    required int id,
    required int version,
  }) async {
    submittedId = id;
    submittedVersion = version;
    return _returnManifest(status: 'SUBMITTED');
  }

  ProviderLaundryReturn _returnManifest({String status = 'DRAFT'}) =>
      ProviderLaundryReturn(
        id: 7,
        reference: 'DEV-7',
        status: status,
        providerId: 3,
        providerName: 'Lavanderia Demo',
        effectiveAt: DateTime.utc(2026, 11, 3),
        version: 0,
        lines: const <ProviderLaundryReturnLine>[
          ProviderLaundryReturnLine(
            id: 2,
            itemId: 1,
            itemName: 'Toalha',
            declaredClean: 3,
            declaredRetained: 0,
            acceptedClean: 0,
            returnedDirty: 0,
            retained: 0,
            missing: 0,
            damaged: 0,
          ),
        ],
      );
}
