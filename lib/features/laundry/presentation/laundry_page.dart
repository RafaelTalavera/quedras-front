import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../application/laundry_app_service.dart';
import '../domain/laundry_models.dart';

class LaundryPage extends StatefulWidget {
  const LaundryPage({required this.service, super.key});
  final LaundryAppService service;

  @override
  State<LaundryPage> createState() => _LaundryPageState();
}

class _LaundryPageState extends State<LaundryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _itemSearch = TextEditingController();
  List<LaundryProvider> _providers = const <LaundryProvider>[];
  List<LaundryItem> _items = const <LaundryItem>[];
  List<LaundryShipment> _shipments = const <LaundryShipment>[];
  List<LaundryShipment> _historyShipments = const <LaundryShipment>[];
  final Map<int, double> _quantities = <int, double>{};
  final Map<LaundryShipmentKind, Map<int, FocusNode>> _quantityFocusNodes =
      <LaundryShipmentKind, Map<int, FocusNode>>{};
  int? _providerId;
  DateTime _sentAt = DateTime.now();
  int? _historyProviderId;
  LaundryShipmentStatus? _historyStatus;
  DateTime? _historyDateFrom;
  DateTime? _historyDateTo;
  bool _loading = true;
  bool _historyLoading = false;
  bool _saving = false;
  String? _error;
  _LaundryItemStatusFilter _itemStatusFilter = _LaundryItemStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 9, vsync: this);
    _tabs.addListener(_refreshNavigation);
    _load();
  }

  void _refreshNavigation() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_refreshNavigation);
    _tabs.dispose();
    _notes.dispose();
    _itemSearch.dispose();
    for (final Map<int, FocusNode> nodes in _quantityFocusNodes.values) {
      for (final FocusNode node in nodes.values) {
        node.dispose();
      }
    }
    super.dispose();
  }

  FocusNode _quantityFocusNode(LaundryShipmentKind kind, int itemId) =>
      _quantityFocusNodes
          .putIfAbsent(kind, () => <int, FocusNode>{})
          .putIfAbsent(itemId, FocusNode.new);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Object> values = await Future.wait<Object>(<Future<Object>>[
        widget.service.listProviders(),
        widget.service.listItems(),
        widget.service.listShipments(),
      ]);
      if (!mounted) return;
      setState(() {
        _providers = (values[0] as List<LaundryProvider>)
            .where((LaundryProvider value) => value.active)
            .toList();
        _items = values[1] as List<LaundryItem>;
        _shipments = values[2] as List<LaundryShipment>;
        _historyShipments = values[2] as List<LaundryShipment>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Controle de lavanderia',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Envios, recebimentos e rastreabilidade das peças do hotel.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _LaundryActionButton(
                key: const ValueKey<String>('laundry-action-new-shipment'),
                selected: _tabs.index == 1,
                icon: Icons.add_box_outlined,
                label: 'Novo envio',
                onPressed: () => _tabs.animateTo(1),
              ),
              _LaundryActionButton(
                key: const ValueKey<String>('laundry-action-rewash'),
                selected: _tabs.index == 2,
                icon: Icons.replay_rounded,
                label: 'Relavagem',
                onPressed: () => _tabs.animateTo(2),
              ),
              _LaundryActionButton(
                key: const ValueKey<String>('laundry-action-receive'),
                selected: _tabs.index == 0,
                icon: Icons.inventory_rounded,
                label: 'Recebido',
                onPressed: () => _tabs.animateTo(0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Resumos', style: Theme.of(context).textTheme.titleMedium),
              OutlinedButton(
                onPressed: () => _tabs.animateTo(4),
                child: const Text('Envios registrados'),
              ),
              OutlinedButton(
                onPressed: () => _tabs.animateTo(5),
                child: const Text('Relavagens registradas'),
              ),
              OutlinedButton(
                onPressed: () => _tabs.animateTo(6),
                child: const Text('Recebimentos registrados'),
              ),
              PopupMenuButton<int>(
                key: const ValueKey<String>('laundry-secondary-menu'),
                tooltip: 'Consultas e configuração',
                onSelected: _tabs.animateTo,
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<int>>[
                      PopupMenuItem<int>(
                        value: 3,
                        child: Text('Resumo por data'),
                      ),
                      PopupMenuItem<int>(value: 7, child: Text('Histórico')),
                      PopupMenuItem<int>(
                        value: 8,
                        child: Text('Itens e preços'),
                      ),
                    ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.more_horiz_rounded),
                      SizedBox(width: 6),
                      Text('Consultas e configuração'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, retry: _load)
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _buildReceived(),
                      _buildNewShipment(),
                      _buildRewash(),
                      _buildSummaryByDate(),
                      _buildSent(LaundryShipmentKind.standard),
                      _buildSent(LaundryShipmentKind.rewash),
                      _buildReceptionSummary(),
                      _buildHistory(),
                      _buildItemsAdministration(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewash() => _buildShipmentForm(LaundryShipmentKind.rewash);

  Widget _buildReceived() => _buildShipmentForm(LaundryShipmentKind.receipt);

  Widget _buildSummaryByDate() {
    final List<_LaundryDailySummary> rows = _dailySummaries(_shipments);
    if (rows.isEmpty) {
      return const _EmptyState(
        icon: Icons.table_chart_outlined,
        message: 'Não há movimentações para resumir.',
      );
    }
    final _LaundryDailySummary totals = rows.fold(
      const _LaundryDailySummary(date: null),
      (_LaundryDailySummary total, _LaundryDailySummary row) => total.add(row),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Text(
            'Resumo de peças por data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text('As movimentações canceladas não estão incluídas.'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey<String>('laundry-daily-summary-table'),
              columns: const <DataColumn>[
                DataColumn(label: Text('Data')),
                DataColumn(label: Text('Recebidas'), numeric: true),
                DataColumn(label: Text('Enviadas'), numeric: true),
                DataColumn(label: Text('Relavadas'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: <DataRow>[
                ...rows.map(
                  (_LaundryDailySummary row) =>
                      _summaryDataRow(_displayDate(row.date!), row),
                ),
                _summaryDataRow('Totais', totals, total: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _summaryDataRow(
    String label,
    _LaundryDailySummary summary, {
    bool total = false,
  }) {
    final TextStyle? style = total
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    DataCell cell(String value) => DataCell(Text(value, style: style));
    return DataRow(
      key: ValueKey<String>(total ? 'laundry-summary-totals' : label),
      cells: <DataCell>[
        cell(label),
        cell(_quantityText(summary.received)),
        cell(_quantityText(summary.sent)),
        cell(_quantityText(summary.rewashed)),
        cell(_quantityText(summary.total)),
      ],
    );
  }

  List<_LaundryDailySummary> _dailySummaries(List<LaundryShipment> shipments) {
    final Map<DateTime, _LaundryDailySummary> grouped =
        <DateTime, _LaundryDailySummary>{};
    for (final LaundryShipment shipment in shipments) {
      if (shipment.status == LaundryShipmentStatus.cancelled ||
          shipment.sentAt == null) {
        continue;
      }
      final DateTime value = shipment.sentAt!.toLocal();
      final DateTime date = DateTime(value.year, value.month, value.day);
      grouped[date] = (grouped[date] ?? _LaundryDailySummary(date: date))
          .addShipment(shipment);
    }
    final List<_LaundryDailySummary> rows = grouped.values.toList();
    rows.sort(
      (_LaundryDailySummary a, _LaundryDailySummary b) =>
          b.date!.compareTo(a.date!),
    );
    return rows;
  }

  Widget _buildSent(LaundryShipmentKind kind) {
    final List<LaundryShipment> sent = _shipments
        .where(
          (LaundryShipment value) =>
              value.kind == kind &&
              value.status != LaundryShipmentStatus.pendingDispatch &&
              value.sentAt != null,
        )
        .toList();
    return _buildShipmentList(
      shipments: sent,
      emptyIcon: Icons.local_shipping_outlined,
      emptyMessage: kind == LaundryShipmentKind.rewash
          ? 'Não há relavagens registradas.'
          : 'Não há envios registrados.',
      primaryLabel: 'Detalhes',
      onOpen: (LaundryShipment shipment) => _openDetail(shipment.id),
    );
  }

  Widget _buildReceptionSummary() {
    final List<LaundryShipment> received = _shipments
        .where(
          (LaundryShipment value) => value.kind == LaundryShipmentKind.receipt,
        )
        .toList();
    return _buildShipmentList(
      shipments: received,
      emptyIcon: Icons.inventory_rounded,
      emptyMessage: 'Não há recebimentos registrados.',
      primaryLabel: 'Detalhes',
      onOpen: (LaundryShipment shipment) => _openDetail(shipment.id),
    );
  }

  Widget _buildShipmentList({
    required List<LaundryShipment> shipments,
    required IconData emptyIcon,
    required String emptyMessage,
    required String primaryLabel,
    required void Function(LaundryShipment shipment) onOpen,
  }) {
    if (shipments.isEmpty) {
      return _EmptyState(icon: emptyIcon, message: emptyMessage);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: shipments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, int index) {
          final LaundryShipment shipment = shipments[index];
          return _ShipmentCard(
            shipment: shipment,
            primaryLabel: primaryLabel,
            onOpen: () => onOpen(shipment),
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int>(
                key: const ValueKey<String>('laundry-history-provider'),
                initialValue: _historyProviderId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fornecedor'),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ..._providers.map(
                    (LaundryProvider provider) => DropdownMenuItem<int>(
                      value: provider.id,
                      child: Text(provider.name),
                    ),
                  ),
                ],
                onChanged: _historyLoading
                    ? null
                    : (int? value) =>
                          setState(() => _historyProviderId = value),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<LaundryShipmentStatus>(
                key: const ValueKey<String>('laundry-history-status'),
                initialValue: _historyStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: <DropdownMenuItem<LaundryShipmentStatus>>[
                  const DropdownMenuItem<LaundryShipmentStatus>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...LaundryShipmentStatus.values.map(
                    (LaundryShipmentStatus status) =>
                        DropdownMenuItem<LaundryShipmentStatus>(
                          value: status,
                          child: Text(status.label),
                        ),
                  ),
                ],
                onChanged: _historyLoading
                    ? null
                    : (LaundryShipmentStatus? value) =>
                          setState(() => _historyStatus = value),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('laundry-history-date-from'),
              onPressed: _historyLoading
                  ? null
                  : () => _selectHistoryDate(true),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _historyDateFrom == null
                    ? 'De'
                    : 'De ${_displayDate(_historyDateFrom!)}',
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('laundry-history-date-to'),
              onPressed: _historyLoading
                  ? null
                  : () => _selectHistoryDate(false),
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _historyDateTo == null
                    ? 'Até'
                    : 'Até ${_displayDate(_historyDateTo!)}',
              ),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('laundry-history-apply'),
              onPressed: _historyLoading ? null : _loadHistory,
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('Aplicar'),
            ),
            TextButton(
              key: const ValueKey<String>('laundry-history-clear'),
              onPressed: _historyLoading ? null : _clearHistoryFilters,
              child: const Text('Limpar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _historyLoading
              ? const Center(child: CircularProgressIndicator())
              : _historyShipments.isEmpty
              ? const _EmptyState(
                  icon: Icons.history,
                  message: 'Não há remessas para os filtros selecionados.',
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    itemCount: _historyShipments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, int index) => _ShipmentCard(
                      shipment: _historyShipments[index],
                      primaryLabel: 'Detalhes',
                      onOpen: () => _openDetail(_historyShipments[index].id),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _selectHistoryDate(bool from) async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: (from ? _historyDateFrom : _historyDateTo) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (from) {
        _historyDateFrom = selected;
        if (_historyDateTo != null && selected.isAfter(_historyDateTo!)) {
          _historyDateTo = selected;
        }
      } else {
        _historyDateTo = selected;
        if (_historyDateFrom != null && selected.isBefore(_historyDateFrom!)) {
          _historyDateFrom = selected;
        }
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final List<LaundryShipment> shipments = await widget.service
          .listShipments(
            status: _historyStatus,
            providerId: _historyProviderId,
            dateFrom: _historyDateFrom == null
                ? null
                : _apiDate(_historyDateFrom!),
            dateTo: _historyDateTo == null ? null : _apiDate(_historyDateTo!),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _historyShipments = shipments;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _historyLoading = false);
      _showError(_errorText(error));
    }
  }

  Future<void> _clearHistoryFilters() async {
    setState(() {
      _historyProviderId = null;
      _historyStatus = null;
      _historyDateFrom = null;
      _historyDateTo = null;
    });
    await _loadHistory();
  }

  Widget _buildItemsAdministration() {
    final String query = _itemSearch.text.trim().toLowerCase();
    final List<LaundryItem> visibleItems = _items.where((LaundryItem item) {
      final bool matchesName =
          query.isEmpty || item.name.toLowerCase().contains(query);
      final bool matchesStatus = switch (_itemStatusFilter) {
        _LaundryItemStatusFilter.all => true,
        _LaundryItemStatusFilter.active => item.active,
        _LaundryItemStatusFilter.inactive => !item.active,
      };
      return matchesName && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Itens de lavanderia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.icon(
              key: const ValueKey<String>('laundry-new-item'),
              onPressed: () => _openItemForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo item'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey<String>('laundry-item-search'),
                controller: _itemSearch,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<_LaundryItemStatusFilter>(
                key: const ValueKey<String>('laundry-item-status-filter'),
                initialValue: _itemStatusFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: _LaundryItemStatusFilter.values
                    .map(
                      (_LaundryItemStatusFilter value) =>
                          DropdownMenuItem<_LaundryItemStatusFilter>(
                            value: value,
                            child: Text(value.label),
                          ),
                    )
                    .toList(),
                onChanged: (_LaundryItemStatusFilter? value) {
                  if (value != null) {
                    setState(() => _itemStatusFilter = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibleItems.isEmpty
              ? const _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'Não há itens para os filtros selecionados.',
                )
              : RefreshIndicator(
                  onRefresh: _reloadItems,
                  child: ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) =>
                        _LaundryItemCard(
                          item: visibleItems[index],
                          onEdit: () => _openItemForm(visibleItems[index]),
                        ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _reloadItems() async {
    try {
      final List<LaundryItem> items = await widget.service.listItems();
      if (!mounted) {
        return;
      }
      setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        _showError(_errorText(error));
      }
    }
  }

  Future<void> _openItemForm([LaundryItem? item]) async {
    final _LaundryItemFormResult? result =
        await showDialog<_LaundryItemFormResult>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) =>
              _LaundryItemFormDialog(service: widget.service, item: item),
        );
    if (!mounted || result == null) {
      return;
    }
    await _reloadItems();
    if (!mounted) {
      return;
    }
    if (result.notFound) {
      _showWarning(
        'Item indisponível',
        'O item não existe mais. A lista foi atualizada.',
      );
    } else {
      _showSuccess(
        item == null ? 'Item criado' : 'Item atualizado',
        item == null ? 'Item criado.' : 'Item atualizado.',
      );
    }
  }

  Widget _buildNewShipment() =>
      _buildShipmentForm(LaundryShipmentKind.standard);

  Widget _buildShipmentForm(LaundryShipmentKind kind) {
    final bool isRewash = kind == LaundryShipmentKind.rewash;
    final bool isReceipt = kind == LaundryShipmentKind.receipt;
    final List<LaundryItem> activeItems = _items
        .where((LaundryItem item) => item.active)
        .toList();
    final List<MapEntry<LaundryItem, double>> selected = activeItems
        .map(
          (LaundryItem item) =>
              MapEntry<LaundryItem, double>(item, _quantities[item.id] ?? 0),
        )
        .where((MapEntry<LaundryItem, double> value) => value.value > 0)
        .toList();
    final double estimated = selected.fold(
      0,
      (double sum, MapEntry<LaundryItem, double> value) =>
          sum +
          (kind == LaundryShipmentKind.standard
              ? value.key.currentUnitPrice * value.value
              : 0),
    );
    return ListView(
      children: <Widget>[
        Text(
          isRewash
              ? 'Registrar relavagem'
              : isReceipt
              ? 'Registrar recebimento'
              : 'Registrar novo envio',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (isRewash || isReceipt)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Registre esta operação separadamente, com as peças e quantidades correspondentes.',
            ),
          )
        else
          const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: const ValueKey<String>('laundry-shipment-provider'),
          initialValue: _providerId,
          decoration: const InputDecoration(labelText: 'Fornecedor ativo'),
          items: _providers
              .map(
                (LaundryProvider provider) => DropdownMenuItem<int>(
                  value: provider.id,
                  child: Text(provider.name),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (int? value) => setState(() => _providerId = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('laundry-shipment-date'),
              onPressed: _saving ? null : _selectShipmentDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Data: ${_displayDate(_sentAt)}'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('laundry-shipment-time'),
              onPressed: _saving ? null : _selectShipmentTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text('Hora: ${_displayTime(_sentAt)}'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...activeItems.indexed.map(
          ((int, LaundryItem) entry) => _QuantityRow(
            item: entry.$2,
            focusNode: _quantityFocusNode(kind, entry.$2.id),
            textInputAction: entry.$1 == activeItems.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            value: _quantities[entry.$2.id] ?? 0,
            onChanged: (double value) =>
                setState(() => _quantities[entry.$2.id] = value),
            onSubmitted: () {
              if (entry.$1 < activeItems.length - 1) {
                _quantityFocusNode(
                  kind,
                  activeItems[entry.$1 + 1].id,
                ).requestFocus();
              } else if (!_saving) {
                _createShipment(kind);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          enabled: !_saving,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observação opcional'),
        ),
        const SizedBox(height: 16),
        if (selected.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Resumo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...selected.map(
                    (MapEntry<LaundryItem, double> value) => Text(
                      '${value.key.name}: ${_quantity(value.value, value.key.unitType)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kind != LaundryShipmentKind.standard
                        ? 'Valor: ${_money(0)} · SEM CUSTO'
                        : 'Valor estimado: ${_money(estimated)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('laundry-shipment-save'),
          onPressed: _saving ? null : () => _createShipment(kind),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            isRewash
                ? 'Salvar relavagem'
                : isReceipt
                ? 'Salvar recebimento'
                : 'Salvar envio',
          ),
        ),
      ],
    );
  }

  Future<void> _selectShipmentDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _sentAt,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Data do envio',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _sentAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _sentAt.hour,
        _sentAt.minute,
      );
    });
  }

  Future<void> _selectShipmentTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sentAt),
      helpText: 'Hora do envio',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _sentAt = DateTime(
        _sentAt.year,
        _sentAt.month,
        _sentAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  Future<void> _createShipment(LaundryShipmentKind kind) async {
    final List<CreateLaundryShipmentLineRequest> lines = _items
        .where(
          (LaundryItem item) => item.active && (_quantities[item.id] ?? 0) > 0,
        )
        .map(
          (LaundryItem item) => CreateLaundryShipmentLineRequest(
            itemId: item.id,
            quantity: _quantities[item.id]!,
          ),
        )
        .toList();
    if (_providerId == null || lines.isEmpty) {
      _showWarning(
        'Dados incompletos',
        'Selecione um fornecedor e pelo menos uma peça.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createShipment(
        CreateLaundryShipmentRequest(
          providerId: _providerId!,
          kind: kind,
          sentAt: _sentAt,
          notes: _notes.text,
          lines: lines,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _providerId = null;
        _sentAt = DateTime.now();
        _quantities.clear();
        _notes.clear();
      });
      await _load();
      if (!mounted) return;
      _tabs.animateTo(switch (kind) {
        LaundryShipmentKind.standard => 4,
        LaundryShipmentKind.rewash => 5,
        LaundryShipmentKind.receipt => 6,
      });
      _showSuccess(
        switch (kind) {
          LaundryShipmentKind.standard => 'Envio salvo',
          LaundryShipmentKind.rewash => 'Relavagem salva',
          LaundryShipmentKind.receipt => 'Recebimento salvo',
        },
        switch (kind) {
          LaundryShipmentKind.standard => 'Envio salvo.',
          LaundryShipmentKind.rewash => 'Relavagem salva sem custo.',
          LaundryShipmentKind.receipt => 'Recebimento salvo.',
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(_errorText(error));
      }
    }
  }

  Future<void> _openDetail(int id) async {
    try {
      LaundryShipment shipment = await widget.service.getShipment(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => _ShipmentDetailDialog(
          shipment: shipment,
          onDispatch: shipment.isPendingDispatch
              ? () {
                  Navigator.pop(dialogContext);
                  _dispatch(shipment);
                }
              : null,
          onCancel: shipment.status == LaundryShipmentStatus.sent
              ? () {
                  Navigator.pop(dialogContext);
                  _cancel(shipment);
                }
              : null,
          onAudit: () async {
            final events = await widget.service.shipmentAudit(shipment.id);
            if (dialogContext.mounted) {
              await showAuditTimelineDialog(
                context: dialogContext,
                title: 'Auditoria ${shipment.shipmentNumber}',
                events: events,
              );
            }
          },
        ),
      );
    } catch (error) {
      if (mounted) _showError(_errorText(error));
    }
  }

  Future<void> _dispatch(LaundryShipment shipment) async {
    final DispatchLaundryShipmentRequest? request =
        await showDialog<DispatchLaundryShipmentRequest>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DispatchDialog(shipment: shipment),
        );
    if (request == null || !mounted) return;
    try {
      await widget.service.dispatchShipment(shipment.id, request);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _tabs.animateTo(3);
      _showSuccess('Envio confirmado', 'Envio para relavagem confirmado.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        _showWarning(
          'Relavagem atualizada',
          'Outra operação modificou a relavagem. Os dados foram atualizados.',
        );
        await _load();
      } else {
        _showError(error.message);
      }
    }
  }

  Future<void> _cancel(LaundryShipment shipment) async {
    final TextEditingController controller = TextEditingController();
    final String? notes = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar remessa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo obrigatório'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Cancelar remessa'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null) return;
    try {
      await widget.service.cancelShipment(shipment.id, notes);
      await _load();
      if (mounted) {
        _showSuccess('Remessa cancelada', 'A remessa foi cancelada.');
      }
    } catch (error) {
      if (mounted) _showError(_errorText(error));
    }
  }

  void _showSuccess(String title, String message) {
    AppAlerts.success(context, title: title, message: message);
  }

  void _showWarning(String title, String message) {
    AppAlerts.warning(context, title: title, message: message);
  }

  void _showError(String message) {
    AppAlerts.error(
      context,
      title: 'Não foi possível concluir',
      message: message,
    );
  }
}

enum _LaundryItemStatusFilter {
  all('Todos'),
  active('Ativos'),
  inactive('Inativos');

  const _LaundryItemStatusFilter(this.label);
  final String label;
}

final class _LaundryItemFormResult {
  const _LaundryItemFormResult.saved() : notFound = false;
  const _LaundryItemFormResult.notFound() : notFound = true;
  final bool notFound;
}

class _LaundryItemCard extends StatelessWidget {
  const _LaundryItemCard({required this.item, required this.onEdit});
  final LaundryItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: item.active
          ? null
          : Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        avatar: Icon(
                          item.active
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                          size: 18,
                        ),
                        label: Text(item.active ? 'Ativo' : 'Inativo'),
                      ),
                    ],
                  ),
                  Text(
                    '${item.unitType.label} · Preço atual: ${_money(item.currentUnitPrice)}',
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: ValueKey<String>('laundry-edit-item-${item.id}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaundryItemFormDialog extends StatefulWidget {
  const _LaundryItemFormDialog({required this.service, this.item});
  final LaundryAppService service;
  final LaundryItem? item;

  @override
  State<_LaundryItemFormDialog> createState() => _LaundryItemFormDialogState();
}

class _LaundryItemFormDialogState extends State<_LaundryItemFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item?.name ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.item?.currentUnitPrice.toStringAsFixed(2) ?? '',
  );
  late LaundryUnitType _unitType =
      widget.item?.unitType ?? LaundryUnitType.piece;
  late bool _active = widget.item?.active ?? true;
  bool _saving = false;
  String? _serverError;

  bool get _isValid {
    final String name = _name.text.trim();
    final String priceText = _price.text.trim().replaceAll(',', '.');
    final double? price = double.tryParse(priceText);
    return name.isNotEmpty &&
        name.length <= 120 &&
        price != null &&
        price >= 0 &&
        RegExp(r'^\d+(?:[\.,]\d{1,2})?$').hasMatch(_price.text.trim());
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.item != null;
    return AlertDialog(
      title: Text(editing ? 'Editar item' : 'Novo item'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('laundry-item-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 120,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (_) => setState(() => _serverError = null),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<LaundryUnitType>(
                key: const ValueKey<String>('laundry-item-unit'),
                initialValue: _unitType,
                decoration: const InputDecoration(labelText: 'Unidade'),
                items: LaundryUnitType.values
                    .map(
                      (LaundryUnitType type) =>
                          DropdownMenuItem<LaundryUnitType>(
                            value: type,
                            child: Text(type.label),
                          ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (LaundryUnitType? value) {
                        if (value != null) {
                          setState(() => _unitType = value);
                        }
                      },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey<String>('laundry-item-price'),
                controller: _price,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Preço atual'),
                onChanged: (_) => setState(() => _serverError = null),
              ),
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                key: const ValueKey<String>('laundry-item-active'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text(
                  'Itens inativos não aparecem em novos envios.',
                ),
                value: _active,
                onChanged: _saving
                    ? null
                    : (bool value) => setState(() => _active = value),
              ),
              if (_serverError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _serverError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey<String>('laundry-item-save'),
          onPressed: !_isValid || _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_isValid || _saving) {
      return;
    }
    if (widget.item?.active == true && !_active) {
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Desativar item'),
              content: const Text(
                'O item deixará de estar disponível para novos envios. Os envios históricos não serão alterados.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Desativar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) {
        return;
      }
    }
    setState(() {
      _saving = true;
      _serverError = null;
    });
    final LaundryItem draft = LaundryItem(
      id: widget.item?.id ?? 0,
      name: _name.text.trim(),
      unitType: _unitType,
      currentUnitPrice: double.parse(_price.text.trim().replaceAll(',', '.')),
      active: _active,
    );
    try {
      if (widget.item == null) {
        await widget.service.createItem(draft);
      } else {
        await widget.service.updateItem(widget.item!.id, draft);
      }
      if (mounted) {
        Navigator.pop(context, const _LaundryItemFormResult.saved());
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 404 && widget.item != null) {
        Navigator.pop(context, const _LaundryItemFormResult.notFound());
        return;
      }
      setState(() {
        _saving = false;
        _serverError = error.statusCode == 409
            ? 'Já existe outro item com esse nome.'
            : error.message;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = _errorText(error);
        });
      }
    }
  }
}

class _LaundryActionButton extends StatelessWidget {
  const _LaundryActionButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = selected
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          );
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          );
  }
}

class _QuantityRow extends StatefulWidget {
  const _QuantityRow({
    required this.item,
    required this.value,
    required this.focusNode,
    required this.textInputAction,
    required this.onChanged,
    required this.onSubmitted,
  });
  final LaundryItem item;
  final double value;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<double> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<_QuantityRow> createState() => _QuantityRowState();
}

class _QuantityRowState extends State<_QuantityRow> {
  late final TextEditingController _controller = TextEditingController(
    text: _quantity(widget.value, widget.item.unitType),
  );

  @override
  void didUpdateWidget(covariant _QuantityRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.item.unitType != widget.item.unitType) {
      _controller.text = _quantity(widget.value, widget.item.unitType);
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.item.unitType.label} · ${_money(widget.item.currentUnitPrice)}',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.value <= 0
                ? null
                : () => widget.onChanged(
                    (widget.value -
                            (widget.item.unitType == LaundryUnitType.piece
                                ? 1
                                : 0.1))
                        .clamp(0, double.infinity),
                  ),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 72,
            child: TextFormField(
              key: ValueKey<String>('laundry-item-${widget.item.id}'),
              controller: _controller,
              focusNode: widget.focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                _QuantityInputFormatter(
                  allowDecimal: widget.item.unitType != LaundryUnitType.piece,
                ),
              ],
              textInputAction: widget.textInputAction,
              textAlign: TextAlign.center,
              onChanged: (String text) {
                final double? parsed = double.tryParse(
                  text.replaceAll(',', '.'),
                );
                if (parsed != null &&
                    parsed >= 0 &&
                    (widget.item.unitType != LaundryUnitType.piece ||
                        parsed == parsed.roundToDouble())) {
                  widget.onChanged(parsed);
                }
              },
              onFieldSubmitted: (_) => widget.onSubmitted(),
            ),
          ),
          IconButton(
            onPressed: () => widget.onChanged(
              widget.value +
                  (widget.item.unitType == LaundryUnitType.piece ? 1 : 0.1),
            ),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ),
  );
}

class _QuantityInputFormatter extends TextInputFormatter {
  const _QuantityInputFormatter({required this.allowDecimal});

  final bool allowDecimal;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final RegExp pattern = allowDecimal
        ? RegExp(r'^\d*(?:[.,]\d*)?$')
        : RegExp(r'^\d*$');
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.shipment,
    required this.primaryLabel,
    required this.onOpen,
  });
  final LaundryShipment shipment;
  final String primaryLabel;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      shipment.shipmentNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (shipment.kind != LaundryShipmentKind.standard)
                      Chip(label: Text(shipment.kind.label)),
                  ],
                ),
                Text(
                  shipment.kind == LaundryShipmentKind.receipt
                      ? '${shipment.providerName} · ${shipment.receivedAt == null ? '-' : _dateTime(shipment.receivedAt!)}'
                      : shipment.sentAt == null
                      ? '${shipment.providerName} · Envio pendente'
                      : '${shipment.providerName} · ${_dateTime(shipment.sentAt!)}',
                ),
                Text(
                  '${shipment.kind == LaundryShipmentKind.receipt ? 'Recebido' : 'Enviado'}: ${_quantity(shipment.totalQuantity, LaundryUnitType.kilogram)} · Pendente: ${_quantity(shipment.pendingQuantity, LaundryUnitType.kilogram)} · ${shipment.kind == LaundryShipmentKind.receipt ? 'Recebido' : shipment.status.label}',
                ),
                Text(
                  'Faturável: ${_money(shipment.displayedBillableAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: onOpen, child: Text(primaryLabel)),
        ],
      ),
    ),
  );
}

class _ShipmentDetailDialog extends StatelessWidget {
  const _ShipmentDetailDialog({
    required this.shipment,
    this.onDispatch,
    this.onCancel,
    required this.onAudit,
  });
  final LaundryShipment shipment;
  final VoidCallback? onDispatch, onCancel;
  final Future<void> Function() onAudit;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(shipment.shipmentNumber),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ...shipment.lines.map(
              (LaundryShipmentLine line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.itemName),
                trailing: Text(
                  _quantity(line.sentQuantity, line.unitType),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const Divider(),
            Text(
              'Total: ${_quantityText(shipment.totalQuantity)}',
              key: const ValueKey<String>('laundry-detail-total'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: onAudit, child: const Text('Auditoria')),
      if (onCancel != null)
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      if (onDispatch != null)
        FilledButton(
          onPressed: onDispatch,
          child: const Text('Confirmar envio'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  );
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.shipment});
  final LaundryShipment shipment;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  late final List<_ReceiveLineDraft> _lines = widget.shipment.lines
      .where((LaundryShipmentLine line) => line.pendingQuantity > 0)
      .map(_ReceiveLineDraft.new)
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final _ReceiveLineDraft line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Registrar recebimento · ${widget.shipment.shipmentNumber}'),
    content: SizedBox(
      width: 850,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${widget.shipment.providerName} · Classifique apenas o que chegou ao hotel.',
            ),
            const SizedBox(height: 12),
            for (final _ReceiveLineDraft draft in _lines)
              _ReceiveLineEditor(
                key: ValueKey<int>(draft.line.id),
                draft: draft,
                onChanged: () => setState(() => _error = null),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
        key: const ValueKey<String>('laundry-receive-confirm'),
        onPressed: _submit,
        child: const Text('Salvar recebimento'),
      ),
    ],
  );

  void _submit() {
    final List<ReceiveLaundryLineRequest> requests =
        <ReceiveLaundryLineRequest>[];
    for (final _ReceiveLineDraft draft in _lines) {
      final ReceiveLaundryLineRequest? request = draft.toRequest();
      if (request == null) {
        setState(() => _error = 'Revise as quantidades informadas.');
        return;
      }
      final String? validation = request.validate(draft.line.pendingQuantity);
      if (validation != null) {
        setState(() => _error = '${draft.line.itemName}: $validation');
        return;
      }
      requests.add(request);
    }
    if (requests.isEmpty) {
      setState(() => _error = 'A remessa não possui peças pendentes.');
      return;
    }
    Navigator.pop(
      context,
      ReceiveLaundryShipmentRequest(
        receivedAt: DateTime.now(),
        version: widget.shipment.version,
        lines: requests,
      ),
    );
  }
}

class _ReceiveLineDraft {
  _ReceiveLineDraft(this.line)
    : accepted = TextEditingController(
        text: _editableQuantity(line.pendingQuantity),
      ),
      missing = TextEditingController(text: '0'),
      damaged = TextEditingController(text: '0');

  final LaundryShipmentLine line;
  final TextEditingController accepted, missing, damaged;

  ReceiveLaundryLineRequest? toRequest() {
    final double? acceptedValue = _parseQuantity(accepted.text);
    final double? missingValue = _parseQuantity(missing.text);
    final double? damagedValue = _parseQuantity(damaged.text);
    if (acceptedValue == null || missingValue == null || damagedValue == null) {
      return null;
    }
    return ReceiveLaundryLineRequest(
      lineId: line.id,
      acceptedQuantity: acceptedValue,
      rewashQuantity: 0,
      missingQuantity: missingValue,
      damagedQuantity: damagedValue,
    );
  }

  void dispose() {
    accepted.dispose();
    missing.dispose();
    damaged.dispose();
  }
}

class _ReceiveLineEditor extends StatelessWidget {
  const _ReceiveLineEditor({
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final _ReceiveLineDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            draft.line.itemName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Pendente: ${_quantity(draft.line.pendingQuantity, draft.line.unitType)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _quantityField(
                'Aceito',
                draft.accepted,
                draft.line.id,
                'accepted',
                onChanged,
              ),
              _quantityField(
                'Faltante',
                draft.missing,
                draft.line.id,
                'missing',
                onChanged,
              ),
              _quantityField(
                'Danificado',
                draft.damaged,
                draft.line.id,
                'damaged',
                onChanged,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static Widget _quantityField(
    String label,
    TextEditingController controller,
    int lineId,
    String field,
    VoidCallback onChanged,
  ) => SizedBox(
    width: 125,
    child: TextField(
      key: ValueKey<String>('laundry-receive-$field-$lineId'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    ),
  );
}

double? _parseQuantity(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _editableQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({required this.shipment});
  final LaundryShipment shipment;

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final TextEditingController _notes = TextEditingController();
  DateTime _sentAt = DateTime.now();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Enviar ${widget.shipment.shipmentNumber} para relavagem'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${widget.shipment.providerName} · RELAVAGEM · SEM CUSTO'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('laundry-dispatch-date'),
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Data: ${_displayDate(_sentAt)}'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('laundry-dispatch-time'),
                onPressed: _selectTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Hora: ${_displayTime(_sentAt)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('laundry-dispatch-notes'),
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observação opcional'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Voltar'),
      ),
      FilledButton(
        key: const ValueKey<String>('laundry-dispatch-confirm'),
        onPressed: () => Navigator.pop(
          context,
          DispatchLaundryShipmentRequest(
            sentAt: _sentAt,
            version: widget.shipment.version,
            notes: _notes.text,
          ),
        ),
        child: const Text('Confirmar envio'),
      ),
    ],
  );

  Future<void> _selectDate() async {
    final DateTime? value = await showDatePicker(
      context: context,
      initialDate: _sentAt,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (value == null || !mounted) return;
    setState(() {
      _sentAt = DateTime(
        value.year,
        value.month,
        value.day,
        _sentAt.hour,
        _sentAt.minute,
      );
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sentAt),
    );
    if (value == null || !mounted) return;
    setState(() {
      _sentAt = DateTime(
        _sentAt.year,
        _sentAt.month,
        _sentAt.day,
        value.hour,
        value.minute,
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 48, color: CostaNorteBrand.royalBlue),
        const SizedBox(height: 10),
        Text(message),
      ],
    ),
  );
}

final class _LaundryDailySummary {
  const _LaundryDailySummary({
    required this.date,
    this.received = 0,
    this.sent = 0,
    this.rewashed = 0,
  });

  final DateTime? date;
  final double received;
  final double sent;
  final double rewashed;
  double get total => received + sent + rewashed;

  _LaundryDailySummary addShipment(LaundryShipment shipment) =>
      _LaundryDailySummary(
        date: date,
        received:
            received +
            (shipment.kind == LaundryShipmentKind.receipt
                ? shipment.totalQuantity
                : 0),
        sent:
            sent +
            (shipment.kind == LaundryShipmentKind.standard
                ? shipment.totalQuantity
                : 0),
        rewashed:
            rewashed +
            (shipment.kind == LaundryShipmentKind.rewash
                ? shipment.totalQuantity
                : 0),
      );

  _LaundryDailySummary add(_LaundryDailySummary other) => _LaundryDailySummary(
    date: date,
    received: received + other.received,
    sent: sent + other.sent,
    rewashed: rewashed + other.rewashed,
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}

String _errorText(Object error) => error is ApiException
    ? error.message
    : 'Não foi possível concluir a operação.';
String _money(double value) =>
    r'R$ ' + value.toStringAsFixed(2).replaceAll('.', ',');
String _quantity(double value, LaundryUnitType unit) =>
    unit == LaundryUnitType.piece
    ? value.toStringAsFixed(0)
    : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
String _quantityText(double value) => value
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
String _dateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _displayTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
