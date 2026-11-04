import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../application/provider_laundry_app_service.dart';
import '../domain/provider_laundry_models.dart';

class ProviderLaundryPage extends StatefulWidget {
  const ProviderLaundryPage({required this.service, super.key});

  final ProviderLaundryAppService service;

  @override
  State<ProviderLaundryPage> createState() => _ProviderLaundryPageState();
}

class _ProviderLaundryPageState extends State<ProviderLaundryPage> {
  bool _loading = true;
  String? _error;
  List<ProviderLaundryDocumentSummary> _documents = const [];
  List<ProviderLaundryReturnSummary> _returns = const [];
  List<ProviderLaundryStockRow> _processing = const [];
  List<ProviderLaundryStockRow> _rewash = const [];

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
      final results = await Future.wait<Object>(<Future<Object>>[
        widget.service.listDocuments(),
        widget.service.listReturns(),
        widget.service.listStock(bucket: ProviderLaundryStockBucket.processing),
        widget.service.listStock(bucket: ProviderLaundryStockBucket.rewash),
      ]);
      if (!mounted) return;
      setState(() {
        _documents =
            (results[0]
                    as ProviderLaundryResultPage<
                      ProviderLaundryDocumentSummary
                    >)
                .items;
        _returns =
            (results[1]
                    as ProviderLaundryResultPage<ProviderLaundryReturnSummary>)
                .items;
        _processing =
            (results[2] as ProviderLaundryResultPage<ProviderLaundryStockRow>)
                .items;
        _rewash =
            (results[3] as ProviderLaundryResultPage<ProviderLaundryStockRow>)
                .items;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Não foi possível carregar os dados da lavanderia.';
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
            Text(_error!, key: const ValueKey('provider-laundry-error')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('provider-laundry-portal'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
        children: <Widget>[
          Text(
            'Portal da lavanderia',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CostaNorteBrand.royalBlueDeep,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Acompanhe envios, devoluções e peças em processamento.'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('provider-return-create'),
              onPressed: () => _editReturn(),
              icon: const Icon(Icons.add),
              label: const Text('Nova devolução'),
            ),
          ),
          const SizedBox(height: 18),
          _StockOverview(processing: _processing, rewash: _rewash),
          const SizedBox(height: 20),
          _Section(
            title: 'Envios por confirmar',
            emptyMessage: 'Nenhum envio pendente.',
            children: _documents
                .map(
                  (ProviderLaundryDocumentSummary item) => _SummaryTile(
                    title: item.reference,
                    subtitle: _documentType(item.documentType),
                    status: _status(item.status),
                    date: item.effectiveAt,
                    onTap: () => _openDocument(item.id),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Devoluções',
            emptyMessage: 'Nenhuma devolução registrada.',
            children: _returns
                .map(
                  (ProviderLaundryReturnSummary item) => _SummaryTile(
                    title: item.reference,
                    subtitle: 'Devolução',
                    status: _status(item.status),
                    date: item.effectiveAt,
                    onTap: () => _openReturn(item.id),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(int id) async {
    late final ProviderLaundryDocument document;
    try {
      document = await widget.service.getDocument(id);
    } on Object catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    }
    if (!mounted) return;
    final _DocumentDecision? decision = await showDialog<_DocumentDecision>(
      context: context,
      builder: (BuildContext context) => _DocumentDialog(document: document),
    );
    if (decision == null || !mounted) return;

    String? notes;
    if (decision == _DocumentDecision.observe) {
      notes = await _requestObservation();
      if (notes == null || !mounted) return;
    }
    try {
      if (decision == _DocumentDecision.acknowledge) {
        await widget.service.acknowledgeDocument(
          id: document.id,
          version: document.version,
        );
      } else {
        await widget.service.observeDocument(
          id: document.id,
          version: document.version,
          notes: notes!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == _DocumentDecision.acknowledge
                ? 'Envio confirmado.'
                : 'Observação enviada.',
          ),
        ),
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<String?> _requestObservation() async {
    final TextEditingController controller = TextEditingController();
    String? validation;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Observar envio'),
              content: TextField(
                key: const ValueKey('provider-document-observation'),
                controller: controller,
                maxLength: 500,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Motivo da observação',
                  errorText: validation,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final String notes = controller.text.trim();
                    if (notes.isEmpty) {
                      setDialogState(
                        () => validation = 'Informe o motivo da observação.',
                      );
                      return;
                    }
                    Navigator.pop(context, notes);
                  },
                  child: const Text('Enviar observação'),
                ),
              ],
            ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    final String message = error is ApiException
        ? error.message
        : 'Não foi possível concluir a operação.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openReturn(int id) async {
    late final ProviderLaundryReturn manifest;
    try {
      manifest = await widget.service.getReturn(id);
    } on Object catch (error) {
      if (!mounted) return;
      _showError(error);
      return;
    }
    if (!mounted) return;
    final _ReturnAction? action = await showDialog<_ReturnAction>(
      context: context,
      builder: (BuildContext context) => _ReturnDialog(manifest: manifest),
    );
    if (action == _ReturnAction.edit && mounted) {
      await _editReturn(existing: manifest);
    } else if (action == _ReturnAction.submit && mounted) {
      try {
        await widget.service.submitReturn(
          id: manifest.id,
          version: manifest.version,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devolução enviada ao hotel.')),
        );
        await _load();
      } on Object catch (error) {
        if (!mounted) return;
        _showError(error);
      }
    }
  }

  Future<void> _editReturn({ProviderLaundryReturn? existing}) async {
    final Map<int, ProviderLaundryStockRow> available =
        <int, ProviderLaundryStockRow>{};
    for (final ProviderLaundryStockRow row in <ProviderLaundryStockRow>[
      ..._processing,
      ..._rewash,
    ]) {
      available.putIfAbsent(row.itemId, () => row);
    }
    for (final ProviderLaundryReturnLine line
        in existing?.lines ?? const <ProviderLaundryReturnLine>[]) {
      available.putIfAbsent(
        line.itemId,
        () => ProviderLaundryStockRow(
          itemId: line.itemId,
          itemName: line.itemName,
          unitType: 'PIECE',
          bucket: ProviderLaundryStockBucket.processing.apiValue,
          quantity: line.declaredClean + line.declaredRetained,
          ageDays: 0,
          version: 0,
        ),
      );
    }
    final ProviderLaundryReturnInput? input =
        await showDialog<ProviderLaundryReturnInput>(
          context: context,
          builder: (BuildContext context) => _ReturnFormDialog(
            availableItems: available.values.toList(growable: false),
            existing: existing,
          ),
        );
    if (input == null || !mounted) return;
    try {
      if (existing == null) {
        await widget.service.createReturn(input);
      } else {
        await widget.service.updateReturn(id: existing.id, input: input);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Devolução criada.' : 'Rascunho atualizado.',
          ),
        ),
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }
}

class _StockOverview extends StatelessWidget {
  const _StockOverview({required this.processing, required this.rewash});

  final List<ProviderLaundryStockRow> processing;
  final List<ProviderLaundryStockRow> rewash;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      _StockCard(
        label: 'Em processamento',
        value: _total(processing),
        oldestDays: _oldest(processing),
        icon: Icons.local_laundry_service_outlined,
      ),
      _StockCard(
        label: 'Em relavagem',
        value: _total(rewash),
        oldestDays: _oldest(rewash),
        icon: Icons.refresh_rounded,
      ),
    ],
  );

  static double _total(List<ProviderLaundryStockRow> rows) => rows.fold(
    0,
    (double total, ProviderLaundryStockRow row) => total + row.quantity,
  );

  static int _oldest(List<ProviderLaundryStockRow> rows) => rows.fold(
    0,
    (int days, ProviderLaundryStockRow row) =>
        row.ageDays > days ? row.ageDays : days,
  );
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.label,
    required this.value,
    required this.oldestDays,
    required this.icon,
  });

  final String label;
  final double value;
  final int oldestDays;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: CostaNorteBrand.royalBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label),
                  Text(
                    _quantity(value),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Mais antigo: $oldestDays dia(s)'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (children.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(emptyMessage),
          ),
        )
      else
        ...children,
    ],
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(title),
      subtitle: Text('$subtitle · ${_date(date)}'),
      trailing: Chip(label: Text(status)),
    ),
  );
}

