import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audit/audit_models.dart';
import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/feedback/app_share.dart';
import '../../../core/files/file_save_result.dart';
import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/sync/schedule_sync_service.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../application/maintenance_app_service.dart';
import '../application/maintenance_daily_report_pdf_exporter.dart';
import '../domain/maintenance_models.dart';

enum MaintenanceSection { operationalSummary }

enum _MaintenanceQuickLauncher {
  elevators,
  airConditioning,
  internet,
  internal,
}

enum _ExecutiveSummaryFilter {
  allOpen,
  carryOver,
  urgent,
  scheduled,
  inProgress,
  unassigned,
}

class MaintenancePageController {
  _MaintenancePageState? _state;

  Future<void> scrollToSection(MaintenanceSection section) async {
    await _state?._scrollToSection(section);
  }

  void _attach(_MaintenancePageState state) {
    _state = state;
  }

  void _detach(_MaintenancePageState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({
    required this.maintenanceAppService,
    required this.scheduleSyncService,
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final MaintenanceAppService maintenanceAppService;
  final ScheduleSyncService scheduleSyncService;
  final MaintenancePageController? controller;
  final ValueChanged<MaintenanceSection>? onSectionChanged;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;
  List<MaintenanceLocation> _locations = const <MaintenanceLocation>[];
  List<MaintenanceProvider> _providers = const <MaintenanceProvider>[];
  List<MaintenanceOrder> _orders = const <MaintenanceOrder>[];
  MaintenanceDailyExecutiveReport? _executiveReport;
  late DateTime _selectedDate;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingProviders = false;
  bool _saving = false;
  bool _providersLoaded = false;
  bool _exportingDailyReport = false;
  bool _openingDailyReport = false;
  int? _sharingOrderId;
  int? _loadingHistoryOrderId;
  String? _errorMessage;
  int? _selectedOrderId;
  _ExecutiveSummaryFilter _executiveSummaryFilter =
      _ExecutiveSummaryFilter.allOpen;
  MaintenanceSection _currentSection = MaintenanceSection.operationalSummary;
  final MaintenanceDailyReportPdfExporter _dailyReportPdfExporter =
      DefaultMaintenanceDailyReportPdfExporter();

  static const List<_MaintenanceQuickLauncher> _quickLaunchers =
      <_MaintenanceQuickLauncher>[
        _MaintenanceQuickLauncher.elevators,
        _MaintenanceQuickLauncher.airConditioning,
        _MaintenanceQuickLauncher.internet,
        _MaintenanceQuickLauncher.internal,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _selectedDate = _today();
    _syncSubscription = widget.scheduleSyncService.events.listen(
      _handleSyncEvent,
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant MaintenancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    widget.controller?._detach(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(showLoading: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            eyebrow: 'Manutencao',
            title: '',
            icon: Icons.build_circle_rounded,
            photoAlignment: Alignment.centerRight,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saving ? null : () => _createOrder(),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Nova ordem'),
                ),
                ..._quickLaunchers.map(
                  (_MaintenanceQuickLauncher launcher) => OutlinedButton.icon(
                    onPressed: _saving ? null : () => _createOrder(launcher),
                    icon: Icon(_launcherIcon(launcher)),
                    label: Text(_launcherLabel(launcher)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _openPreventivePlans,
                  icon: const Icon(Icons.event_repeat_rounded),
                  label: const Text('Preventivos'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _loadingProviders
                      ? null
                      : _manageCatalogs,
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Catalogos'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickSelectedDate,
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Alterar dia'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...<Widget>[
            Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 18),
          ],
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[_buildExecutiveSummaryCard()],
            ),
        ],
      ),
    );
  }

  MaintenanceOrder? get _selectedOrder {
    if (_selectedOrderId == null) {
      return null;
    }
    for (final MaintenanceOrder order in _orders) {
      if (order.id == _selectedOrderId) {
        return order;
      }
    }
    return null;
  }

  List<MaintenanceOrder> get _dayOrders =>
      _orders
          .where(
            (MaintenanceOrder order) =>
                _sameDay(order.referenceDate, _selectedDate),
          )
          .toList()
        ..sort((MaintenanceOrder a, MaintenanceOrder b) {
          return a.referenceDate.compareTo(b.referenceDate);
        });

  List<MaintenanceOrder> get _openDayOrders =>
      _dayOrders.where(_isOrderOpenForExecutiveSummary).toList();

  Future<void> _scrollToSection(MaintenanceSection section) async {
    _setCurrentSection(section);
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _setCurrentSection(MaintenanceSection section) {
    if (_currentSection == section) {
      return;
    }
    _currentSection = section;
    widget.onSectionChanged?.call(section);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      if (showLoading) {
        _loading = true;
      } else {
        _refreshingData = true;
      }
      _errorMessage = null;
    });
    try {
      final Future<List<MaintenanceLocation>> locationsFuture = widget
          .maintenanceAppService
          .listLocations();
      final Future<List<MaintenanceOrder>> ordersFuture = widget
          .maintenanceAppService
          .listOrders(
            dateFrom: _formatDateApi(_selectedDate),
            dateTo: _formatDateApi(_selectedDate),
          );
      final Future<MaintenanceDailyExecutiveReport> executiveReportFuture =
          widget.maintenanceAppService.getDailyExecutiveReport(
            date: _formatDateApi(_selectedDate),
          );
      final List<MaintenanceLocation> locations = await locationsFuture;
      final List<MaintenanceOrder> orders = await ordersFuture;
      final MaintenanceDailyExecutiveReport executiveReport =
          await executiveReportFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = List<MaintenanceLocation>.of(locations)
          ..sort(_compareLocationCatalogOrder);
        _orders = orders;
        _executiveReport = executiveReport;
        _loading = false;
        _refreshingData = false;
        if (_selectedOrderId != null &&
            !_orders.any(
              (MaintenanceOrder order) => order.id == _selectedOrderId,
            )) {
          _selectedOrderId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshingData = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _loadProviders() async {
    if (_providersLoaded) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingProviders = true;
    });
    try {
      final List<MaintenanceProvider> providers = await widget
          .maintenanceAppService
          .listProviders();
      if (!mounted) {
        return;
      }
      setState(() {
        _providers = providers;
        _providersLoaded = true;
        _loadingProviders = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingProviders = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  bool _canAutoRefresh() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return mounted &&
        !_loading &&
        !_refreshingData &&
        !_loadingProviders &&
        !_saving &&
        (route?.isCurrent ?? true);
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain != ScheduleSyncDomain.maintenance || !_canAutoRefresh()) {
      return;
    }
    if (!_isRelevantSyncEvent(event)) {
      return;
    }
    unawaited(_load(showLoading: false));
  }

  bool _isRelevantSyncEvent(ScheduleSyncEvent event) {
    return event.affectsDay(_selectedDate) ||
        _mayAffectExecutiveCarryOver(event);
  }

  bool _mayAffectExecutiveCarryOver(ScheduleSyncEvent event) {
    final DateTime? start = event.dateFrom;
    final DateTime? end = event.dateTo;
    if (start == null && end == null) {
      return true;
    }
    final DateTime effectiveStart = DateTime(
      (start ?? end!).year,
      (start ?? end!).month,
      (start ?? end!).day,
    );
    final DateTime selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return effectiveStart.isBefore(selected);
  }

  Future<void> _pickSelectedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1, 1, 1),
      lastDate: DateTime(_selectedDate.year + 1, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _load(showLoading: false);
  }

  Widget _buildExecutiveSummaryCard() {
    final MaintenanceDailyExecutiveReport? executiveReport = _executiveReport;
    final List<MaintenanceOrder> openOrders =
        executiveReport?.allOpenOrders ?? _openDayOrders;
    final List<MaintenanceOrder> carryOverOrders =
        executiveReport?.carryOverOrders ?? const <MaintenanceOrder>[];
    final int urgentCount = openOrders
        .where(
          (MaintenanceOrder order) =>
              order.priority == MaintenancePriority.urgent,
        )
        .length;
    final int scheduledCount = openOrders
        .where(
          (MaintenanceOrder order) =>
              order.status == MaintenanceOrderStatus.scheduled,
        )
        .length;
    final int inProgressCount = openOrders
        .where(
          (MaintenanceOrder order) =>
              order.status == MaintenanceOrderStatus.inProgress,
        )
        .length;
    final int unassignedCount = openOrders
        .where((MaintenanceOrder order) => order.providerId == null)
        .length;
    final List<MaintenanceOrder> filteredOrders = _filterExecutiveOrders(
      openOrders: openOrders,
      carryOverOrders: carryOverOrders,
      filter: _executiveSummaryFilter,
    );
    final List<MaintenanceOrder> previewOrders = filteredOrders
        .take(5)
        .toList();
    final String filterTitle = _executiveSummaryFilterTitle(
      _executiveSummaryFilter,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Estado de ordenes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _exportingDailyReport || _openingDailyReport
                          ? null
                          : _downloadDailyReportPdf,
                      icon: Icon(
                        _exportingDailyReport
                            ? Icons.hourglass_top_rounded
                            : Icons.download_rounded,
                      ),
                      label: Text(
                        _exportingDailyReport ? 'Gerando PDF...' : 'Baixar PDF',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportingDailyReport || _openingDailyReport
                          ? null
                          : _openDailyReportForPrinting,
                      icon: Icon(
                        _openingDailyReport
                            ? Icons.hourglass_top_rounded
                            : Icons.print_rounded,
                      ),
                      label: Text(
                        _openingDailyReport ? 'Preparando...' : 'Imprimir',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _metricChip(
                    'Abiertas',
                    '${openOrders.length}',
                    Icons.assignment_late_rounded,
                    selected:
                        _executiveSummaryFilter ==
                        _ExecutiveSummaryFilter.allOpen,
                    onTap: () => _setExecutiveSummaryFilter(
                      _ExecutiveSummaryFilter.allOpen,
                    ),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricChip(
                    'Urgentes',
                    '$urgentCount',
                    Icons.priority_high_rounded,
                    selected:
                        _executiveSummaryFilter ==
                        _ExecutiveSummaryFilter.urgent,
                    onTap: () => _setExecutiveSummaryFilter(
                      _ExecutiveSummaryFilter.urgent,
                    ),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricChip(
                    'Agendadas',
                    '$scheduledCount',
                    Icons.event_available_rounded,
                    selected:
                        _executiveSummaryFilter ==
                        _ExecutiveSummaryFilter.scheduled,
                    onTap: () => _setExecutiveSummaryFilter(
                      _ExecutiveSummaryFilter.scheduled,
                    ),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricChip(
                    'Em andamento',
                    '$inProgressCount',
                    Icons.handyman_rounded,
                    selected:
                        _executiveSummaryFilter ==
                        _ExecutiveSummaryFilter.inProgress,
                    onTap: () => _setExecutiveSummaryFilter(
                      _ExecutiveSummaryFilter.inProgress,
                    ),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricChip(
                    'Sem prestador',
                    '$unassignedCount',
                    Icons.person_off_rounded,
                    selected:
                        _executiveSummaryFilter ==
                        _ExecutiveSummaryFilter.unassigned,
                    onTap: () => _setExecutiveSummaryFilter(
                      _ExecutiveSummaryFilter.unassigned,
                    ),
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (filteredOrders.isEmpty)
              _emptyBox(
                _executiveSummaryFilter == _ExecutiveSummaryFilter.allOpen
                    ? 'Nao ha ordens abertas para o dia selecionado. O PDF pode ser gerado mesmo assim como comprovante do painel vazio.'
                    : 'Nao ha ordens para o filtro "$filterTitle" no dia selecionado.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFB),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: CostaNorteBrand.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      filterTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...previewOrders.map(
                      (MaintenanceOrder order) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildExecutiveOrderRow(order),
                      ),
                    ),
                    if (filteredOrders.length > previewOrders.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'E mais ${filteredOrders.length - previewOrders.length} ordem(ns) no relatorio completo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveOrderRow(MaintenanceOrder order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          setState(() {
            _selectedOrderId = order.id;
          });
          await _openOrderActionDialog(order);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CostaNorteBrand.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.locationDisplayLabel} - ${order.providerLabel}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _statusPill(order),
                ],
              ),
              if (order.description != null &&
                  order.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    order.description!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CostaNorteBrand.mutedInk,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _tag(order.orderKind.label),
                  _tag(_orderScheduleLabel(order)),
                  _tag(order.serviceLabel),
                  if (order.priority == MaintenancePriority.urgent)
                    _tag('Urgente'),
                  if (order.assignedUsername != null &&
                      order.assignedUsername!.trim().isNotEmpty)
                    _tag('Atribuido: ${order.assignedUsername!}'),
                  if (order.guestLabel != null)
                    _tag('Hospede: ${order.guestLabel!}'),
                  _tag('Toque para ver detalhe'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _compareLocationCatalogOrder(
    MaintenanceLocation a,
    MaintenanceLocation b,
  ) {
    final int groupCompare = _locationCatalogGroup(
      a,
    ).compareTo(_locationCatalogGroup(b));
    if (groupCompare != 0) {
      return groupCompare;
    }
    final int? aNumericCode = _locationCatalogNumericCode(a);
    final int? bNumericCode = _locationCatalogNumericCode(b);
    if (aNumericCode != null &&
        bNumericCode != null &&
        aNumericCode != bNumericCode) {
      return aNumericCode.compareTo(bNumericCode);
    }
    final int codeCompare = a.code.toLowerCase().compareTo(
      b.code.toLowerCase(),
    );
    if (codeCompare != 0) {
      return codeCompare;
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  int _locationCatalogGroup(MaintenanceLocation location) {
    final String code = location.code.trim();
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return code.length <= 2 ? 1 : 0;
    }
    return 2;
  }

  int? _locationCatalogNumericCode(MaintenanceLocation location) {
    final String code = location.code.trim();
    return RegExp(r'^\d+$').hasMatch(code) ? int.tryParse(code) : null;
  }

  Widget _metricChip(
    String label,
    String value,
    IconData icon, {
    bool selected = false,
    VoidCallback? onTap,
    bool compact = false,
  }) {
    final Color borderColor = selected
        ? CostaNorteBrand.royalBlueDeep
        : CostaNorteBrand.line;
    final Color backgroundColor = selected
        ? CostaNorteBrand.royalBlue.withValues(alpha: 0.10)
        : CostaNorteBrand.mist;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: compact ? 16 : 18,
                color: CostaNorteBrand.royalBlueDeep,
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: compact ? TextAlign.center : TextAlign.start,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: compact ? 10 : null,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: compact ? TextAlign.center : TextAlign.start,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 16 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setExecutiveSummaryFilter(_ExecutiveSummaryFilter filter) {
    if (_executiveSummaryFilter == filter) {
      return;
    }
    setState(() {
      _executiveSummaryFilter = filter;
    });
  }

  List<MaintenanceOrder> _filterExecutiveOrders({
    required List<MaintenanceOrder> openOrders,
    required List<MaintenanceOrder> carryOverOrders,
    required _ExecutiveSummaryFilter filter,
  }) {
    switch (filter) {
      case _ExecutiveSummaryFilter.allOpen:
        return openOrders;
      case _ExecutiveSummaryFilter.carryOver:
        return carryOverOrders;
      case _ExecutiveSummaryFilter.urgent:
        return openOrders
            .where(
              (MaintenanceOrder order) =>
                  order.priority == MaintenancePriority.urgent,
            )
            .toList();
      case _ExecutiveSummaryFilter.scheduled:
        return openOrders
            .where(
              (MaintenanceOrder order) =>
                  order.status == MaintenanceOrderStatus.scheduled,
            )
            .toList();
      case _ExecutiveSummaryFilter.inProgress:
        return openOrders
            .where(
              (MaintenanceOrder order) =>
                  order.status == MaintenanceOrderStatus.inProgress,
            )
            .toList();
      case _ExecutiveSummaryFilter.unassigned:
        return openOrders
            .where((MaintenanceOrder order) => order.providerId == null)
            .toList();
    }
  }

  String _executiveSummaryFilterTitle(_ExecutiveSummaryFilter filter) {
    switch (filter) {
      case _ExecutiveSummaryFilter.allOpen:
        return 'Ordens abertas agora';
      case _ExecutiveSummaryFilter.carryOver:
        return 'Pendentes anteriores';
      case _ExecutiveSummaryFilter.urgent:
        return 'Ordens urgentes';
      case _ExecutiveSummaryFilter.scheduled:
        return 'Ordens agendadas';
      case _ExecutiveSummaryFilter.inProgress:
        return 'Ordens em andamento';
      case _ExecutiveSummaryFilter.unassigned:
        return 'Ordens sem prestador';
    }
  }

  MaintenanceDailyExecutiveReport _buildFilteredExecutiveReport() {
    final MaintenanceDailyExecutiveReport baseReport =
        _executiveReport ??
        MaintenanceDailyExecutiveReport(
          carryOverOpenCount: 0,
          dayOpenCount: _openDayOrders.length,
          totalOpenCount: _openDayOrders.length,
          urgentCount: _openDayOrders
              .where(
                (MaintenanceOrder order) =>
                    order.priority == MaintenancePriority.urgent,
              )
              .length,
          scheduledCount: _openDayOrders
              .where(
                (MaintenanceOrder order) =>
                    order.status == MaintenanceOrderStatus.scheduled,
              )
              .length,
          inProgressCount: _openDayOrders
              .where(
                (MaintenanceOrder order) =>
                    order.status == MaintenanceOrderStatus.inProgress,
              )
              .length,
          unassignedCount: _openDayOrders
              .where((MaintenanceOrder order) => order.providerId == null)
              .length,
          carryOverOrders: const <MaintenanceOrder>[],
          dayOpenOrders: _openDayOrders,
        );
    final List<MaintenanceOrder> filteredOrders = _filterExecutiveOrders(
      openOrders: baseReport.allOpenOrders,
      carryOverOrders: baseReport.carryOverOrders,
      filter: _executiveSummaryFilter,
    );
    final List<MaintenanceOrder> filteredCarryOver = filteredOrders
        .where(
          (MaintenanceOrder order) =>
              !_sameDay(order.referenceDate, _selectedDate),
        )
        .toList();
    final List<MaintenanceOrder> filteredDayOrders = filteredOrders
        .where(
          (MaintenanceOrder order) =>
              _sameDay(order.referenceDate, _selectedDate),
        )
        .toList();

    return MaintenanceDailyExecutiveReport(
      carryOverOpenCount: filteredCarryOver.length,
      dayOpenCount: filteredDayOrders.length,
      totalOpenCount: filteredOrders.length,
      urgentCount: filteredOrders
          .where(
            (MaintenanceOrder order) =>
                order.priority == MaintenancePriority.urgent,
          )
          .length,
      scheduledCount: filteredOrders
          .where(
            (MaintenanceOrder order) =>
                order.status == MaintenanceOrderStatus.scheduled,
          )
          .length,
      inProgressCount: filteredOrders
          .where(
            (MaintenanceOrder order) =>
                order.status == MaintenanceOrderStatus.inProgress,
          )
          .length,
      unassignedCount: filteredOrders
          .where((MaintenanceOrder order) => order.providerId == null)
          .length,
      carryOverOrders: filteredCarryOver,
      dayOpenOrders: filteredDayOrders,
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CostaNorteBrand.line),
        color: Colors.white,
      ),
      child: Text(message),
    );
  }

  Widget _statusPill(MaintenanceOrder order) {
    final Color color = switch (order.status) {
      MaintenanceOrderStatus.open => CostaNorteBrand.goldDeep,
      MaintenanceOrderStatus.assigned => CostaNorteBrand.royalBlue,
      MaintenanceOrderStatus.scheduled => CostaNorteBrand.royalBlueDeep,
      MaintenanceOrderStatus.inProgress => CostaNorteBrand.success,
      MaintenanceOrderStatus.completed => CostaNorteBrand.success,
      MaintenanceOrderStatus.cancelled => CostaNorteBrand.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        order.status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Future<void> _createOrder([_MaintenanceQuickLauncher? launcher]) async {
    await _loadProviders();
    if (!mounted) {
      return;
    }
    final List<MaintenanceProvider> activeProviders = _providers
        .where((MaintenanceProvider item) => item.active)
        .toList();
    final List<MaintenanceProvider> dialogProviders = _prioritizeProviders(
      activeProviders,
      launcher,
    );
    final int? initialProviderId = _initialProviderIdForLauncher(
      dialogProviders,
      launcher,
    );
    final _MaintenanceOrderDraft? draft =
        await showDialog<_MaintenanceOrderDraft>(
          context: context,
          builder: (BuildContext context) => _MaintenanceOrderDialog(
            locations: _locations
                .where((MaintenanceLocation item) => item.active)
                .toList(),
            providers: dialogProviders,
            initialProviderId: initialProviderId,
            launcherLabel: launcher == null ? null : _launcherLabel(launcher),
          ),
        );
    if (draft == null) {
      return;
    }
    await _saveOrderDraft(draft);
  }

  List<MaintenanceProvider> _prioritizeProviders(
    List<MaintenanceProvider> providers,
    _MaintenanceQuickLauncher? launcher,
  ) {
    if (launcher == null) {
      return providers;
    }
    final List<MaintenanceProvider> matching = <MaintenanceProvider>[];
    final List<MaintenanceProvider> remaining = <MaintenanceProvider>[];
    for (final MaintenanceProvider provider in providers) {
      if (_matchesLauncher(provider, launcher)) {
        matching.add(provider);
      } else {
        remaining.add(provider);
      }
    }
    return <MaintenanceProvider>[...matching, ...remaining];
  }

  int? _initialProviderIdForLauncher(
    List<MaintenanceProvider> providers,
    _MaintenanceQuickLauncher? launcher,
  ) {
    if (launcher == null) {
      return null;
    }
    for (final MaintenanceProvider provider in providers) {
      if (_matchesLauncher(provider, launcher)) {
        return provider.id;
      }
    }
    return null;
  }

  bool _matchesLauncher(
    MaintenanceProvider provider,
    _MaintenanceQuickLauncher launcher,
  ) {
    return switch (launcher) {
      _MaintenanceQuickLauncher.elevators =>
        provider.specialty == MaintenanceProviderSpecialty.elevators,
      _MaintenanceQuickLauncher.airConditioning =>
        provider.specialty == MaintenanceProviderSpecialty.airConditioning,
      _MaintenanceQuickLauncher.internet =>
        provider.specialty == MaintenanceProviderSpecialty.internet,
      _MaintenanceQuickLauncher.internal =>
        provider.providerType == MaintenanceProviderType.internal,
    };
  }

  String _launcherLabel(_MaintenanceQuickLauncher launcher) {
    return switch (launcher) {
      _MaintenanceQuickLauncher.elevators => 'Elevadores',
      _MaintenanceQuickLauncher.airConditioning => 'Ar-condicionado',
      _MaintenanceQuickLauncher.internet => 'Internet',
      _MaintenanceQuickLauncher.internal => 'Interno',
    };
  }

  IconData _launcherIcon(_MaintenanceQuickLauncher launcher) {
    return switch (launcher) {
      _MaintenanceQuickLauncher.elevators => Icons.elevator_rounded,
      _MaintenanceQuickLauncher.airConditioning => Icons.ac_unit_rounded,
      _MaintenanceQuickLauncher.internet => Icons.router_rounded,
      _MaintenanceQuickLauncher.internal => Icons.handyman_rounded,
    };
  }

  Future<void> _editOrder({MaintenanceOrder? order}) async {
    final MaintenanceOrder? selected = order ?? _selectedOrder;
    if (selected == null) {
      return;
    }
    if (selected.status == MaintenanceOrderStatus.inProgress) {
      await AppAlerts.info(
        context,
        title: 'Edicao bloqueada',
        message:
            'Ordens em andamento nao podem ser editadas neste fluxo. Para seguir, conclua ou cancele a ordem atual.',
      );
      return;
    }
    await _loadProviders();
    if (!mounted) {
      return;
    }
    final _MaintenanceOrderDraft? draft =
        await showDialog<_MaintenanceOrderDraft>(
          context: context,
          builder: (BuildContext context) => _MaintenanceOrderDialog(
            locations: _locations
                .where((MaintenanceLocation item) => item.active)
                .toList(),
            providers: _providers
                .where((MaintenanceProvider item) => item.active)
                .toList(),
            initialOrder: selected,
          ),
        );
    if (draft == null) {
      return;
    }
    await _saveOrderDraft(draft, editingOrderId: selected.id);
  }

  Future<void> _shareOrderToWhatsApp({MaintenanceOrder? order}) async {
    final MaintenanceOrder? selected = order ?? _selectedOrder;
    if (selected == null || _sharingOrderId != null) {
      return;
    }

    setState(() {
      _sharingOrderId = selected.id;
    });
    try {
      await AppShare.shareText(
        context,
        text: _buildOrderShareMessage(selected),
        subject: 'Ordem de manutencao ${selected.id}',
        failureTitle: 'Falha ao compartilhar ordem',
        failureMessagePrefix: 'Nao foi possivel preparar a mensagem da ordem',
      );
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharingOrderId = null;
        });
      }
    }
  }

  Future<void> _downloadDailyReportPdf() async {
    setState(() {
      _exportingDailyReport = true;
    });
    try {
      final MaintenanceDailyExecutiveReport report =
          _buildFilteredExecutiveReport();
      final String filterTitle = _executiveSummaryFilterTitle(
        _executiveSummaryFilter,
      );
      final FileSaveResult? result = await _dailyReportPdfExporter.savePdf(
        date: _selectedDate,
        report: report,
      );
      if (result == null || !mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'PDF salvo',
        message: result.hasLocalPath
            ? '$filterTitle salvo em:\n${result.path}'
            : 'Download do PDF de "$filterTitle" iniciado no navegador:\n${result.fileName}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao gerar PDF',
        message: 'Nao foi possivel salvar o resumo executivo: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingDailyReport = false;
        });
      }
    }
  }

  Future<void> _openDailyReportForPrinting() async {
    setState(() {
      _openingDailyReport = true;
    });
    try {
      final MaintenanceDailyExecutiveReport report =
          _buildFilteredExecutiveReport();
      final String filterTitle = _executiveSummaryFilterTitle(
        _executiveSummaryFilter,
      );
      final File file = await _dailyReportPdfExporter.createTemporaryPdf(
        date: _selectedDate,
        report: report,
      );
      await _openFileWithSystem(file.path);
      if (!mounted) {
        return;
      }
      await AppAlerts.info(
        context,
        title: 'PDF pronto para impressao',
        message:
            'O resumo "$filterTitle" foi aberto no visor PDF do sistema.\n\nArquivo temporario:\n${file.path}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao preparar impressao',
        message: 'Nao foi possivel abrir o resumo executivo: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingDailyReport = false;
        });
      }
    }
  }

  Future<void> _saveOrderDraft(
    _MaintenanceOrderDraft draft, {
    int? editingOrderId,
  }) async {
    setState(() {
      _saving = true;
    });
    try {
      if (draft.scheduledStartAt != null && draft.scheduledEndAt != null) {
        final List<MaintenanceConflict> conflicts = await widget
            .maintenanceAppService
            .findConflicts(
              locationId: draft.locationId,
              scheduledStartAt: _formatLocalDateTimeApi(
                draft.scheduledStartAt!,
              ),
              scheduledEndAt: _formatLocalDateTimeApi(draft.scheduledEndAt!),
              excludeOrderId: editingOrderId,
            );
        if (!mounted) {
          return;
        }
        if (conflicts.isNotEmpty) {
          final bool confirm = await AppAlerts.confirm(
            context,
            title: 'Conflito de agenda',
            message:
                'Ja existem ${conflicts.length} ordem(ns) para o mesmo local nessa faixa. O sistema permite seguir, mas a decisao fica com o operador.',
            confirmLabel: 'Continuar',
          );
          if (!confirm) {
            setState(() {
              _saving = false;
            });
            return;
          }
        }
      }

      final MaintenanceOrder savedOrder;
      if (editingOrderId == null) {
        savedOrder = await widget.maintenanceAppService.createOrder(
          draft.toCreateModel(),
        );
      } else {
        savedOrder = await widget.maintenanceAppService.updateOrder(
          editingOrderId,
          draft.toUpdateModel(),
        );
      }
      final _ProviderNotificationResult notificationResult =
          await _notifyProviderForSavedOrder(savedOrder);
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: editingOrderId == null ? 'Ordem criada' : 'Ordem atualizada',
        message:
            'A ordem de manutencao foi salva com sucesso.${notificationResult.userMessageSuffix}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao salvar ordem',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _startOrder() async {
    final MaintenanceOrder? order = _selectedOrder;
    if (order == null) {
      return;
    }
    final bool confirm = await AppAlerts.confirm(
      context,
      title: 'Iniciar ordem',
      message: 'Deseja iniciar a ordem selecionada agora?',
    );
    if (!confirm) {
      return;
    }
    await _runOrderMutation(
      () => widget.maintenanceAppService.startOrder(order.id),
      successTitle: 'Ordem iniciada',
    );
  }

  Future<void> _completeOrder() async {
    final MaintenanceOrder? order = _selectedOrder;
    if (order == null) {
      return;
    }
    final _CompletionDraft? draft = await showDialog<_CompletionDraft>(
      context: context,
      builder: (BuildContext context) => const _CompletionDialog(),
    );
    if (draft == null) {
      return;
    }
    await _runOrderMutation(
      () => widget.maintenanceAppService.completeOrder(
        order.id,
        CompleteMaintenanceOrderModel(
          completedAt: draft.completedAt?.toUtc().toIso8601String(),
          resolutionNotes: draft.resolutionNotes,
        ),
      ),
      successTitle: 'Ordem concluida',
    );
  }

  Future<void> _cancelOrder() async {
    final MaintenanceOrder? order = _selectedOrder;
    if (order == null) {
      return;
    }
    final String? notes = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _CancelDialog(),
    );
    if (notes == null) {
      return;
    }
    await _runOrderMutation(
      () => widget.maintenanceAppService.cancelOrder(
        order.id,
        CancelMaintenanceOrderModel(cancellationNotes: notes),
      ),
      successTitle: 'Ordem cancelada',
    );
  }

  Future<void> _runOrderMutation(
    Future<MaintenanceOrder> Function() action, {
    required String successTitle,
  }) async {
    setState(() {
      _saving = true;
    });
    try {
      await action();
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: successTitle,
        message: 'A operacao foi concluida com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha na operacao',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _manageCatalogs() async {
    await _loadProviders();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _MaintenanceCatalogsDialog(
        locations: _locations,
        providers: _providers,
        service: widget.maintenanceAppService,
      ),
    );
    if (!mounted) {
      return;
    }
    await _load(showLoading: false);
  }

  Future<void> _openPreventivePlans() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _PreventivePlansDialog(service: widget.maintenanceAppService),
    );
    if (!mounted) {
      return;
    }
    await _load(showLoading: false);
  }

  Future<void> _manageAttachments() async {
    final MaintenanceOrder? order = _selectedOrder;
    if (order == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _MaintenanceAttachmentsDialog(
        order: order,
        service: widget.maintenanceAppService,
      ),
    );
    if (!mounted) {
      return;
    }
    await _load(showLoading: false);
  }

  Future<void> _openOrderActionDialog(MaintenanceOrder order) async {
    final _MaintenanceOrderAction? action =
        await showDialog<_MaintenanceOrderAction>(
          context: context,
          builder: (BuildContext context) => _MaintenanceOrderActionDialog(
            order: order,
            sharing: _sharingOrderId == order.id,
            loadingHistory: _loadingHistoryOrderId == order.id,
          ),
        );
    if (action == null || !mounted) {
      return;
    }

    setState(() {
      _selectedOrderId = order.id;
    });
    switch (action) {
      case _MaintenanceOrderAction.edit:
        await _editOrder(order: order);
        return;
      case _MaintenanceOrderAction.share:
        await _shareOrderToWhatsApp(order: order);
        return;
      case _MaintenanceOrderAction.start:
        await _startOrder();
        return;
      case _MaintenanceOrderAction.complete:
        await _completeOrder();
        return;
      case _MaintenanceOrderAction.cancel:
        await _cancelOrder();
        return;
      case _MaintenanceOrderAction.attachments:
        await _manageAttachments();
        return;
      case _MaintenanceOrderAction.history:
        await _openOrderHistory(order);
        return;
    }
  }

  Future<void> _openOrderHistory(MaintenanceOrder order) async {
    setState(() {
      _loadingHistoryOrderId = order.id;
      _errorMessage = null;
    });
    try {
      final List<AuditEventModel> history = await widget.maintenanceAppService
          .history(order.id);
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${order.title}',
        events: history,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Historico da ordem',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingHistoryOrderId = null);
      }
    }
  }

  Future<MaintenanceOrder?> pickOrderForDay(
    String title, {
    bool Function(MaintenanceOrder order)? canSelect,
    String? emptyMessage,
  }) async {
    final List<MaintenanceOrder> items = canSelect == null
        ? _dayOrders
        : _dayOrders.where(canSelect).toList();
    if (items.isEmpty) {
      if (!mounted || emptyMessage == null) {
        return null;
      }
      await AppAlerts.info(context, title: title, message: emptyMessage);
      return null;
    }

    return showDialog<MaintenanceOrder>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(title),
        children: items
            .map(
              (MaintenanceOrder item) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(item),
                child: Text(
                  '${item.title} - ${item.locationDisplayLabel} - ${item.providerNameSnapshot}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _buildOrderShareMessage(MaintenanceOrder order) {
    MaintenanceProvider? provider;
    for (final MaintenanceProvider item in _providers) {
      if (order.providerId != null && item.id == order.providerId) {
        provider = item;
        break;
      }
    }
    final StringBuffer buffer = StringBuffer()
      ..writeln('Ordem de manutencao Hotel Costa Norte')
      ..writeln('Titulo: ${order.title}')
      ..writeln('Local: ${order.locationDisplayLabel}')
      ..writeln('Prestador: ${order.providerLabel}')
      ..writeln(
        'Contato: ${provider != null && (provider.contact ?? '').isNotEmpty ? provider.contact : 'nao informado'}',
      )
      ..writeln('Servico: ${order.serviceLabel}')
      ..writeln('Tipo: ${order.orderKind.label}')
      ..writeln('Prioridade tecnica: ${order.priority.label}')
      ..writeln('Origem: ${order.requestOrigin.label}')
      ..writeln('Status: ${order.status.label}')
      ..writeln('Agenda: ${_orderScheduleLabel(order)}');
    if (order.guestLabel != null) {
      buffer.writeln('Hospede: ${order.guestLabel}');
    }
    if (order.assignedUsername != null) {
      buffer.writeln('Atribuido a: ${order.assignedUsername}');
    }
    if (order.estimatedExecutionMinutes != null) {
      buffer.writeln('Tempo estimado: ${order.estimatedExecutionMinutes} min');
    }
    if ((order.description ?? '').trim().isNotEmpty) {
      buffer.writeln('Descricao: ${order.description!.trim()}');
    }
    return buffer.toString().trim();
  }

  Future<_ProviderNotificationResult> _notifyProviderForSavedOrder(
    MaintenanceOrder order,
  ) async {
    final MaintenanceProvider? provider = _findProviderById(order.providerId);
    if (provider == null) {
      return _ProviderNotificationResult.notConfigured(
        ' Nenhum prestador foi vinculado para envio por WhatsApp.',
      );
    }

    final String? whatsappNumber = _normalizeWhatsappNumber(provider.contact);
    if (whatsappNumber == null) {
      return _ProviderNotificationResult.notConfigured(
        ' O prestador "${provider.name}" nao possui WhatsApp valido cadastrado.',
      );
    }

    final String message = _buildOrderShareMessage(order);
    final Uri appUri = Uri.parse(
      'whatsapp://send?phone=$whatsappNumber&text=${Uri.encodeComponent(message)}',
    );
    final Uri webUri = Uri.parse(
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}',
    );

    try {
      final bool launchedApp = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedApp) {
        return const _ProviderNotificationResult.sent(
          ' WhatsApp aberto para envio ao prestador.',
        );
      }
    } catch (_) {
      // Fallback to WhatsApp Web below.
    }

    try {
      final bool launchedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedWeb) {
        return const _ProviderNotificationResult.sent(
          ' WhatsApp Web aberto para envio ao prestador.',
        );
      }
    } catch (_) {
      // Clipboard fallback below.
    }

    await Clipboard.setData(ClipboardData(text: message));
    return const _ProviderNotificationResult.fallback(
      ' Nao foi possivel abrir o WhatsApp; a mensagem foi copiada para a area de transferencia.',
    );
  }

  MaintenanceProvider? _findProviderById(int? providerId) {
    if (providerId == null) {
      return null;
    }
    for (final MaintenanceProvider provider in _providers) {
      if (provider.id == providerId) {
        return provider;
      }
    }
    return null;
  }
}

final class _ProviderNotificationResult {
  const _ProviderNotificationResult._(this.userMessageSuffix);

  const _ProviderNotificationResult.sent(String message) : this._(message);

  const _ProviderNotificationResult.notConfigured(String message)
    : this._(message);

  const _ProviderNotificationResult.fallback(String message) : this._(message);

  final String userMessageSuffix;
}

enum _MaintenanceOrderAction {
  edit,
  share,
  start,
  complete,
  cancel,
  attachments,
  history,
}

class _MaintenanceOrderActionDialog extends StatelessWidget {
  const _MaintenanceOrderActionDialog({
    required this.order,
    required this.sharing,
    required this.loadingHistory,
  });

  final MaintenanceOrder order;
  final bool sharing;
  final bool loadingHistory;

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        order.status != MaintenanceOrderStatus.inProgress &&
        order.status != MaintenanceOrderStatus.completed &&
        order.status != MaintenanceOrderStatus.cancelled;
    final bool canStart =
        order.status == MaintenanceOrderStatus.open ||
        order.status == MaintenanceOrderStatus.assigned ||
        order.status == MaintenanceOrderStatus.scheduled;
    final bool canComplete = order.status == MaintenanceOrderStatus.inProgress;
    final bool canCancel =
        order.status != MaintenanceOrderStatus.completed &&
        order.status != MaintenanceOrderStatus.cancelled;
    return AlertDialog(
      title: const Text('Ordem do dia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(order.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '${order.locationDisplayLabel} - ${order.providerLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.edit)
                    : null,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: sharing
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.share),
                icon: Icon(
                  sharing ? Icons.hourglass_top_rounded : Icons.send_rounded,
                ),
                label: Text(sharing ? 'Compartilhando...' : 'Compartilhar'),
              ),
              OutlinedButton.icon(
                onPressed: canStart
                    ? () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.start)
                    : null,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Iniciar'),
              ),
              OutlinedButton.icon(
                onPressed: canComplete
                    ? () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.complete)
                    : null,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Concluir'),
              ),
              OutlinedButton.icon(
                onPressed: canCancel
                    ? () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.cancel)
                    : null,
                icon: const Icon(Icons.cancel_schedule_send_rounded),
                label: const Text('Cancelar'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_MaintenanceOrderAction.attachments),
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Anexos'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_MaintenanceOrderAction.history),
                icon: loadingHistory
                    ? const Icon(Icons.hourglass_top_rounded)
                    : const Icon(Icons.history_rounded),
                label: Text(loadingHistory ? 'Carregando...' : 'Historico'),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

bool _isOrderOpenForExecutiveSummary(MaintenanceOrder order) {
  return order.status != MaintenanceOrderStatus.completed &&
      order.status != MaintenanceOrderStatus.cancelled;
}

Future<void> _openFileWithSystem(String path) async {
  if (Platform.isWindows) {
    await Process.start('cmd', <String>['/c', 'start', '', path]);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', <String>[path]);
    return;
  }
  if (Platform.isLinux) {
    await Process.start('xdg-open', <String>[path]);
    return;
  }
  throw UnsupportedError('Abertura de PDF nao suportada nesta plataforma.');
}

class _MaintenanceOrderDraft {
  const _MaintenanceOrderDraft({
    required this.locationId,
    required this.providerId,
    required this.planId,
    required this.orderKind,
    required this.title,
    required this.description,
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.guestName,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int locationId;
  final int? providerId;
  final int? planId;
  final MaintenanceOrderKind orderKind;
  final String title;
  final String? description;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? guestName;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  CreateMaintenanceOrderModel toCreateModel() {
    return CreateMaintenanceOrderModel(
      locationId: locationId,
      providerId: providerId,
      planId: planId,
      orderKind: orderKind,
      title: title,
      description: description,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      scheduledStartAt: scheduledStartAt == null
          ? null
          : _formatLocalDateTimeApi(scheduledStartAt!),
      scheduledEndAt: scheduledEndAt == null
          ? null
          : _formatLocalDateTimeApi(scheduledEndAt!),
    );
  }

  UpdateMaintenanceOrderModel toUpdateModel() {
    return UpdateMaintenanceOrderModel(
      locationId: locationId,
      providerId: providerId,
      planId: planId,
      orderKind: orderKind,
      title: title,
      description: description,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      scheduledStartAt: scheduledStartAt == null
          ? null
          : _formatLocalDateTimeApi(scheduledStartAt!),
      scheduledEndAt: scheduledEndAt == null
          ? null
          : _formatLocalDateTimeApi(scheduledEndAt!),
    );
  }
}

class _MaintenanceOrderDialog extends StatefulWidget {
  const _MaintenanceOrderDialog({
    required this.locations,
    required this.providers,
    this.initialOrder,
    this.initialProviderId,
    this.launcherLabel,
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenanceOrder? initialOrder;
  final int? initialProviderId;
  final String? launcherLabel;

  @override
  State<_MaintenanceOrderDialog> createState() =>
      _MaintenanceOrderDialogState();
}

class _MaintenanceOrderDialogState extends State<_MaintenanceOrderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late int _locationId;
  int? _providerId;
  late MaintenanceOrderKind _orderKind;
  late MaintenanceRequestOrigin _requestOrigin;
  late bool _hasSchedule;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _guestNameController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final MaintenanceOrder? order = widget.initialOrder;
    _locationId = order?.locationId ?? widget.locations.first.id;
    _providerId = order?.providerId ?? widget.initialProviderId;
    _orderKind = widget.launcherLabel != null && order == null
        ? MaintenanceOrderKind.corrective
        : order?.orderKind ?? MaintenanceOrderKind.corrective;
    _requestOrigin =
        order?.requestOrigin ?? MaintenanceRequestOrigin.internalRole;
    _hasSchedule = order?.scheduledStartAt != null;
    final DateTime baseDate = order?.scheduledStartAt ?? DateTime.now();
    _date = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _startTime = TimeOfDay(hour: baseDate.hour, minute: baseDate.minute);
    final DateTime endDate =
        order?.scheduledEndAt ?? baseDate.add(const Duration(hours: 1));
    _endTime = TimeOfDay(hour: endDate.hour, minute: endDate.minute);
    _titleController = TextEditingController(text: order?.title ?? '');
    _descriptionController = TextEditingController(
      text: order?.description ?? '',
    );
    _guestNameController = TextEditingController(text: order?.guestName ?? '');
    _locationController = TextEditingController(text: _selectedLocationTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _guestNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  MaintenanceLocation get _selectedLocation => widget.locations.firstWhere(
    (MaintenanceLocation item) => item.id == _locationId,
    orElse: () => widget.locations.first,
  );

  String get _selectedLocationTitle =>
      _formatLocationPickerTitle(_selectedLocation);

  bool get _shouldHideProviderField =>
      widget.initialOrder == null &&
      widget.launcherLabel != null &&
      widget.initialProviderId != null;

  bool get _shouldHideOrderKindField =>
      widget.initialOrder == null && widget.launcherLabel != null;

  List<MaintenanceOrderKind> get _availableOrderKinds {
    if (widget.initialOrder?.orderKind == MaintenanceOrderKind.preventive) {
      return MaintenanceOrderKind.values;
    }
    return <MaintenanceOrderKind>[
      MaintenanceOrderKind.corrective,
      MaintenanceOrderKind.visit,
    ];
  }

  MaintenanceProvider? get _selectedProvider {
    final int? providerId = _providerId;
    if (providerId == null) {
      return null;
    }
    for (final MaintenanceProvider provider in widget.providers) {
      if (provider.id == providerId) {
        return provider;
      }
    }
    return null;
  }

  String? get _selectedProviderWhatsapp =>
      _normalizeWhatsappNumber(_selectedProvider?.contact);

  String _formatLocationPickerTitle(MaintenanceLocation location) {
    final String code = location.code.trim();
    final String label = _normalizeMaintenanceLocationLabel(location.label);
    if (location.locationCategory == MaintenanceLocationCategory.apartment) {
      final String compact = label
          .replaceFirst(
            RegExp(
              r'^\s*(?:habitacion(?:es)?|habitaci\u00f3n(?:es)?|habitacao|quarto|apartamento|apto)\s*[-#:]*\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (compact.isNotEmpty) {
        return compact;
      }
      if (code.isNotEmpty) {
        return code;
      }
    }
    return label.isNotEmpty ? label : code;
  }

  String _formatLocationPickerSubtitle(MaintenanceLocation location) {
    final List<String> parts = <String>[
      if (location.floor != null && location.floor!.trim().isNotEmpty)
        _normalizeLocationPickerFloor(location.floor!),
      location.locationCategory.label,
      if (location.code.trim().isNotEmpty) 'Ref. ${location.code.trim()}',
    ];
    return parts.join(' - ');
  }

  String _normalizeLocationPickerFloor(String value) {
    final String normalized = _normalizeMaintenanceLocationLabel(value).trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if (RegExp(
      r'^anda(?:r|res)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return normalized;
    }
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return 'Andar $normalized';
    }
    final RegExpMatch? match = RegExp(
      r'^(?:piso|pisos|andar|andares)\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match != null) {
      return 'Andar ${match.group(1)!}';
    }
    return normalized;
  }

  Future<void> _pickLocation() async {
    final MaintenanceLocation? selected = await showDialog<MaintenanceLocation>(
      context: context,
      builder: (BuildContext context) => _LocationSearchDialog(
        locations: widget.locations,
        selectedLocationId: _locationId,
        titleBuilder: _formatLocationPickerTitle,
        subtitleBuilder: _formatLocationPickerSubtitle,
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _locationId = selected.id;
      _locationController.text = _formatLocationPickerTitle(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.wideFormWidth,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.initialOrder == null
                    ? widget.launcherLabel == null
                          ? 'Nova ordem'
                          : 'Nova ordem · ${widget.launcherLabel}'
                    : 'Editar ordem',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Local',
                  helperText: _formatLocationPickerSubtitle(_selectedLocation),
                  suffixIcon: const Icon(Icons.search_rounded),
                ),
                onTap: _pickLocation,
              ),
              const SizedBox(height: 12),
              if (!_shouldHideOrderKindField) ...<Widget>[
                DropdownButtonFormField<MaintenanceOrderKind>(
                  value: _orderKind,
                  decoration: const InputDecoration(labelText: 'Tipo de ordem'),
                  items: _availableOrderKinds
                      .map(
                        (MaintenanceOrderKind item) =>
                            DropdownMenuItem<MaintenanceOrderKind>(
                              value: item,
                              child: Text(item.label),
                            ),
                      )
                      .toList(),
                  onChanged: (MaintenanceOrderKind? value) {
                    if (value != null) {
                      setState(() => _orderKind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<MaintenanceRequestOrigin>(
                value: _requestOrigin,
                decoration: const InputDecoration(
                  labelText: 'Origem do pedido',
                ),
                items: MaintenanceRequestOrigin.values
                    .map(
                      (MaintenanceRequestOrigin item) =>
                          DropdownMenuItem<MaintenanceRequestOrigin>(
                            value: item,
                            child: Text(item.label),
                          ),
                    )
                    .toList(),
                onChanged: (MaintenanceRequestOrigin? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _requestOrigin = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (!_shouldHideProviderField) ...<Widget>[
                DropdownButtonFormField<int?>(
                  value: _providerId,
                  isExpanded: true,
                  style: const TextStyle(overflow: TextOverflow.ellipsis),
                  decoration: InputDecoration(
                    labelText: 'Prestador',
                    helperText: _providerId == null
                        ? 'Selecione um prestador para envio por WhatsApp.'
                        : _selectedProviderWhatsapp == null
                        ? 'O prestador selecionado ainda nao possui WhatsApp valido.'
                        : 'WhatsApp pronto para envio: $_selectedProviderWhatsapp',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Sem responsavel definido',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...widget.providers.map(
                      (MaintenanceProvider item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(
                          '${item.name} · ${item.specialty.label} · ${item.serviceLabel}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (int? value) =>
                      setState(() => _providerId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o titulo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              if (_requestOrigin ==
                  MaintenanceRequestOrigin.guestRequest) ...<Widget>[
                TextFormField(
                  controller: _guestNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do hospede',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasSchedule,
                onChanged: (bool value) => setState(() => _hasSchedule = value),
                title: const Text('Agendar atendimento no calendario'),
              ),
              if (_hasSchedule) ...<Widget>[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text('Data: ${_shortDate(_date)}'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickStartTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Inicio: ${_formatTimeOfDay(_startTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndTime,
                        icon: const Icon(Icons.timer_off_rounded),
                        label: Text('Fim: ${_formatTimeOfDay(_endTime)}'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('Salvar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1, 1, 1),
      lastDate: DateTime(_date.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _endTime = _addMinutes(picked, 60);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? guestName = _guestNameController.text.trim().isEmpty
        ? null
        : _guestNameController.text.trim();
    if (_requestOrigin == MaintenanceRequestOrigin.guestRequest &&
        guestName == null) {
      AppAlerts.warning(
        context,
        title: 'Dados do hospede',
        message: 'Informe o nome do hospede.',
      );
      return;
    }

    if (_providerId == null) {
      AppAlerts.warning(
        context,
        title: 'Prestador obrigatorio',
        message:
            'Selecione um prestador com WhatsApp valido para que a ordem seja enviada ao salvar.',
      );
      return;
    }

    if (_selectedProviderWhatsapp == null) {
      final String providerName = _selectedProvider?.name ?? 'selecionado';
      AppAlerts.warning(
        context,
        title: 'WhatsApp do prestador',
        message:
            'O prestador "$providerName" nao possui WhatsApp valido cadastrado. Ajuste o cadastro antes de salvar a ordem.',
      );
      return;
    }

    DateTime? startAt;
    DateTime? endAt;
    if (_hasSchedule) {
      startAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _startTime.hour,
        _startTime.minute,
      );
      endAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _endTime.hour,
        _endTime.minute,
      );
      if (!startAt.isBefore(endAt)) {
        AppAlerts.warning(
          context,
          title: 'Horario invalido',
          message: 'O horario de fim deve ser posterior ao horario de inicio.',
        );
        return;
      }
    }

    Navigator.of(context).pop(
      _MaintenanceOrderDraft(
        locationId: _locationId,
        providerId: _providerId,
        planId: widget.initialOrder?.planId,
        orderKind: _orderKind,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requestOrigin: _requestOrigin,
        requestedForGuest:
            _requestOrigin == MaintenanceRequestOrigin.guestRequest,
        guestName: guestName,
        scheduledStartAt: startAt,
        scheduledEndAt: endAt,
      ),
    );
  }
}

class _CompletionDraft {
  const _CompletionDraft({
    required this.completedAt,
    required this.resolutionNotes,
  });

  final DateTime? completedAt;
  final String resolutionNotes;
}

class _MaintenancePlanDraft {
  const _MaintenancePlanDraft({
    required this.locationId,
    required this.providerId,
    required this.title,
    required this.description,
    required this.recurrenceUnit,
    required this.recurrenceInterval,
    required this.nextDueDate,
    required this.active,
  });

  final int locationId;
  final int? providerId;
  final String title;
  final String? description;
  final MaintenancePlanRecurrenceUnit recurrenceUnit;
  final int recurrenceInterval;
  final DateTime nextDueDate;
  final bool active;

  CreateMaintenancePlanModel toCreateModel() {
    return CreateMaintenancePlanModel(
      locationId: locationId,
      providerId: providerId,
      title: title,
      description: description,
      recurrenceUnit: recurrenceUnit,
      recurrenceInterval: recurrenceInterval,
      nextDueDate: _formatDateApi(nextDueDate),
      active: active,
    );
  }

  UpdateMaintenancePlanModel toUpdateModel() {
    return UpdateMaintenancePlanModel(
      locationId: locationId,
      providerId: providerId,
      title: title,
      description: description,
      recurrenceUnit: recurrenceUnit,
      recurrenceInterval: recurrenceInterval,
      nextDueDate: _formatDateApi(nextDueDate),
      active: active,
    );
  }
}

class _PreventivePlansDialog extends StatefulWidget {
  const _PreventivePlansDialog({required this.service});

  final MaintenanceAppService service;

  @override
  State<_PreventivePlansDialog> createState() => _PreventivePlansDialogState();
}

class _PreventivePlansDialogState extends State<_PreventivePlansDialog> {
  List<MaintenanceLocation> _locations = const <MaintenanceLocation>[];
  List<MaintenanceProvider> _providers = const <MaintenanceProvider>[];
  List<MaintenancePlan> _plans = const <MaintenancePlan>[];
  bool _loading = true;
  bool _saving = false;
  int? _generatingPlanId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<MaintenancePlan> activePlans = _plans
        .where((MaintenancePlan plan) => plan.active)
        .toList();
    final DateTime today = _today();
    final int dueTodayCount = activePlans
        .where(
          (MaintenancePlan plan) =>
              plan.nextDueDate != null && _sameDay(plan.nextDueDate!, today),
        )
        .length;
    final int overdueCount = activePlans
        .where(
          (MaintenancePlan plan) =>
              plan.nextDueDate != null && plan.nextDueDate!.isBefore(today),
        )
        .length;

    return AppDialogShell(
      maxWidth: 920,
      maxHeight: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Planos preventivos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cadastre, acompanhe e gere ordens a partir das rotinas preventivas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving || _loading ? null : _createPlan,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Criar plano'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...<Widget>[
            Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _metricChip(
                context,
                label: 'Ativos',
                value: '${activePlans.length}',
                icon: Icons.task_alt_rounded,
              ),
              _metricChip(
                context,
                label: 'Vencidos',
                value: '$overdueCount',
                icon: Icons.warning_amber_rounded,
              ),
              _metricChip(
                context,
                label: 'Para hoje',
                value: '$dueTodayCount',
                icon: Icons.today_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _plans.isEmpty
                ? _emptyBox(
                    context,
                    'Ainda nao ha planos preventivos cadastrados. Crie um plano anual de ar-condicionado ou mensal de elevadores para comecar.',
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCFB),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: CostaNorteBrand.line),
                    ),
                    child: ListView.separated(
                      itemCount: _plans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final MaintenancePlan plan = _plans[index];
                        return _buildPreventivePlanRow(plan, today);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = null;
      if (showLoading) {
        _loading = true;
      }
    });
    try {
      final Future<List<MaintenanceLocation>> locationsFuture = widget.service
          .listLocations();
      final Future<List<MaintenanceProvider>> providersFuture = widget.service
          .listProviders();
      final Future<List<MaintenancePlan>> plansFuture = widget.service
          .listPlans();
      final List<MaintenanceLocation> locations = await locationsFuture;
      final List<MaintenanceProvider> providers = await providersFuture;
      final List<MaintenancePlan> plans = await plansFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = List<MaintenanceLocation>.of(locations)
          ..sort(_compareLocationsForCatalogOrder);
        _providers = providers;
        _plans = plans;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _createPlan() async {
    final _MaintenancePlanDraft? draft =
        await showDialog<_MaintenancePlanDraft>(
          context: context,
          builder: (BuildContext context) => _MaintenancePlanDialog(
            locations: _locations
                .where((MaintenanceLocation item) => item.active)
                .toList(),
            providers: _providers
                .where((MaintenanceProvider item) => item.active)
                .toList(),
          ),
        );
    if (draft == null) {
      return;
    }
    await _savePlanDraft(draft);
  }

  Future<void> _editPlan(MaintenancePlan plan) async {
    final _MaintenancePlanDraft? draft =
        await showDialog<_MaintenancePlanDraft>(
          context: context,
          builder: (BuildContext context) => _MaintenancePlanDialog(
            locations: _locations
                .where((MaintenanceLocation item) => item.active)
                .toList(),
            providers: _providers
                .where((MaintenanceProvider item) => item.active)
                .toList(),
            initialPlan: plan,
          ),
        );
    if (draft == null) {
      return;
    }
    await _savePlanDraft(draft, editingPlanId: plan.id);
  }

  Future<void> _savePlanDraft(
    _MaintenancePlanDraft draft, {
    int? editingPlanId,
  }) async {
    setState(() {
      _saving = true;
    });
    try {
      if (editingPlanId == null) {
        await widget.service.createPlan(draft.toCreateModel());
      } else {
        await widget.service.updatePlan(editingPlanId, draft.toUpdateModel());
      }
      await _load(showLoading: false);
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: editingPlanId == null ? 'Plano criado' : 'Plano atualizado',
        message: 'O plano preventivo foi salvo com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao salvar plano',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _generateOrderFromPlan(MaintenancePlan plan) async {
    final bool confirm = await AppAlerts.confirm(
      context,
      title: 'Gerar ordem preventiva',
      message:
          'Deseja gerar agora uma ordem preventiva para "${plan.title}"? O proximo vencimento sera avancado para o proximo ciclo.',
      confirmLabel: 'Gerar ordem',
    );
    if (!confirm || !mounted) {
      return;
    }
    setState(() {
      _generatingPlanId = plan.id;
    });
    try {
      await widget.service.generateOrderFromPlan(plan.id);
      await _load(showLoading: false);
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Ordem gerada',
        message: 'A ordem preventiva foi criada a partir do plano selecionado.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao gerar ordem',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPlanId = null;
        });
      }
    }
  }

  Widget _buildPreventivePlanRow(MaintenancePlan plan, DateTime today) {
    final bool overdue =
        plan.nextDueDate != null && plan.nextDueDate!.isBefore(today);
    final bool dueToday =
        plan.nextDueDate != null && _sameDay(plan.nextDueDate!, today);
    final String nextDueLabel = plan.nextDueDate == null
        ? 'Sem vencimento'
        : _shortDate(plan.nextDueDate!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_normalizeMaintenanceLocationLabel(plan.locationLabel)} - ${plan.providerName ?? 'Sem prestador definido'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _tag(context, plan.active ? 'Ativo' : 'Inativo'),
            ],
          ),
          if (plan.description != null && plan.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                plan.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CostaNorteBrand.mutedInk,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _tag(context, plan.recurrenceLabel),
              _tag(context, 'Proximo: $nextDueLabel'),
              if (plan.serviceLabel != null) _tag(context, plan.serviceLabel!),
              if (overdue) _tag(context, 'Vencido'),
              if (dueToday) _tag(context, 'Para hoje'),
              if (plan.lastGeneratedOn != null)
                _tag(
                  context,
                  'Ultima ordem: ${_shortDate(plan.lastGeneratedOn!)}',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _generatingPlanId == plan.id || !plan.active
                    ? null
                    : () => _generateOrderFromPlan(plan),
                icon: Icon(
                  _generatingPlanId == plan.id
                      ? Icons.hourglass_top_rounded
                      : Icons.playlist_add_check_circle_rounded,
                ),
                label: Text(
                  _generatingPlanId == plan.id ? 'Gerando...' : 'Gerar ordem',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _editPlan(plan),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CostaNorteBrand.foam,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: CostaNorteBrand.royalBlueDeep),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CostaNorteBrand.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _tag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CostaNorteBrand.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  int _compareLocationsForCatalogOrder(
    MaintenanceLocation a,
    MaintenanceLocation b,
  ) {
    final int groupCompare = _locationCatalogGroup(
      a,
    ).compareTo(_locationCatalogGroup(b));
    if (groupCompare != 0) {
      return groupCompare;
    }
    final int? aNumericCode = _locationCatalogNumericCode(a);
    final int? bNumericCode = _locationCatalogNumericCode(b);
    if (aNumericCode != null &&
        bNumericCode != null &&
        aNumericCode != bNumericCode) {
      return aNumericCode.compareTo(bNumericCode);
    }
    final int codeCompare = a.code.toLowerCase().compareTo(
      b.code.toLowerCase(),
    );
    if (codeCompare != 0) {
      return codeCompare;
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  int _locationCatalogGroup(MaintenanceLocation location) {
    final String code = location.code.trim();
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return code.length <= 2 ? 1 : 0;
    }
    return 2;
  }

  int? _locationCatalogNumericCode(MaintenanceLocation location) {
    final String code = location.code.trim();
    return RegExp(r'^\d+$').hasMatch(code) ? int.tryParse(code) : null;
  }
}

class _MaintenancePlanDialog extends StatefulWidget {
  const _MaintenancePlanDialog({
    required this.locations,
    required this.providers,
    this.initialPlan,
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenancePlan? initialPlan;

  @override
  State<_MaintenancePlanDialog> createState() => _MaintenancePlanDialogState();
}

class _MaintenancePlanDialogState extends State<_MaintenancePlanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late int _locationId;
  int? _providerId;
  late MaintenancePlanRecurrenceUnit _recurrenceUnit;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _intervalController;
  late bool _active;
  late DateTime _nextDueDate;

  @override
  void initState() {
    super.initState();
    final MaintenancePlan? plan = widget.initialPlan;
    _locationId = plan?.locationId ?? widget.locations.first.id;
    _providerId = plan?.providerId;
    _recurrenceUnit =
        plan?.recurrenceUnit ?? MaintenancePlanRecurrenceUnit.monthly;
    _titleController = TextEditingController(text: plan?.title ?? '');
    _descriptionController = TextEditingController(
      text: plan?.description ?? '',
    );
    _intervalController = TextEditingController(
      text: '${plan?.recurrenceInterval ?? 1}',
    );
    _active = plan?.active ?? true;
    _nextDueDate = plan?.nextDueDate ?? _today();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.wideFormWidth,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.initialPlan == null ? 'Novo plano' : 'Editar plano',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _locationId,
                decoration: const InputDecoration(labelText: 'Local'),
                items: widget.locations
                    .map(
                      (MaintenanceLocation item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(
                          _normalizeMaintenanceLocationLabel(item.label),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() => _locationId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _providerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prestador'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sem prestador definido'),
                  ),
                  ...widget.providers.map(
                    (MaintenanceProvider item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(
                        '${item.name} - ${item.specialty.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (int? value) => setState(() => _providerId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o titulo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaintenancePlanRecurrenceUnit>(
                value: _recurrenceUnit,
                decoration: const InputDecoration(labelText: 'Recorrencia'),
                items: MaintenancePlanRecurrenceUnit.values
                    .map(
                      (MaintenancePlanRecurrenceUnit item) =>
                          DropdownMenuItem<MaintenancePlanRecurrenceUnit>(
                            value: item,
                            child: Text(item.label),
                          ),
                    )
                    .toList(),
                onChanged: (MaintenancePlanRecurrenceUnit? value) {
                  if (value != null) {
                    setState(() => _recurrenceUnit = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Intervalo',
                  helperText: 'Ex.: 1 para mensal ou anual, 2 para bimestral',
                ),
                validator: (String? value) {
                  final int? parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 1) {
                    return 'Informe um intervalo valido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickNextDueDate,
                icon: const Icon(Icons.event_rounded),
                label: Text('Proximo vencimento: ${_shortDate(_nextDueDate)}'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (bool value) => setState(() => _active = value),
                title: const Text('Plano ativo'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('Salvar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickNextDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(_nextDueDate.year - 1, 1, 1),
      lastDate: DateTime(_nextDueDate.year + 3, 12, 31),
    );
    if (picked != null) {
      setState(() => _nextDueDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final int recurrenceInterval = int.parse(_intervalController.text.trim());
    Navigator.of(context).pop(
      _MaintenancePlanDraft(
        locationId: _locationId,
        providerId: _providerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        recurrenceUnit: _recurrenceUnit,
        recurrenceInterval: recurrenceInterval,
        nextDueDate: _nextDueDate,
        active: _active,
      ),
    );
  }
}

class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog({
    required this.locations,
    required this.selectedLocationId,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });

  final List<MaintenanceLocation> locations;
  final int selectedLocationId;
  final String Function(MaintenanceLocation) titleBuilder;
  final String Function(MaintenanceLocation) subtitleBuilder;

  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  late final TextEditingController _searchController;
  late List<MaintenanceLocation> _filteredLocations;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredLocations = List<MaintenanceLocation>.of(widget.locations);
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applyFilter)
      ..dispose();
    super.dispose();
  }

  void _applyFilter() {
    final String query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = List<MaintenanceLocation>.of(widget.locations);
        return;
      }
      _filteredLocations = widget.locations.where((MaintenanceLocation item) {
        final String haystack = <String>[
          widget.titleBuilder(item),
          widget.subtitleBuilder(item),
          item.label,
          item.code,
          item.floor ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 720,
      child: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selecionar local',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar local',
                hintText: 'Digite nome, numero, referencia ou andar',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_filteredLocations.length} resultado(s)',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CostaNorteBrand.mutedInk),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredLocations.isEmpty
                  ? _emptyScrollableBox(
                      'Nenhum local encontrado para a busca informada.',
                    )
                  : ListView.separated(
                      itemCount: _filteredLocations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final MaintenanceLocation location =
                            _filteredLocations[index];
                        final bool selected =
                            location.id == widget.selectedLocationId;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? CostaNorteBrand.royalBlueDeep
                                  : CostaNorteBrand.line,
                            ),
                          ),
                          tileColor: selected
                              ? CostaNorteBrand.mist
                              : Colors.white,
                          title: Text(widget.titleBuilder(location)),
                          subtitle: Text(widget.subtitleBuilder(location)),
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(
                            context,
                          ).pop<MaintenanceLocation>(location),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog();

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  DateTime _completedAt = DateTime.now();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Concluir ordem',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.event_available_rounded),
            label: Text(_dateTimeLabel(_completedAt)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Resolucao',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (_notesController.text.trim().isEmpty) {
                    AppAlerts.warning(
                      context,
                      title: 'Resolucao obrigatoria',
                      message: 'Informe como a ordem foi resolvida.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _CompletionDraft(
                      completedAt: _completedAt,
                      resolutionNotes: _notesController.text.trim(),
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _completedAt,
      firstDate: DateTime(_completedAt.year - 1, 1, 1),
      lastDate: DateTime(_completedAt.year + 1, 12, 31),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_completedAt),
    );
    if (pickedTime == null) {
      return;
    }
    setState(() {
      _completedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cancelar ordem',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Motivo do cancelamento',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final String value = _notesController.text.trim();
                  if (value.isEmpty) {
                    AppAlerts.warning(
                      context,
                      title: 'Motivo obrigatorio',
                      message: 'Informe o motivo do cancelamento.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCatalogsDialog extends StatefulWidget {
  const _MaintenanceCatalogsDialog({
    required this.locations,
    required this.providers,
    required this.service,
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenanceAppService service;

  @override
  State<_MaintenanceCatalogsDialog> createState() =>
      _MaintenanceCatalogsDialogState();
}

class _MaintenanceCatalogsDialogState
    extends State<_MaintenanceCatalogsDialog> {
  late List<MaintenanceLocation> _locations;
  late List<MaintenanceProvider> _providers;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _locations = List<MaintenanceLocation>.from(widget.locations);
    _providers = List<MaintenanceProvider>.from(widget.providers);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 920,
      maxHeight: 720,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Catalogos', style: Theme.of(context).textTheme.headlineSmall),
            if (_historyError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _historyError!,
                style: const TextStyle(color: CostaNorteBrand.error),
              ),
            ],
            const SizedBox(height: 12),
            const TabBar(
              tabs: <Tab>[
                Tab(text: 'Locais'),
                Tab(text: 'Responsaveis'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _CatalogLocationPane(
                    locations: _locations,
                    service: widget.service,
                    onHistoryError: _setHistoryError,
                    onCreate: _createLocation,
                    onUpdate: _updateLocation,
                  ),
                  _CatalogProviderPane(
                    providers: _providers,
                    service: widget.service,
                    onHistoryError: _setHistoryError,
                    onCreate: _createProvider,
                    onUpdate: _updateProvider,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<MaintenanceLocation> _createLocation(
    CreateMaintenanceLocationModel input,
  ) async {
    final MaintenanceLocation location = await widget.service.createLocation(
      input,
    );
    setState(() {
      _locations = <MaintenanceLocation>[..._locations, location]
        ..sort(_compareLocations);
    });
    return location;
  }

  Future<MaintenanceLocation> _updateLocation(
    int locationId,
    UpdateMaintenanceLocationModel input,
  ) async {
    final MaintenanceLocation location = await widget.service.updateLocation(
      locationId,
      input,
    );
    setState(() {
      _locations =
          _locations
              .map(
                (MaintenanceLocation item) =>
                    item.id == location.id ? location : item,
              )
              .toList()
            ..sort(_compareLocations);
    });
    return location;
  }

  int _compareLocations(MaintenanceLocation a, MaintenanceLocation b) {
    final int groupCompare = _locationCatalogGroup(
      a,
    ).compareTo(_locationCatalogGroup(b));
    if (groupCompare != 0) {
      return groupCompare;
    }
    final int? aNumericCode = _locationCatalogNumericCode(a);
    final int? bNumericCode = _locationCatalogNumericCode(b);
    if (aNumericCode != null &&
        bNumericCode != null &&
        aNumericCode != bNumericCode) {
      return aNumericCode.compareTo(bNumericCode);
    }
    final int codeCompare = a.code.toLowerCase().compareTo(
      b.code.toLowerCase(),
    );
    if (codeCompare != 0) {
      return codeCompare;
    }
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  int _locationCatalogGroup(MaintenanceLocation location) {
    final String code = location.code.trim();
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return code.length <= 2 ? 1 : 0;
    }
    return 2;
  }

  int? _locationCatalogNumericCode(MaintenanceLocation location) {
    final String code = location.code.trim();
    return RegExp(r'^\d+$').hasMatch(code) ? int.tryParse(code) : null;
  }

  Future<MaintenanceProvider> _createProvider(
    CreateMaintenanceProviderModel input,
  ) async {
    final MaintenanceProvider provider = await widget.service.createProvider(
      input,
    );
    setState(() {
      _providers = <MaintenanceProvider>[..._providers, provider]
        ..sort((MaintenanceProvider a, MaintenanceProvider b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    });
    return provider;
  }

  Future<MaintenanceProvider> _updateProvider(
    int providerId,
    UpdateMaintenanceProviderModel input,
  ) async {
    final MaintenanceProvider provider = await widget.service.updateProvider(
      providerId,
      input,
    );
    setState(() {
      _providers =
          _providers
              .map(
                (MaintenanceProvider item) =>
                    item.id == provider.id ? provider : item,
              )
              .toList()
            ..sort((MaintenanceProvider a, MaintenanceProvider b) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
    });
    return provider;
  }

  void _setHistoryError(String? message) {
    setState(() {
      _historyError = message;
    });
  }
}

class _MaintenanceAttachmentsDialog extends StatefulWidget {
  const _MaintenanceAttachmentsDialog({
    required this.order,
    required this.service,
  });

  final MaintenanceOrder order;
  final MaintenanceAppService service;

  @override
  State<_MaintenanceAttachmentsDialog> createState() =>
      _MaintenanceAttachmentsDialogState();
}

class _MaintenanceAttachmentsDialogState
    extends State<_MaintenanceAttachmentsDialog> {
  List<MaintenanceOrderAttachment> _attachments =
      const <MaintenanceOrderAttachment>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 760,
      maxHeight: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Anexos da ordem',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(widget.order.title),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _pickAndUpload(MaintenanceAttachmentType.photo),
                icon: const Icon(Icons.photo_camera_back_rounded),
                label: const Text('Adicionar foto'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () =>
                          _pickAndUpload(MaintenanceAttachmentType.attachment),
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Adicionar arquivo'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _attachments.isEmpty
                ? _emptyScrollableBox('Ainda nao ha anexos nesta ordem.')
                : ListView.separated(
                    itemCount: _attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final MaintenanceOrderAttachment attachment =
                          _attachments[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              attachment.attachmentType ==
                                      MaintenanceAttachmentType.photo
                                  ? Icons.image_rounded
                                  : Icons.insert_drive_file_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(attachment.fileName),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${attachment.attachmentType.label} Â· ${attachment.fileSize} bytes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => _deleteAttachment(attachment),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final List<MaintenanceOrderAttachment> attachments = await widget.service
        .listAttachments(widget.order.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _attachments = attachments;
      _loading = false;
    });
  }

  Future<void> _pickAndUpload(MaintenanceAttachmentType type) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: type == MaintenanceAttachmentType.photo
          ? FileType.image
          : FileType.any,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final PlatformFile file = result.files.first;
    final List<int> bytes = file.bytes ?? await File(file.path!).readAsBytes();
    setState(() => _saving = true);
    try {
      await widget.service.addAttachment(
        widget.order.id,
        AddMaintenanceAttachmentModel(
          attachmentType: type,
          fileName: file.name,
          contentType: _contentTypeFor(file.extension),
          base64Content: base64Encode(bytes),
        ),
      );
      if (!mounted) {
        return;
      }
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Anexos',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteAttachment(MaintenanceOrderAttachment attachment) async {
    final bool confirm = await AppAlerts.confirm(
      context,
      title: 'Excluir anexo',
      message: 'Deseja remover ${attachment.fileName} desta ordem?',
    );
    if (!confirm) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.deleteAttachment(widget.order.id, attachment.id);
      if (!mounted) {
        return;
      }
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Anexos',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _CatalogLocationPane extends StatefulWidget {
  const _CatalogLocationPane({
    required this.locations,
    required this.service,
    required this.onHistoryError,
    required this.onCreate,
    required this.onUpdate,
  });

  final List<MaintenanceLocation> locations;
  final MaintenanceAppService service;
  final ValueChanged<String?> onHistoryError;
  final Future<MaintenanceLocation> Function(CreateMaintenanceLocationModel)
  onCreate;
  final Future<MaintenanceLocation> Function(
    int,
    UpdateMaintenanceLocationModel,
  )
  onUpdate;

  @override
  State<_CatalogLocationPane> createState() => _CatalogLocationPaneState();
}

class _CatalogLocationPaneState extends State<_CatalogLocationPane> {
  MaintenanceLocation? _selected;
  late final TextEditingController _searchController;
  late final TextEditingController _codeController;
  late final TextEditingController _labelController;
  late final TextEditingController _floorController;
  late final TextEditingController _descriptionController;
  MaintenanceLocationType _type = MaintenanceLocationType.room;
  MaintenanceLocationCategory _category = MaintenanceLocationCategory.apartment;
  bool _active = true;
  bool _saving = false;
  String? _historyLoadingKey;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _codeController = TextEditingController();
    _labelController = TextEditingController();
    _floorController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    _labelController.dispose();
    _floorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _catalogLocationTitle(MaintenanceLocation location) {
    final String normalized = location.label.trim();
    if (location.locationCategory != MaintenanceLocationCategory.apartment) {
      return _normalizeCatalogLabel(normalized);
    }
    final String compact = _normalizeCatalogLabel(normalized).replaceFirst(
      RegExp(
        r'^\s*(?:habitacion(?:es)?|habitaci\u00f3n(?:es)?|habitacao|quarto|apartamento|apto)\s*[-#:]*\s*',
        caseSensitive: false,
      ),
      '',
    );
    final String result = compact.trim();
    if (result.isNotEmpty) {
      return result;
    }
    if (location.code.trim().isNotEmpty) {
      return location.code.trim();
    }
    return _normalizeCatalogLabel(normalized);
  }

  String _normalizeCatalogLabel(String value) {
    return _normalizeMaintenanceLocationLabel(value);
  }

  List<MaintenanceLocation> get _filteredLocations {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.locations;
    }
    return widget.locations.where((MaintenanceLocation item) {
      final String haystack = <String>[
        item.label,
        item.code,
        item.floor ?? '',
        item.locationType.label,
        item.locationCategory.label,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;
        final Widget locationsList = _buildLocationCatalogList();
        final Widget form = _buildLocationCatalogForm();

        if (compact) {
          return Column(
            children: <Widget>[
              Expanded(child: locationsList),
              const SizedBox(height: 16),
              Expanded(child: form),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Flexible(flex: 2, child: locationsList),
            const SizedBox(width: 16),
            SizedBox(width: 460, child: form),
          ],
        );
      },
    );
  }

  Widget _buildLocationCatalogList() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Buscar local',
            hintText: 'Nombre, referencia, piso...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: _filteredLocations
                .map(
                  (MaintenanceLocation item) => ListTile(
                    title: Text(_catalogLocationTitle(item)),
                    subtitle: Text(
                      '${item.locationType.label} - ${item.locationCategory.label}${item.code.trim().isEmpty ? '' : ' - Ref. ${item.code}'}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(item.active ? 'Ativo' : 'Inativo'),
                        IconButton(
                          onPressed: _historyLoadingKey == 'location:${item.id}'
                              ? null
                              : () => _openLocationAudit(item),
                          icon: Icon(
                            _historyLoadingKey == 'location:${item.id}'
                                ? Icons.hourglass_top_rounded
                                : Icons.history_rounded,
                          ),
                        ),
                      ],
                    ),
                    selected: _selected?.id == item.id,
                    onTap: () => _load(item),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCatalogForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<MaintenanceLocationType>(
            isExpanded: true,
            value: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: MaintenanceLocationType.values
                .map(
                  (MaintenanceLocationType item) =>
                      DropdownMenuItem<MaintenanceLocationType>(
                        value: item,
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                )
                .toList(),
            onChanged: (MaintenanceLocationType? value) {
              if (value != null) {
                setState(() {
                  _type = value;
                  if (_type == MaintenanceLocationType.commonArea) {
                    _category = MaintenanceLocationCategory.commonArea;
                  } else if (_category ==
                      MaintenanceLocationCategory.commonArea) {
                    _category = MaintenanceLocationCategory.apartment;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MaintenanceLocationCategory>(
            isExpanded: true,
            value: _type == MaintenanceLocationType.commonArea
                ? MaintenanceLocationCategory.commonArea
                : _category,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items:
                (_type == MaintenanceLocationType.commonArea
                        ? const <MaintenanceLocationCategory>[
                            MaintenanceLocationCategory.commonArea,
                          ]
                        : const <MaintenanceLocationCategory>[
                            MaintenanceLocationCategory.apartment,
                            MaintenanceLocationCategory.chalet,
                          ])
                    .map(
                      (MaintenanceLocationCategory item) =>
                          DropdownMenuItem<MaintenanceLocationCategory>(
                            value: item,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    )
                    .toList(),
            onChanged: _type == MaintenanceLocationType.commonArea
                ? null
                : (MaintenanceLocationCategory? value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Referencia numerica',
              helperText: 'Obrigatoria. Use 2 ou 3 digitos numericos.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _floorController,
            decoration: const InputDecoration(labelText: 'Andar'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descricao',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (bool value) => setState(() => _active = value),
            title: const Text('Ativo'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_selected == null ? 'Criar' : 'Salvar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _clear,
                  child: const Text('Novo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _load(MaintenanceLocation item) {
    setState(() {
      _selected = item;
      _type = item.locationType;
      _category = item.locationCategory;
      _codeController.text = item.code;
      _labelController.text = item.label;
      _floorController.text = item.floor ?? '';
      _descriptionController.text = item.description ?? '';
      _active = item.active;
    });
  }

  void _clear() {
    setState(() {
      _selected = null;
      _type = MaintenanceLocationType.room;
      _category = MaintenanceLocationCategory.apartment;
      _codeController.clear();
      _labelController.clear();
      _floorController.clear();
      _descriptionController.clear();
      _active = true;
    });
  }

  Future<void> _save() async {
    final String code = _codeController.text.trim();
    if (!RegExp(r'^\d{2,3}$').hasMatch(code)) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Informe uma referencia numerica de 2 ou 3 digitos.',
      );
      return;
    }
    if (_labelController.text.trim().isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Informe o nome do local.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_selected == null) {
        await widget.onCreate(
          CreateMaintenanceLocationModel(
            locationType: _type,
            locationCategory: _type == MaintenanceLocationType.commonArea
                ? MaintenanceLocationCategory.commonArea
                : _category,
            code: code,
            label: _labelController.text,
            floor: _floorController.text,
            description: _descriptionController.text,
            active: _active,
          ),
        );
      } else {
        await widget.onUpdate(
          _selected!.id,
          UpdateMaintenanceLocationModel(
            locationType: _type,
            locationCategory: _type == MaintenanceLocationType.commonArea
                ? MaintenanceLocationCategory.commonArea
                : _category,
            code: code,
            label: _labelController.text,
            floor: _floorController.text,
            description: _descriptionController.text,
            active: _active,
          ),
        );
      }
      _clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Locais',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLocationAudit(MaintenanceLocation location) async {
    setState(() => _historyLoadingKey = 'location:${location.id}');
    widget.onHistoryError(null);
    try {
      final List<AuditEventModel> events = await widget.service.locationAudit(
        location.id,
      );
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${_catalogLocationTitle(location)}',
        events: events,
      );
    } catch (error) {
      widget.onHistoryError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _historyLoadingKey = null);
      }
    }
  }
}

class _CatalogProviderPane extends StatefulWidget {
  const _CatalogProviderPane({
    required this.providers,
    required this.service,
    required this.onHistoryError,
    required this.onCreate,
    required this.onUpdate,
  });

  final List<MaintenanceProvider> providers;
  final MaintenanceAppService service;
  final ValueChanged<String?> onHistoryError;
  final Future<MaintenanceProvider> Function(CreateMaintenanceProviderModel)
  onCreate;
  final Future<MaintenanceProvider> Function(
    int,
    UpdateMaintenanceProviderModel,
  )
  onUpdate;

  @override
  State<_CatalogProviderPane> createState() => _CatalogProviderPaneState();
}

class _CatalogProviderPaneState extends State<_CatalogProviderPane> {
  MaintenanceProvider? _selected;
  late final TextEditingController _searchController;
  late final TextEditingController _nameController;
  late final TextEditingController _serviceLabelController;
  late final TextEditingController _scopeController;
  late final TextEditingController _contactController;
  MaintenanceProviderType _type = MaintenanceProviderType.internal;
  MaintenanceProviderSpecialty _specialty =
      MaintenanceProviderSpecialty.generalMaintenance;
  bool _active = true;
  bool _saving = false;
  String? _historyLoadingKey;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _nameController = TextEditingController();
    _serviceLabelController = TextEditingController();
    _scopeController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _serviceLabelController.dispose();
    _scopeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  List<MaintenanceProvider> get _filteredProviders {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.providers;
    }
    return widget.providers.where((MaintenanceProvider item) {
      final String haystack = <String>[
        item.name,
        item.serviceLabel,
        item.scopeDescription ?? '',
        item.contact ?? '',
        item.providerType.label,
        item.specialty.label,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          flex: 2,
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar responsable',
                  hintText: 'Nombre, servicio, WhatsApp...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: _filteredProviders
                      .map(
                        (MaintenanceProvider item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.providerType.label} · ${item.specialty.label} · ${item.serviceLabel}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(item.active ? 'Ativo' : 'Inativo'),
                              IconButton(
                                onPressed:
                                    _historyLoadingKey == 'provider:${item.id}'
                                    ? null
                                    : () => _openProviderAudit(item),
                                icon: Icon(
                                  _historyLoadingKey == 'provider:${item.id}'
                                      ? Icons.hourglass_top_rounded
                                      : Icons.history_rounded,
                                ),
                              ),
                            ],
                          ),
                          selected: _selected?.id == item.id,
                          onTap: () => _load(item),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<MaintenanceProviderType>(
                  isExpanded: true,
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: MaintenanceProviderType.values
                      .map(
                        (MaintenanceProviderType item) =>
                            DropdownMenuItem<MaintenanceProviderType>(
                              value: item,
                              child: Text(item.label),
                            ),
                      )
                      .toList(),
                  onChanged: (MaintenanceProviderType? value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MaintenanceProviderSpecialty>(
                  isExpanded: true,
                  value: _specialty,
                  decoration: const InputDecoration(labelText: 'Especialidade'),
                  items: MaintenanceProviderSpecialty.values
                      .map(
                        (MaintenanceProviderSpecialty item) =>
                            DropdownMenuItem<MaintenanceProviderSpecialty>(
                              value: item,
                              child: Text(item.label),
                            ),
                      )
                      .toList(),
                  onChanged: (MaintenanceProviderSpecialty? value) {
                    if (value != null) setState(() => _specialty = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceLabelController,
                  decoration: const InputDecoration(labelText: 'Servico'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scopeController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Escopo',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '5511999998888',
                    helperText: 'Formato internacional, solo numeros.',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (bool value) => setState(() => _active = value),
                  title: const Text('Ativo'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_selected == null ? 'Criar' : 'Salvar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clear,
                        child: const Text('Novo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _load(MaintenanceProvider item) {
    setState(() {
      _selected = item;
      _type = item.providerType;
      _specialty = item.specialty;
      _nameController.text = item.name;
      _serviceLabelController.text = item.serviceLabel;
      _scopeController.text = item.scopeDescription ?? '';
      _contactController.text = item.contact ?? '';
      _active = item.active;
    });
  }

  void _clear() {
    setState(() {
      _selected = null;
      _type = MaintenanceProviderType.internal;
      _specialty = MaintenanceProviderSpecialty.generalMaintenance;
      _nameController.clear();
      _serviceLabelController.clear();
      _scopeController.clear();
      _contactController.clear();
      _active = true;
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _serviceLabelController.text.trim().isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Informe nome e servico do responsavel.',
      );
      return;
    }
    final String? normalizedWhatsapp = _normalizeWhatsappNumber(
      _contactController.text,
    );
    if (_contactController.text.trim().isNotEmpty &&
        normalizedWhatsapp == null) {
      await AppAlerts.warning(
        context,
        title: 'WhatsApp invalido',
        message:
            'Informe o numero no formato internacional, por exemplo 5511999998888.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_selected == null) {
        await widget.onCreate(
          CreateMaintenanceProviderModel(
            providerType: _type,
            specialty: _specialty,
            name: _nameController.text,
            serviceLabel: _serviceLabelController.text,
            scopeDescription: _scopeController.text,
            contact: normalizedWhatsapp,
            active: _active,
          ),
        );
      } else {
        await widget.onUpdate(
          _selected!.id,
          UpdateMaintenanceProviderModel(
            providerType: _type,
            specialty: _specialty,
            name: _nameController.text,
            serviceLabel: _serviceLabelController.text,
            scopeDescription: _scopeController.text,
            contact: normalizedWhatsapp,
            active: _active,
          ),
        );
      }
      _clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Responsaveis',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openProviderAudit(MaintenanceProvider provider) async {
    setState(() => _historyLoadingKey = 'provider:${provider.id}');
    widget.onHistoryError(null);
    try {
      final List<AuditEventModel> events = await widget.service.providerAudit(
        provider.id,
      );
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${provider.name}',
        events: events,
      );
    } catch (error) {
      widget.onHistoryError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _historyLoadingKey = null);
      }
    }
  }
}

String? _normalizeWhatsappNumber(String? rawValue) {
  final String trimmed = (rawValue ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }
  String digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.length < 10 || digits.length > 15) {
    return null;
  }
  return digits;
}

Widget _emptyScrollableBox(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CostaNorteBrand.line),
      color: Colors.white,
    ),
    child: Text(message),
  );
}

String _normalizeMaintenanceLocationLabel(String value) {
  String normalized = value.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  normalized = normalized.replaceAllMapped(
    RegExp(r'\bescaleras?\b', caseSensitive: false),
    (Match match) =>
        match.group(0)!.toLowerCase().endsWith('s') ? 'Escadas' : 'Escada',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'\b(?:recepcion(?:es)?|recepci\u00f3n(?:es)?)\b',
      caseSensitive: false,
    ),
    (Match match) =>
        match.group(0)!.toLowerCase().endsWith('s') ? 'Recepcoes' : 'Recepcao',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\bpasillos?\b', caseSensitive: false),
    (Match match) =>
        match.group(0)!.toLowerCase().endsWith('s') ? 'Corredores' : 'Corredor',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\bpisos?\b', caseSensitive: false),
    (Match match) =>
        match.group(0)!.toLowerCase().endsWith('s') ? 'Andares' : 'Andar',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'\b(?:habitacion(?:es)?|habitaci\u00f3n(?:es)?)\b',
      caseSensitive: false,
    ),
    (Match match) =>
        match.group(0)!.toLowerCase().endsWith('s') ? 'Quartos' : 'Quarto',
  );

  return normalized;
}

String _contentTypeFor(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

String _orderScheduleLabel(MaintenanceOrder order) {
  if (order.scheduledStartAt == null || order.scheduledEndAt == null) {
    return 'Sem agenda definida Â· Reportada em ${_dateTimeLabel(order.reportedAt)}';
  }
  return '${_dateTimeLabel(order.scheduledStartAt!)} a ${_formatTime(order.scheduledEndAt!)}';
}

String _dateTimeLabel(DateTime value) =>
    '${_shortDate(value)} ${_formatTime(value)}';

String _formatDateApi(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _formatLocalDateTimeApi(DateTime value) =>
    '${_formatDateApi(value)}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

TimeOfDay _addMinutes(TimeOfDay value, int minutesToAdd) {
  final int totalMinutes = value.hour * 60 + value.minute + minutesToAdd;
  return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
}
