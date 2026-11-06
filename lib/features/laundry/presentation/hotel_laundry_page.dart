import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback/app_alerts.dart';
import '../../../core/network/api_exception.dart';
import '../application/hotel_laundry_app_service.dart';
import '../domain/hotel_laundry_models.dart';
import '../domain/laundry_models.dart';
import '../domain/provider_laundry_models.dart';

class HotelLaundryPage extends StatefulWidget {
  const HotelLaundryPage({required this.service, super.key});

  final HotelLaundryAppService service;

  @override
  State<HotelLaundryPage> createState() => _HotelLaundryPageState();
}

class _HotelLaundryPageState extends State<HotelLaundryPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  HotelLaundryStockTotals? _totals;
  List<HotelLaundryDocumentSummary> _documents = const [];
  List<HotelLaundryReturnSummary> _returns = const [];
  List<LaundryProvider> _providers = const [];
  List<LaundryItem> _items = const [];
  List<HotelLaundryOperationalDailyRow> _dailyRows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        widget.service.dashboard(),
        widget.service.listDocuments(size: 50),
        widget.service.listReturns(status: 'SUBMITTED', size: 50),
        widget.service.listProviders(),
        widget.service.listItems(),
        widget.service.operationalSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _totals = results[0] as HotelLaundryStockTotals;
        _documents =
            (results[1] as HotelLaundryResultPage<HotelLaundryDocumentSummary>)
                .items;
        _returns =
            (results[2] as HotelLaundryResultPage<HotelLaundryReturnSummary>)
                .items;
        _providers = (results[3] as List<LaundryProvider>)
            .where((LaundryProvider provider) => provider.active)
            .toList(growable: false);
        _items = (results[4] as List<LaundryItem>)
            .where((LaundryItem item) => item.active)
            .toList(growable: false);
        _dailyRows = results[5] as List<HotelLaundryOperationalDailyRow>;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Não foi possível carregar a lavanderia.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, key: const ValueKey('hotel-laundry-error')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    final HotelLaundryStockTotals totals = _totals!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('hotel-laundry-v2'),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: <Widget>[
              const Text(
                'Controle de lavanderia',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    key: const ValueKey('hotel-laundry-dispatch'),
                    onPressed: _saving ? null : () => _showDispatch(false),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Enviar'),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('hotel-laundry-receive'),
                    onPressed: _saving ? null : _showManualReturn,
                    icon: const Icon(Icons.move_to_inbox_outlined),
                    label: const Text('Receber da lavanderia'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-rewash'),
                    onPressed: _saving ? null : () => _showDispatch(true),
                    icon: const Icon(Icons.replay_outlined),
                    label: const Text('Enviar para relavagem'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-providers'),
                    onPressed: _saving ? null : _showProviders,
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Lavanderias'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-opening-stock'),
                    onPressed: _saving ? null : _showOpeningStock,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Estoque inicial'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-inventory-history'),
                    onPressed: _saving ? null : _showInventoryHistory,
                    icon: const Icon(Icons.manage_search_outlined),
                    label: const Text('Consultar estoque'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-retire-item'),
                    onPressed: _saving ? null : _showItemRetirement,
                    icon: const Icon(Icons.remove_shopping_cart_outlined),
                    label: const Text('Dar de baixa'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricCard(
                'En lavandería',
                totals.providerProcessing + totals.providerRewash,
              ),
              _MetricCard(
                'Recibido de lavandería',
                _dailyRows.fold<double>(
                  0,
                  (double total, HotelLaundryOperationalDailyRow row) =>
                      total + row.receivedQuantity,
                ),
              ),
              _MetricCard('En hotel para relavado', totals.hotelRewashQueue),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Movimientos por prenda y día',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_dailyRows.isEmpty)
            const Card(
              child: ListTile(title: Text('No hay movimientos registrados.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('hotel-laundry-daily-summary'),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Prenda')),
                  DataColumn(label: Text('Enviado'), numeric: true),
                  DataColumn(label: Text('Recibido'), numeric: true),
                  DataColumn(label: Text('Relavado'), numeric: true),
                ],
                rows: _dailyRows
                    .map(
                      (HotelLaundryOperationalDailyRow row) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(_date(row.date))),
                          DataCell(Text(row.itemName)),
                          DataCell(Text(_number(row.sentQuantity))),
                          DataCell(Text(_number(row.receivedQuantity))),
                          DataCell(Text(_number(row.rewashedQuantity))),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          const SizedBox(height: 28),
          Text(
            'Devoluções para confirmar (${_returns.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_returns.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhuma devolução pendente.')),
            )
          else
            ..._returns.map(
              (HotelLaundryReturnSummary item) => Card(
                child: ListTile(
                  title: Text('${item.reference} · ${item.providerName}'),
                  subtitle: Text(_dateTime(item.effectiveAt)),
                  trailing: FilledButton(
                    key: ValueKey('hotel-laundry-confirm-${item.id}'),
                    onPressed: _saving ? null : () => _showReturn(item),
                    child: const Text('Conferir'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 28),
          Text(
            'Documentos recentes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_documents.isEmpty)
            const Card(child: ListTile(title: Text('Nenhum documento V2.')))
          else
            ..._documents.map(
              (HotelLaundryDocumentSummary item) => Card(
                child: ListTile(
                  title: Text('${item.reference} · ${item.providerName}'),
                  subtitle: Text(
                    '${_documentType(item.documentType)} · ${_status(item.status)} · ${_dateTime(item.effectiveAt)}',
                  ),
                  trailing: item.status == 'DRAFT'
                      ? FilledButton(
                          key: ValueKey('hotel-laundry-retry-${item.id}'),
                          onPressed: _saving
                              ? null
                              : () => _retryDocumentSubmission(item),
                          child: const Text('Tentar envio novamente'),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showProviders() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _LaundryProvidersDialog(service: widget.service),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _showDispatch(bool rewash) async {
    if (_providers.isEmpty || _items.isEmpty) {
      _message('Cadastre ao menos um fornecedor e um item ativo.');
      return;
    }
    final Map<int, TextEditingController> quantities =
        <int, TextEditingController>{
          for (final LaundryItem item in _items)
            item.id: TextEditingController(),
        };
    int providerId = _providers.first.id;
    DateTime effectiveAt = DateTime.now();
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(rewash ? 'Enviar para relavagem' : 'Novo envio'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<int>(
                        initialValue: providerId,
                        decoration: const InputDecoration(
                          labelText: 'Fornecedor',
                        ),
                        items: _providers
                            .map(
                              (LaundryProvider provider) =>
                                  DropdownMenuItem<int>(
                                    value: provider.id,
                                    child: Text(provider.name),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (int? value) => setDialogState(() {
                          if (value != null) providerId = value;
                        }),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const ValueKey('hotel-dispatch-date'),
                        onPressed: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? selected = await showDatePicker(
                            context: context,
                            initialDate: effectiveAt,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(now.year, now.month, now.day),
                            helpText: 'Fecha de la transacción',
                          );
                          if (selected == null) return;
                          setDialogState(() {
                            effectiveAt = DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                              effectiveAt.hour,
                              effectiveAt.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Fecha: ${_date(effectiveAt)}'),
                      ),
                      const SizedBox(height: 12),
                      ..._items.map(
                        (LaundryItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            key: ValueKey('hotel-dispatch-item-${item.id}'),
                            controller: quantities[item.id],
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  '${item.name} (${item.unitType.label})',
                              hintText: '0',
                            ),
                          ),
                        ),
                      ),
                      TextField(
                        controller: notes,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('hotel-dispatch-save'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salvar e enviar'),
                ),
              ],
            ),
      ),
    );
    final List<HotelLaundryDispatchLineInput> lines = _items
        .map(
          (LaundryItem item) => HotelLaundryDispatchLineInput(
            itemId: item.id,
            quantity: _quantity(quantities[item.id]?.text),
          ),
        )
        .where((HotelLaundryDispatchLineInput line) => line.quantity > 0)
        .toList(growable: false);
    for (final TextEditingController controller in quantities.values) {
      controller.dispose();
    }
    if (confirmed != true) {
      notes.dispose();
      return;
    }
    if (lines.isEmpty) {
      notes.dispose();
      _message('Informe ao menos uma quantidade positiva.');
      return;
    }
    final String noteValue = notes.text;
    notes.dispose();
    await _command(() async {
      final HotelLaundryDocumentSummary draft = await widget.service
          .createDispatch(
            rewash: rewash,
            input: HotelLaundryDispatchInput(
              version: 0,
              providerId: providerId,
              effectiveAt: effectiveAt,
              notes: noteValue,
              lines: lines,
            ),
          );
      await widget.service.submitDocument(id: draft.id, version: draft.version);
    });
  }

  Future<void> _showOpeningStock() async {
    if (_items.isEmpty) {
      _message('Cadastre ao menos um item ativo.');
      return;
    }
    final DateTime? effectiveAt = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Fecha del stock inicial',
    );
    if (effectiveAt == null || !mounted) return;
    final Map<int, TextEditingController> quantities =
        <int, TextEditingController>{
          for (final LaundryItem item in _items)
            item.id: TextEditingController(),
        };
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Estoque inicial'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  key: const ValueKey('hotel-opening-date'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Fecha del stock'),
                  subtitle: Text(_date(effectiveAt)),
                ),
                const Text(
                  'Informe a quantidade disponível no hotel para cada item.',
                ),
                const SizedBox(height: 12),
                ..._items.map(
                  (LaundryItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      key: ValueKey('hotel-opening-item-${item.id}'),
                      controller: quantities[item.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '${item.name} (${item.unitType.label})',
                        hintText: '0',
                      ),
                    ),
                  ),
                ),
                TextField(
                  key: const ValueKey('hotel-opening-notes'),
                  controller: notes,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('hotel-opening-save'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar estoque'),
          ),
        ],
      ),
    );
    final List<HotelLaundryDispatchLineInput> lines = _items
        .map(
          (LaundryItem item) => HotelLaundryDispatchLineInput(
            itemId: item.id,
            quantity: _quantity(quantities[item.id]?.text),
          ),
        )
        .toList(growable: false);
    for (final TextEditingController controller in quantities.values) {
      controller.dispose();
    }
    final String noteValue = notes.text;
    notes.dispose();
    if (confirmed != true) return;
    if (!lines.any((HotelLaundryDispatchLineInput line) => line.quantity > 0)) {
      _message('Informe ao menos uma quantidade positiva.');
      return;
    }
    await _command(
      () => widget.service.createOpeningStock(
        HotelLaundryOpeningStockInput(
          version: 0,
          effectiveAt: effectiveAt,
          notes: noteValue,
          lines: lines,
        ),
      ),
    );
  }

  Future<void> _showInventoryHistory() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Fecha de consulta',
    );
    if (date == null || !mounted) return;
    try {
      final List<HotelLaundryInventoryMovement> movements = await widget.service
          .listInventoryMovements(date: date);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Trazabilidad · ${_date(date)}'),
          content: SizedBox(
            width: 760,
            child: movements.isEmpty
                ? const Text('No hay movimientos para la fecha consultada.')
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        key: const ValueKey('hotel-inventory-history-table'),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Ítem')),
                          DataColumn(label: Text('Total'), numeric: true),
                          DataColumn(label: Text('Fecha de transacción')),
                          DataColumn(label: Text('Movimiento')),
                        ],
                        rows: movements
                            .map(
                              (HotelLaundryInventoryMovement row) => DataRow(
                                cells: <DataCell>[
                                  DataCell(Text(row.itemName)),
                                  DataCell(Text(_number(row.quantity.abs()))),
                                  DataCell(Text(_dateTime(row.effectiveAt))),
                                  DataCell(Text(_inventoryAction(row))),
                                ],
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      await AppAlerts.error(
        context,
        title: 'No fue posible consultar',
        message: error is ApiException
            ? error.message
            : 'No fue posible consultar el inventario.',
      );
    }
  }

  Future<void> _showItemRetirement() async {
    if (_items.isEmpty) {
      _message('No hay productos activos para dar de baja.');
      return;
    }
    LaundryItem selectedItem = _items.first;
    final DateTime? effectiveAt = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Fecha de retiro',
    );
    if (effectiveAt == null || !mounted) return;
    final TextEditingController quantity = TextEditingController();
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Dar de baja producto'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<LaundryItem>(
                      key: const ValueKey('hotel-retire-item'),
                      initialValue: selectedItem,
                      decoration: const InputDecoration(labelText: 'Producto'),
                      items: _items
                          .map(
                            (LaundryItem item) => DropdownMenuItem<LaundryItem>(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (LaundryItem? item) {
                        if (item != null) {
                          setDialogState(() => selectedItem = item);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('hotel-retire-quantity'),
                      controller: quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad a retirar del inventario',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('hotel-retire-notes'),
                      controller: notes,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de la baja (obligatorio)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('hotel-retire-save'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Retirar y dar de baja'),
                ),
              ],
            ),
      ),
    );
    final double quantityValue = _quantity(quantity.text);
    final String notesValue = notes.text.trim();
    quantity.dispose();
    notes.dispose();
    if (confirmed != true) return;
    if (quantityValue <= 0 || notesValue.isEmpty) {
      _message('Informe una cantidad positiva y el motivo de la baja.');
      return;
    }
    await _command(() async {
      final HotelLaundryStockRow? stock = await widget.service
          .getAvailableStock(itemId: selectedItem.id);
      if (stock == null || stock.quantity < quantityValue) {
        throw ApiException(
          'Estoque disponível insuficiente. Disponível: '
          '${_number(stock?.quantity ?? 0)}.',
          kind: ApiErrorKind.http,
          statusCode: 409,
        );
      }
      await widget.service.retireInventoryItem(
        HotelLaundryItemRetirementInput(
          itemId: selectedItem.id,
          version: stock.version,
          effectiveAt: effectiveAt,
          quantity: quantityValue,
          notes: notesValue,
        ),
      );
    });
  }

  Future<void> _showManualReturn() async {
    if (_providers.isEmpty || _items.isEmpty) {
      _message('Cadastre ao menos uma lavanderia e uma peça ativa.');
      return;
    }
    int providerId = _providers.first.id;
    DateTime effectiveAt = DateTime.now();
    final Map<int, TextEditingController> clean = <int, TextEditingController>{
      for (final LaundryItem item in _items) item.id: TextEditingController(),
    };
    final Map<int, TextEditingController> dirty = <int, TextEditingController>{
      for (final LaundryItem item in _items) item.id: TextEditingController(),
    };
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Receber da lavanderia'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    initialValue: providerId,
                    decoration: const InputDecoration(labelText: 'Lavandería'),
                    items: _providers
                        .map(
                          (LaundryProvider provider) => DropdownMenuItem<int>(
                            value: provider.id,
                            child: Text(provider.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) => setDialogState(() {
                      if (value != null) providerId = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-receive-date'),
                    onPressed: () async {
                      final DateTime now = DateTime.now();
                      final DateTime? selected = await showDatePicker(
                        context: context,
                        initialDate: effectiveAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(now.year, now.month, now.day),
                        helpText: 'Fecha de recepción',
                      );
                      if (selected == null) return;
                      setDialogState(() {
                        effectiveAt = DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                          effectiveAt.hour,
                          effectiveAt.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Fecha: ${_date(effectiveAt)}'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Registre las prendas limpias recibidas y las que quedan en el hotel para relavado.',
                  ),
                  const SizedBox(height: 12),
                  ..._items.map(
                    (LaundryItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(item.name)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: ValueKey('hotel-receive-clean-${item.id}'),
                              controller: clean[item.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Limpias',
                                hintText: '0',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: ValueKey('hotel-receive-dirty-${item.id}'),
                              controller: dirty[item.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Para relavado',
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('hotel-receive-save'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar recepción'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final List<HotelLaundryManualReturnLineInput> lines = _items
        .map(
          (LaundryItem item) => HotelLaundryManualReturnLineInput(
            itemId: item.id,
            acceptedClean: _quantity(clean[item.id]?.text),
            returnedDirty: _quantity(dirty[item.id]?.text),
          ),
        )
        .where((line) => line.acceptedClean + line.returnedDirty > 0)
        .toList(growable: false);
    for (final TextEditingController controller in <TextEditingController>[
      ...clean.values,
      ...dirty.values,
    ]) {
      controller.dispose();
    }
    final String noteValue = notes.text;
    notes.dispose();
    if (confirmed != true) return;
    if (lines.isEmpty) {
      _message('Informe ao menos uma quantidade positiva.');
      return;
    }
    await _command(
      () => widget.service.createManualReturn(
        HotelLaundryManualReturnInput(
          providerId: providerId,
          effectiveAt: effectiveAt,
          notes: noteValue,
          lines: lines,
        ),
      ),
    );
  }

  Future<void> _showReturn(HotelLaundryReturnSummary summary) async {
    final ProviderLaundryReturn manifest = await widget.service.getReturn(
      summary.id,
    );
    if (!mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirmar ${manifest.reference}'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: manifest.lines
                .map(
                  (ProviderLaundryReturnLine line) => ListTile(
                    title: Text(line.itemName),
                    subtitle: Text(
                      'Limpo: ${_number(line.declaredClean)} · Retido: ${_number(line.declaredRetained)}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('hotel-return-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar classificação'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _command(
      () => widget.service.confirmReturn(
        id: manifest.id,
        input: HotelLaundryReturnConfirmationInput(
          version: manifest.version,
          lines: manifest.lines
              .map(
                (ProviderLaundryReturnLine line) =>
                    HotelLaundryReturnClassificationInput(
                      itemId: line.itemId,
                      acceptedClean: line.declaredClean,
                      returnedDirty: 0,
                      retained: line.declaredRetained,
                      missing: 0,
                      damaged: 0,
                    ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _retryDocumentSubmission(
    HotelLaundryDocumentSummary document,
  ) => _command(
    () => widget.service.submitDocument(
      id: document.id,
      version: document.version,
    ),
  );

  Future<void> _command(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      await AppAlerts.success(
        context,
        title: 'Operação concluída',
        message: 'A operação foi registrada corretamente.',
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      await AppAlerts.error(
        context,
        title: 'Não foi possível registrar',
        message: error is ApiException
            ? error.message
            : 'Não foi possível concluir a operação.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _LaundryProvidersDialog extends StatefulWidget {
  const _LaundryProvidersDialog({required this.service});
  final HotelLaundryAppService service;

  @override
  State<_LaundryProvidersDialog> createState() =>
      _LaundryProvidersDialogState();
}

class _LaundryProvidersDialogState extends State<_LaundryProvidersDialog> {
  List<LaundryProvider> _providers = const <LaundryProvider>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<LaundryProvider> providers = await widget.service
          .listProviders();
      if (mounted) {
        setState(() {
          _providers = providers;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is ApiException
              ? error.message
              : 'Não foi possível carregar as lavanderias.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Lavanderias'),
    content: SizedBox(
      width: 680,
      height: 500,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _providers.isEmpty
          ? const Center(child: Text('Nenhuma lavanderia cadastrada.'))
          : ListView.separated(
              itemCount: _providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final LaundryProvider provider = _providers[index];
                return Card(
                  color: provider.active
                      ? null
                      : Theme.of(context).colorScheme.surfaceContainer,
                  child: ListTile(
                    title: Text(provider.name),
                    subtitle: Text(provider.contact ?? 'Sem contato informado'),
                    leading: Icon(
                      provider.active
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      color: provider.active ? Colors.green : Colors.red,
                    ),
                    trailing: OutlinedButton.icon(
                      key: ValueKey('hotel-laundry-provider-${provider.id}'),
                      onPressed: () => _edit(provider),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ),
                );
              },
            ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
      FilledButton.icon(
        key: const ValueKey('hotel-laundry-new-provider'),
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova lavanderia'),
      ),
    ],
  );

  Future<void> _edit(LaundryProvider? provider) async {
    final TextEditingController name = TextEditingController(
      text: provider?.name ?? '',
    );
    final TextEditingController contact = TextEditingController(
      text: provider?.contact ?? '',
    );
    bool active = provider?.active ?? true;
    bool saving = false;
    String? error;
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          final bool valid =
              name.text.trim().isNotEmpty &&
              name.text.trim().length <= 120 &&
              contact.text.trim().length <= 160;
          return AlertDialog(
            title: Text(
              provider == null ? 'Nova lavanderia' : 'Editar lavanderia',
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    key: const ValueKey('hotel-laundry-provider-name'),
                    controller: name,
                    enabled: !saving,
                    maxLength: 120,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    onChanged: (_) => setLocal(() => error = null),
                  ),
                  TextField(
                    key: const ValueKey('hotel-laundry-provider-contact'),
                    controller: contact,
                    enabled: !saving,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Contato (opcional)',
                    ),
                    onChanged: (_) => setLocal(() => error = null),
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('hotel-laundry-provider-active'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativa'),
                    subtitle: const Text(
                      'Inativas não aparecem em novos envios.',
                    ),
                    value: active,
                    onChanged: saving
                        ? null
                        : (bool value) => setLocal(() => active = value),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('hotel-laundry-provider-save'),
                onPressed: !valid || saving
                    ? null
                    : () async {
                        if (provider?.active == true && !active) {
                          final bool confirm =
                              await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title: const Text('Desativar lavanderia'),
                                  content: const Text(
                                    'Ela não aparecerá em novos envios. O histórico será preservado.',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Voltar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Desativar'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!confirm) return;
                        }
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        final CreateLaundryProviderRequest request =
                            CreateLaundryProviderRequest(
                              name: name.text.trim(),
                              contact: contact.text.trim().isEmpty
                                  ? null
                                  : contact.text.trim(),
                              active: active,
                            );
                        try {
                          if (provider == null) {
                            await widget.service.createProvider(request);
                          } else {
                            await widget.service.updateProvider(
                              provider.id,
                              request,
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } on Object catch (failure) {
                          setLocal(() {
                            saving = false;
                            error =
                                failure is ApiException &&
                                    failure.statusCode == 409
                                ? 'Já existe outra lavanderia com esse nome.'
                                : failure is ApiException
                                ? failure.message
                                : 'Não foi possível salvar a lavanderia.';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        name.dispose();
        contact.dispose();
      });
    });
    if (saved == true && mounted) {
      await _reload();
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label),
            const SizedBox(height: 6),
            Text(
              _number(value),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

double _quantity(String? raw) =>
    double.tryParse((raw ?? '').replaceAll(',', '.')) ?? 0;
String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
String _dateTime(DateTime value) =>
    '${value.toLocal().day.toString().padLeft(2, '0')}/${value.toLocal().month.toString().padLeft(2, '0')}/${value.toLocal().year}';
String _date(DateTime value) => _dateTime(value);
String _inventoryAction(HotelLaundryInventoryMovement movement) =>
    switch (movement.movementType) {
      'ITEM_RETIREMENT' || 'WITHDRAWAL' => 'Dado de baja',
      'ADJUSTMENT' when movement.quantity < 0 => 'Dado de baja',
      _ => 'Agregado',
    };
String _documentType(String value) =>
    value == 'REWASH_DISPATCH' ? 'Relavagem' : 'Envio';
String _status(String value) => switch (value) {
  'DRAFT' => 'Rascunho',
  'SUBMITTED' => 'Enviado',
  'CONFIRMED' => 'Confirmado',
  'OBSERVED' => 'Observado',
  _ => value,
};