enum _DocumentDecision { acknowledge, observe }

enum _ReturnAction { edit, submit }

class _DocumentDialog extends StatelessWidget {
  const _DocumentDialog({required this.document});

  final ProviderLaundryDocument document;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(document.reference),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_documentType(document.documentType)} · ${_status(document.status)}',
            ),
            Text('Data: ${_date(document.effectiveAt)}'),
            if (document.notes != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(document.notes!),
            ],
            const Divider(height: 28),
            Text('Peças', style: Theme.of(context).textTheme.titleMedium),
            ...document.lines.map(
              (ProviderLaundryDocumentLine line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.itemName),
                trailing: Text(_quantity(line.quantity)),
              ),
            ),
            if (document.confirmations.isNotEmpty) ...<Widget>[
              const Divider(height: 28),
              Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
              ...document.confirmations.map(
                (ProviderLaundryConfirmation item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_status(item.action)),
                  subtitle: item.notes == null ? null : Text(item.notes!),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
      if (document.canDecide) ...<Widget>[
        OutlinedButton(
          key: const ValueKey('provider-document-observe'),
          onPressed: () => Navigator.pop(context, _DocumentDecision.observe),
          child: const Text('Observar'),
        ),
        FilledButton(
          key: const ValueKey('provider-document-acknowledge'),
          onPressed: () =>
              Navigator.pop(context, _DocumentDecision.acknowledge),
          child: const Text('Confirmar envio'),
        ),
      ],
    ],
  );
}

class _ReturnDialog extends StatelessWidget {
  const _ReturnDialog({required this.manifest});

