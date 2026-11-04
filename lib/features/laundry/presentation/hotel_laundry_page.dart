import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../application/hotel_laundry_app_service.dart';
import '../application/laundry_app_service.dart';
import '../domain/hotel_laundry_models.dart';
import '../domain/laundry_models.dart';
import '../domain/provider_laundry_models.dart';

class HotelLaundryPage extends StatefulWidget {
  const HotelLaundryPage({
    required this.service,
    required this.catalogService,
    super.key,
  });

  final HotelLaundryAppService service;
  final LaundryAppService catalogService;

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
        widget.catalogService.listProviders(),
        widget.catalogService.listItems(),
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
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'NÃ£o foi possÃ­vel carregar a lavanderia.';
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
                  OutlinedButton.icon(
                    key: const ValueKey('hotel-laundry-rewash'),
                    onPressed: _saving ? null : () => _showDispatch(true),
                    icon: const Icon(Icons.replay_outlined),
                    label: const Text('Enviar para relavagem'),
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
              _MetricCard('DisponÃ­vel', totals.hotelAvailable),
              _MetricCard('Na lavanderia', totals.providerProcessing),
              _MetricCard('Relavagem no hotel', totals.hotelRewashQueue),
              _MetricCard('Relavagem externa', totals.providerRewash),
              _MetricCard('Faltante', totals.missing),
              _MetricCard('Danificado', totals.damaged),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'DevoluÃ§Ãµes para confirmar (${_returns.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_returns.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhuma devoluÃ§Ã£o pendente.')),
            )
          else
            ..._returns.map(
              (HotelLaundryReturnSummary item) => Card(
                child: ListTile(
                  title: Text('${item.reference} Â· ${item.providerName}'),
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
                  title: Text('${item.reference} Â· ${item.providerName}'),
                  subtitle: Text(
                    '${_documentType(item.documentType)} Â· ${_status(item.status)} Â· ${_dateTime(item.effectiveAt)}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
                      ..._items.map(
                        (LaundryItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            key: ValueKey('hotel-dispatch-item-${item.id}'),
                            controller: quantities[item.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                          labelText: 'ObservaÃ§Ãµes',
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
              effectiveAt: DateTime.now(),
              notes: noteValue,
              lines: lines,
            ),
          );
      await widget.service.submitDocument(id: draft.id, version: draft.version);
    });
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
                      'Limpo: ${_number(line.declaredClean)} Â· Retido: ${_number(line.declaredRetained)}',
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
            child: const Text('Confirmar classificaÃ§Ã£o'),
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

  Future<void> _command(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      _message('OperaÃ§Ã£o concluÃ­da.');
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      _message(
        error is ApiException
            ? error.message
            : 'NÃ£o foi possÃ­vel concluir a operaÃ§Ã£o.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
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
String _documentType(String value) =>
    value == 'REWASH_DISPATCH' ? 'Relavagem' : 'Envio';
String _status(String value) => switch (value) {
  'DRAFT' => 'Rascunho',
  'SUBMITTED' => 'Enviado',
  'CONFIRMED' => 'Confirmado',
  'OBSERVED' => 'Observado',
  _ => value,
};
