import 'dart:async';

import 'package:costanorte/core/audit/audit_models.dart';
import 'package:costanorte/core/network/api_exception.dart';
import 'package:costanorte/features/laundry/application/laundry_app_service.dart';
import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:costanorte/features/laundry/presentation/laundry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra estado de carga y luego vacío', (
    WidgetTester tester,
  ) async {
    final Completer<List<LaundryShipment>> shipments =
        Completer<List<LaundryShipment>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LaundryPage(
            service: _FakeLaundryService(shipments: shipments.future),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    shipments.complete(<LaundryShipment>[]);
    await tester.pumpAndSettle();
    expect(find.text('Registrar recebimento'), findsOneWidget);
  });

  testWidgets('presenta las tres operaciones independientes en la cabecera', (
    WidgetTester tester,
  ) async {
    await _pumpLaundry(tester, _FakeLaundryService());

    expect(
      find.byKey(const ValueKey<String>('laundry-action-new-shipment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('laundry-action-rewash')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('laundry-action-receive')),
      findsOneWidget,
    );
    expect(find.text('Pendientes'), findsNothing);
    expect(find.text('Para relavado'), findsNothing);
  });

  testWidgets('muestra error y acción de reintento', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LaundryPage(
            service: _FakeLaundryService(error: Exception('fallo')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível concluir a operação.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('identifica relavado como sin costo', (
    WidgetTester tester,
  ) async {
    final LaundryShipment rewash = _shipment(
      kind: LaundryShipmentKind.rewash,
      billableAmount: 50,
      status: LaundryShipmentStatus.sent,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LaundryPage(
            service: _FakeLaundryService(
              shipments: Future<List<LaundryShipment>>.value(<LaundryShipment>[
                rewash,
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relavagens registradas'));
    await tester.pumpAndSettle();
    expect(find.text('RELAVAGEM · SEM CUSTO'), findsOneWidget);
    expect(find.text('Faturável: R\$ 0,00'), findsOneWidget);
  });

  testWidgets('resume por fecha recibidas, enviadas, relavadas y totales', (
    WidgetTester tester,
  ) async {
    final List<LaundryShipment> shipments = <LaundryShipment>[
      _shipment(
        id: 1,
        kind: LaundryShipmentKind.standard,
        billableAmount: 20,
        sentAt: DateTime.utc(2026, 10, 30, 12),
        totalQuantity: 4,
      ),
      _shipment(
        id: 2,
        kind: LaundryShipmentKind.receipt,
        billableAmount: 0,
        sentAt: DateTime.utc(2026, 10, 30, 14),
        totalQuantity: 3,
      ),
      _shipment(
        id: 3,
        kind: LaundryShipmentKind.rewash,
        billableAmount: 0,
        sentAt: DateTime.utc(2026, 10, 29, 12),
        totalQuantity: 2,
      ),
      _shipment(
        id: 4,
        kind: LaundryShipmentKind.standard,
        status: LaundryShipmentStatus.cancelled,
        billableAmount: 0,
        sentAt: DateTime.utc(2026, 10, 30, 15),
        totalQuantity: 99,
      ),
    ];
    await _pumpLaundry(
      tester,
      _FakeLaundryService(
        shipments: Future<List<LaundryShipment>>.value(shipments),
      ),
    );

    await _openTab(tester, 'Resumo por data');

    final Finder table = find.byKey(
      const ValueKey<String>('laundry-daily-summary-table'),
    );
    expect(table, findsOneWidget);
    expect(
      find.descendant(of: table, matching: find.text('30/10/2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('29/10/2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('Totais')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('9')),
      findsOneWidget,
    );
    expect(find.descendant(of: table, matching: find.text('99')), findsNothing);
  });

  testWidgets(
    'Recibido usa el mismo formulario y crea una transacción propia',
    (WidgetTester tester) async {
      final _FakeLaundryService service = _FakeLaundryService(
        items: <LaundryItem>[_activeItem],
        providers: const <LaundryProvider>[
          LaundryProvider(id: 7, name: 'Aguas Claras', active: true),
        ],
      );
      await _pumpLaundry(tester, service);

      expect(find.text('Registrar recebimento'), findsOneWidget);
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey<String>('laundry-shipment-provider')),
          )
          .onChanged!(7);
      await tester.enterText(
        find.byKey(const ValueKey<String>('laundry-item-1')),
        '2',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('laundry-shipment-save')),
      );
      await tester.pumpAndSettle();

      expect(service.lastShipmentRequest?.kind, LaundryShipmentKind.receipt);
      expect(find.text('Recebimento salvo.'), findsOneWidget);
      expect(find.text('Não há recebimentos registrados.'), findsOneWidget);
      expect(find.text('Não há relavagens registradas.'), findsNothing);
      expect(service.receiveCalls, 0);
    },
  );

  testWidgets('el detalle muestra solo prendas y total', (
    WidgetTester tester,
  ) async {
    const LaundryShipmentLine line = LaundryShipmentLine(
      id: 10,
      itemId: 1,
      itemName: 'Toalla de baño',
      unitType: LaundryUnitType.piece,
      sentQuantity: 2,
      acceptedQuantity: 1,
      rewashQuantity: 0.5,
      missingQuantity: 0.25,
      damagedQuantity: 0.25,
      pendingQuantity: 0,
      unitPrice: 4.5,
      billableAmount: 9,
    );
    final LaundryShipment receipt = _shipment(
      kind: LaundryShipmentKind.receipt,
      billableAmount: 0,
      status: LaundryShipmentStatus.sent,
      sentAt: DateTime.utc(2026, 10, 30, 12),
      lines: const <LaundryShipmentLine>[line],
    );
    await _pumpLaundry(
      tester,
      _FakeLaundryService(
        shipments: Future<List<LaundryShipment>>.value(<LaundryShipment>[
          receipt,
        ]),
        detailShipment: receipt,
      ),
    );

    await tester.tap(find.text('Recebimentos registrados'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· Recebido'), findsOneWidget);
    expect(find.textContaining('· Enviado'), findsNothing);

    await tester.tap(find.text('Detalhes'));
    await tester.pumpAndSettle();
    final Finder detail = find.byType(AlertDialog);
    expect(
      find.descendant(of: detail, matching: find.text('Toalla de baño')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('laundry-detail-total')),
      findsOneWidget,
    );
    expect(find.text('Total: 2'), findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.textContaining('Aceito')),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.textContaining('Relavagem')),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.textContaining('Faltante')),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.textContaining('Danificado')),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.textContaining('Pendente')),
      findsNothing,
    );
  });

  testWidgets('Historial aplica filtros de proveedor y estado al servicio', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      shipments: Future<List<LaundryShipment>>.value(<LaundryShipment>[]),
      providers: const <LaundryProvider>[
        LaundryProvider(id: 7, name: 'Aguas Claras', active: true),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LaundryPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'Histórico');
    final Finder providerFilter = find.byKey(
      const ValueKey<String>('laundry-history-provider'),
    );
    tester.widget<DropdownButtonFormField<int>>(providerFilter).onChanged!(7);
    final Finder statusFilter = find.byKey(
      const ValueKey<String>('laundry-history-status'),
    );
    tester
        .widget<DropdownButtonFormField<LaundryShipmentStatus>>(statusFilter)
        .onChanged!(LaundryShipmentStatus.cancelled);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('laundry-history-apply')),
    );
    await tester.pumpAndSettle();

    expect(service.lastProviderId, 7);
    expect(service.lastStatus, LaundryShipmentStatus.cancelled);
    expect(service.listCalls, 2);
  });

  testWidgets('administra listado, bÃºsqueda y filtro de artÃ­culos', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem, _inactiveItem],
    );
    await _pumpLaundry(tester, service);
    await _openItems(tester);
    expect(find.text('Toalla de baÃ±o'), findsOneWidget);
    expect(find.text('SÃ¡bana individual'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-search')),
      'toalla',
    );
    await tester.pump();
    expect(find.text('Toalla de baÃ±o'), findsOneWidget);
    expect(find.text('SÃ¡bana individual'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-search')),
      '',
    );
    final Finder filter = find.byKey(
      const ValueKey<String>('laundry-item-status-filter'),
    );
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inativos').last);
    await tester.pumpAndSettle();
    expect(find.text('Toalla de baÃ±o'), findsNothing);
    expect(find.text('SÃ¡bana individual'), findsOneWidget);
  });

  testWidgets('valida y crea un artÃ­culo evitando doble envÃ­o', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final _FakeLaundryService service = _FakeLaundryService(createGate: gate);
    await _pumpLaundry(tester, service);
    await _openItems(tester);
    await tester.tap(find.byKey(const ValueKey<String>('laundry-new-item')));
    await tester.pumpAndSettle();
    final Finder save = find.byKey(const ValueKey<String>('laundry-item-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-name')),
      '  Alfombra de baÃ±o  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-price')),
      '8,501',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-price')),
      '8,50',
    );
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save, warnIfMissed: false);
    expect(service.createCalls, 1);
    expect(service.lastItem?.name, 'Alfombra de baÃ±o');
    expect(service.lastItem?.currentUnitPrice, 8.5);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Item criado.'), findsOneWidget);
  });

  testWidgets('edita y confirma la desactivaciÃ³n', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem],
    );
    await _pumpLaundry(tester, service);
    await _openItems(tester);
    await tester.tap(find.byKey(const ValueKey<String>('laundry-edit-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('laundry-item-active')));
    await tester.tap(find.byKey(const ValueKey<String>('laundry-item-save')));
    await tester.pumpAndSettle();
    expect(find.text('Desativar item'), findsOneWidget);
    await tester.tap(find.text('Desativar'));
    await tester.pumpAndSettle();
    expect(service.updateCalls, 1);
    expect(service.lastItem?.active, isFalse);
  });

  testWidgets('mantiene el formulario abierto ante 409', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      itemError: const ApiException(
        'Conflicto',
        kind: ApiErrorKind.http,
        statusCode: 409,
      ),
    );
    await _pumpLaundry(tester, service);
    await _openItems(tester);
    await tester.tap(find.byKey(const ValueKey<String>('laundry-new-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-name')),
      'Toalla',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-price')),
      '4.50',
    );
    await tester.pump();
    final Finder save = find.byKey(const ValueKey<String>('laundry-item-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(service.createCalls, 1);
    expect(find.textContaining('Já existe outro'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('laundry-item-save')),
      findsOneWidget,
    );
  });

  testWidgets('cierra ediciÃ³n y recarga ante 404', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem],
      itemError: const ApiException(
        'No existe',
        kind: ApiErrorKind.http,
        statusCode: 404,
      ),
    );
    await _pumpLaundry(tester, service);
    await _openItems(tester);
    await tester.tap(find.byKey(const ValueKey<String>('laundry-edit-item-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-price')),
      '5.00',
    );
    await tester.tap(find.byKey(const ValueKey<String>('laundry-item-save')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('laundry-item-save')),
      findsNothing,
    );
    expect(find.textContaining('não existe mais'), findsOneWidget);
  });

  testWidgets('nuevo envÃ­o muestra exclusivamente artÃ­culos activos', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem, _inactiveItem],
    );
    await _pumpLaundry(tester, service);
    await tester.tap(find.textContaining('Novo env'));
    await tester.pumpAndSettle();
    expect(find.text('Toalla de baÃ±o'), findsOneWidget);
    expect(find.text('SÃ¡bana individual'), findsNothing);
  });

  testWidgets('cantidad inicia en cero y responde a los botones mÃ¡s y menos', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem],
    );
    await _pumpLaundry(tester, service);
    await tester.tap(find.textContaining('Novo env'));
    await tester.pumpAndSettle();

    final Finder quantity = find.byKey(
      const ValueKey<String>('laundry-item-1'),
    );
    expect(tester.widget<TextFormField>(quantity).controller?.text, '0');

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(tester.widget<TextFormField>(quantity).controller?.text, '1');

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(tester.widget<TextFormField>(quantity).controller?.text, '0');
  });

  testWidgets(
    'Enter avanza entre cantidades y guarda recibido desde el ultimo campo',
    (WidgetTester tester) async {
      final _FakeLaundryService service = _FakeLaundryService(
        items: const <LaundryItem>[_activeItem, _secondActiveItem],
        providers: const <LaundryProvider>[
          LaundryProvider(id: 7, name: 'Aguas Claras', active: true),
        ],
      );
      await _pumpLaundry(tester, service);
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey<String>('laundry-shipment-provider')),
          )
          .onChanged!(7);

      final Finder first = find.byKey(const ValueKey<String>('laundry-item-1'));
      final Finder second = find.byKey(
        const ValueKey<String>('laundry-item-3'),
      );
      await tester.tap(first);
      await tester.enterText(first, '2');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final EditableText secondEditable = tester.widget<EditableText>(
        find.descendant(of: second, matching: find.byType(EditableText)),
      );
      expect(secondEditable.focusNode.hasFocus, isTrue);
      await tester.enterText(second, '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(service.lastShipmentRequest?.kind, LaundryShipmentKind.receipt);
      expect(
        service.lastShipmentRequest?.lines.map((line) => line.quantity),
        <double>[2, 3],
      );
      expect(find.text('Recebimento salvo.'), findsOneWidget);
    },
  );

  testWidgets('las cantidades rechazan caracteres no numericos', (
    WidgetTester tester,
  ) async {
    await _pumpLaundry(
      tester,
      _FakeLaundryService(items: <LaundryItem>[_activeItem]),
    );
    final Finder quantity = find.byKey(
      const ValueKey<String>('laundry-item-1'),
    );

    await tester.tap(quantity);
    await tester.enterText(quantity, '2a');

    expect(tester.widget<TextFormField>(quantity).controller?.text, '0');
  });

  testWidgets('nuevo envÃ­o permite seleccionar una fecha anterior', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem],
      providers: const <LaundryProvider>[
        LaundryProvider(id: 7, name: 'Aguas Claras', active: true),
      ],
    );
    await _pumpLaundry(tester, service);
    await tester.tap(find.textContaining('Novo env'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('laundry-shipment-date')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final Finder provider = find.byKey(
      const ValueKey<String>('laundry-shipment-provider'),
    );
    tester.widget<DropdownButtonFormField<int>>(provider).onChanged!(7);
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-1')),
      '2',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('laundry-shipment-save')),
    );
    await tester.pumpAndSettle();

    expect(service.lastShipmentRequest, isNotNull);
    expect(service.lastShipmentRequest!.sentAt.day, 15);
    expect(service.getShipmentCalls, 0);
    expect(find.text('Envio salvo.'), findsOneWidget);
    expect(find.textContaining('Aceito'), findsNothing);
    expect(find.textContaining('Faltante'), findsNothing);
  });

  testWidgets('registra relavado manual como transacción independiente', (
    WidgetTester tester,
  ) async {
    final _FakeLaundryService service = _FakeLaundryService(
      items: <LaundryItem>[_activeItem],
      providers: const <LaundryProvider>[
        LaundryProvider(id: 7, name: 'Aguas Claras', active: true),
      ],
    );
    await _pumpLaundry(tester, service);
    await _openTab(tester, 'Relavagem');
    expect(find.text('Registrar relavagem'), findsOneWidget);
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey<String>('laundry-shipment-provider')),
        )
        .onChanged!(7);
    await tester.enterText(
      find.byKey(const ValueKey<String>('laundry-item-1')),
      '2',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('laundry-shipment-save')),
    );
    await tester.pumpAndSettle();
    expect(service.lastShipmentRequest?.kind, LaundryShipmentKind.rewash);
    expect(find.text('Relavagem salva sem custo.'), findsOneWidget);
  });
}

