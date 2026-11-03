import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/laundry/application/provider_laundry_app_service.dart';
import 'package:costanorte/features/laundry/domain/provider_laundry_models.dart';
import 'package:costanorte/features/laundry/presentation/provider_laundry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra bandejas y saldos sin precios', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProviderLaundryPage(service: _FakeProviderService())),
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
      MaterialApp(home: ProviderLaundryPage(service: service)),
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
}

final class _FakeProviderService implements ProviderLaundryAppService {
  _FakeProviderService({this.failFirst = false});

  final bool failFirst;
  bool _failed = false;

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
}