  final ProviderLaundryReturn manifest;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(manifest.reference),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_status(manifest.status)} · ${_date(manifest.effectiveAt)}',
            ),
            if (manifest.notes != null) Text(manifest.notes!),
            const Divider(height: 28),
            ...manifest.lines.map(
              (ProviderLaundryReturnLine line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.itemName),
                subtitle: Text(
                  'Limpas: ${_quantity(line.declaredClean)} · Retidas: ${_quantity(line.declaredRetained)}',
                ),
              ),
            ),
            if (manifest.correctionNotes != null) ...<Widget>[
              const Divider(height: 28),
              Text('Correção do hotel: ${manifest.correctionNotes}'),
            ],
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
      if (manifest.isDraft) ...<Widget>[
        OutlinedButton(
          onPressed: () => Navigator.pop(context, _ReturnAction.edit),
          child: const Text('Editar'),
        ),
        FilledButton(
          key: const ValueKey('provider-return-submit'),
          onPressed: () => Navigator.pop(context, _ReturnAction.submit),
          child: const Text('Enviar ao hotel'),
        ),
      ],
    ],
  );
}

class _ReturnFormDialog extends StatefulWidget {
  const _ReturnFormDialog({required this.availableItems, this.existing});

  final List<ProviderLaundryStockRow> availableItems;
  final ProviderLaundryReturn? existing;

  @override
  State<_ReturnFormDialog> createState() => _ReturnFormDialogState();
}

class _ReturnFormDialogState extends State<_ReturnFormDialog> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes,
  );
  late final Map<int, _ReturnLineControllers> _lines =
      <int, _ReturnLineControllers>{
        for (final ProviderLaundryStockRow item in widget.availableItems)
          item.itemId: _ReturnLineControllers(
            clean: _existingLine(item.itemId)?.declaredClean ?? 0,
            retained: _existingLine(item.itemId)?.declaredRetained ?? 0,
          ),
      };
  late DateTime _effectiveAt = widget.existing?.effectiveAt ?? DateTime.now();
  String? _error;

  ProviderLaundryReturnLine? _existingLine(int itemId) {
    for (final ProviderLaundryReturnLine line
        in widget.existing?.lines ?? const <ProviderLaundryReturnLine>[]) {
      if (line.itemId == itemId) return line;
    }
    return null;
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final _ReturnLineControllers line in _lines.values) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Nova devolução' : 'Editar devolução',
    ),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Data: ${_date(_effectiveAt)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Observação opcional',
              ),
            ),
            for (final ProviderLaundryStockRow item in widget.availableItems)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.itemName),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: ValueKey('return-clean-${item.itemId}'),
                              controller: _lines[item.itemId]!.clean,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Limpas',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: ValueKey('return-retained-${item.itemId}'),
                              controller: _lines[item.itemId]!.retained,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Retidas',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('provider-return-save'),
        onPressed: _save,
        child: const Text('Salvar rascunho'),
      ),
    ],
  );

  Future<void> _selectDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(
      () => _effectiveAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _effectiveAt.hour,
        _effectiveAt.minute,
      ),
    );
  }

  void _save() {
    final List<ProviderLaundryReturnLineInput> inputs = [];
    for (final MapEntry<int, _ReturnLineControllers> entry in _lines.entries) {
      final double? clean = _parseQuantity(entry.value.clean.text);
      final double? retained = _parseQuantity(entry.value.retained.text);
      if (clean == null || retained == null || clean < 0 || retained < 0) {
        setState(
          () => _error = 'Informe apenas quantidades válidas e não negativas.',
        );
        return;
      }
      if (clean + retained > 0) {
        inputs.add(
          ProviderLaundryReturnLineInput(
            itemId: entry.key,
            declaredClean: clean,
            declaredRetained: retained,
          ),
        );
      }
    }
    if (inputs.isEmpty) {
      setState(() => _error = 'Informe pelo menos uma quantidade.');
      return;
    }
    Navigator.pop(
      context,
      ProviderLaundryReturnInput(
        version: widget.existing?.version ?? 0,
        effectiveAt: _effectiveAt,
        notes: _notes.text,
        lines: inputs,
      ),
    );
  }
}

class _ReturnLineControllers {
  _ReturnLineControllers({required double clean, required double retained})
    : clean = TextEditingController(text: _editableQuantity(clean)),
      retained = TextEditingController(text: _editableQuantity(retained));

  final TextEditingController clean;
  final TextEditingController retained;

  void dispose() {
    clean.dispose();
    retained.dispose();
  }
}

String _documentType(String value) => switch (value) {
  'STANDARD_DISPATCH' => 'Envio normal',
  'REWASH_DISPATCH' => 'Envio para relavagem',
  _ => value,
};

String _status(String value) => switch (value) {
  'DRAFT' => 'Rascunho',
  'SUBMITTED' => 'Pendente',
  'CONFIRMED' => 'Confirmado',
  'OBSERVED' => 'Observado',
  'RESOLVED' => 'Resolvido',
  'CONFIRMED_BY_HOTEL' => 'Confirmado pelo hotel',
  'PROVIDER_CONFIRMED' => 'Confirmado pela lavanderia',
  'PROVIDER_OBSERVED' => 'Observado pela lavanderia',
  _ => value,
};

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

double? _parseQuantity(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _editableQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

String _date(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