const LaundryItem _activeItem = LaundryItem(
  id: 1,
  name: 'Toalla de baÃ±o',
  unitType: LaundryUnitType.piece,
  currentUnitPrice: 4.5,
  active: true,
);
const LaundryItem _inactiveItem = LaundryItem(
  id: 2,
  name: 'SÃ¡bana individual',
  unitType: LaundryUnitType.piece,
  currentUnitPrice: 7,
  active: false,
);
const LaundryItem _secondActiveItem = LaundryItem(
  id: 3,
  name: 'Funda de almohada',
  unitType: LaundryUnitType.piece,
  currentUnitPrice: 3,
  active: true,
);

Future<void> _pumpLaundry(
  WidgetTester tester,
  _FakeLaundryService service,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LaundryPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openItems(WidgetTester tester) async {
  await _openTab(tester, 'Itens e preços');
}

Future<void> _openTab(WidgetTester tester, String label) async {
  Finder tab = find.text(label);
  if (tab.evaluate().isEmpty) {
    await tester.tap(
      find.byKey(const ValueKey<String>('laundry-secondary-menu')),
    );
    await tester.pumpAndSettle();
    tab = find.text(label).last;
  }
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

LaundryShipment _shipment({
  required LaundryShipmentKind kind,
  required double billableAmount,
  LaundryShipmentStatus status = LaundryShipmentStatus.sent,
  DateTime? sentAt,
  int id = 1,
  String shipmentNumber = 'LAV-1',
  List<LaundryShipmentLine> lines = const <LaundryShipmentLine>[],
  double totalQuantity = 2,
}) => LaundryShipment(
  id: id,
  shipmentNumber: shipmentNumber,
  providerId: 1,
  providerName: 'Aguas Claras',
  kind: kind,
  status: status,
  sentAt: status == LaundryShipmentStatus.pendingDispatch
      ? sentAt
      : sentAt ?? DateTime.utc(2026, 10, 30),
  version: 0,
  totalQuantity: totalQuantity,
  billableAmount: billableAmount,
  lines: lines,
);

final class _FakeLaundryService implements LaundryAppService {
  _FakeLaundryService({
    this.shipments,
    this.error,
    this.providers = const <LaundryProvider>[],
    List<LaundryItem>? items,
    this.itemError,
    this.createGate,
    this.detailShipment,
  }) : items = items ?? <LaundryItem>[];
  final Future<List<LaundryShipment>>? shipments;
  final Object? error;
  final List<LaundryProvider> providers;
  final List<LaundryItem> items;
  final ApiException? itemError;
  final Completer<void>? createGate;
  final LaundryShipment? detailShipment;
  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int dispatchCalls = 0;
  int receiveCalls = 0;
  int getShipmentCalls = 0;
  LaundryItem? lastItem;
  CreateLaundryShipmentRequest? lastShipmentRequest;
  DispatchLaundryShipmentRequest? lastDispatchRequest;
  ReceiveLaundryShipmentRequest? lastReceiveRequest;
  int? lastProviderId;
  LaundryShipmentStatus? lastStatus;
  @override
  Future<List<LaundryProvider>> listProviders() async => providers;
  @override
  Future<List<LaundryItem>> listItems() async => List<LaundryItem>.of(items);
  @override
  Future<List<LaundryShipment>> listShipments({
    LaundryShipmentStatus? status,
    int? providerId,
    String? dateFrom,
    String? dateTo,
  }) async {
    listCalls++;
    lastProviderId = providerId;
    lastStatus = status;
    if (error != null) {
      throw error!;
    }
    return (await shipments) ?? const <LaundryShipment>[];
  }

  @override
  Future<LaundryProvider> createProvider(
    CreateLaundryProviderRequest request,
  ) => throw UnimplementedError();
  @override
  Future<LaundryItem> createItem(LaundryItem item) async {
    createCalls++;
    lastItem = item;
    if (itemError != null) {
      throw itemError!;
    }
    if (createGate != null) {
      await createGate!.future;
    }
    final LaundryItem created = LaundryItem(
      id: 99,
      name: item.name,
      unitType: item.unitType,
      currentUnitPrice: item.currentUnitPrice,
      active: item.active,
    );
    items.add(created);
    return created;
  }

  @override
  Future<LaundryItem> updateItem(int id, LaundryItem item) async {
    updateCalls++;
    lastItem = item;
    if (itemError != null) {
      throw itemError!;
    }
    final int index = items.indexWhere((LaundryItem value) => value.id == id);
    if (index >= 0) {
      items[index] = item;
    }
    return item;
  }

  @override
  Future<LaundryShipment> createShipment(
    CreateLaundryShipmentRequest request,
  ) async {
    lastShipmentRequest = request;
    return _shipment(kind: LaundryShipmentKind.standard, billableAmount: 9);
  }

  @override
  Future<LaundryShipment> getShipment(int id) async {
    getShipmentCalls++;
    return detailShipment ??
        _shipment(kind: LaundryShipmentKind.standard, billableAmount: 9);
  }

  @override
  Future<ReceiveLaundryShipmentResult> receiveShipment(
    int id,
    ReceiveLaundryShipmentRequest request,
  ) async {
    receiveCalls++;
    lastReceiveRequest = request;
    return ReceiveLaundryShipmentResult(
      shipment: _shipment(
        kind: LaundryShipmentKind.standard,
        billableAmount: 20,
        status: LaundryShipmentStatus.received,
      ),
    );
  }

  @override
  Future<LaundryShipment> dispatchShipment(
    int id,
    DispatchLaundryShipmentRequest request,
  ) async {
    dispatchCalls++;
    lastDispatchRequest = request;
    return _shipment(kind: LaundryShipmentKind.rewash, billableAmount: 0);
  }

  @override
  Future<LaundryShipment> cancelShipment(int id, String cancellationNotes) =>
      throw UnimplementedError();
  @override
  Future<List<AuditEventModel>> shipmentAudit(int id) async =>
      const <AuditEventModel>[];
}
