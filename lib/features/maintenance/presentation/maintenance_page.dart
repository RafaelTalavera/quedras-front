import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

const List<String> _monthLabels = <String>[
  'Janeiro',
  'Fevereiro',
  'Marco',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> _weekLabels = <String>[
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sab',
  'Dom',
];

const String _generalCommonAreasGroupTitle = 'Areas comuns gerais';

enum MaintenanceSection { operationalSummary }

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
  int? _selectedLocationId;
  _ExecutiveSummaryFilter _executiveSummaryFilter =
      _ExecutiveSummaryFilter.allOpen;
  MaintenanceSection _currentSection = MaintenanceSection.operationalSummary;
  final MaintenanceDailyReportPdfExporter _dailyReportPdfExporter =
      DefaultMaintenanceDailyReportPdfExporter();

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
            eyebrow: 'Operacao tecnica',
            title: 'Manutencao do hotel',
            description:
                'Controle de ordens de manutencao por apartamentos, chalets e areas comuns, com agenda, historico e anexos.',
            icon: Icons.build_circle_rounded,
            photoAlignment: Alignment.centerRight,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saving ? null : _createOrder,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Lancar ordem'),
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
          const SizedBox(height: 18),
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
              children: <Widget>[
                _buildExecutiveSummaryCard(),
                const SizedBox(height: 18),
                _buildOperationalSummaryCard(),
              ],
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
        if (_selectedLocationId != null &&
            !_locations.any(
              (MaintenanceLocation location) =>
                  location.id == _selectedLocationId,
            )) {
          _selectedLocationId = null;
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
              order.priority == MaintenancePriority.urgent ||
              order.businessPriority ==
                  MaintenanceBusinessPriority.criticalOperation,
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
    final List<MaintenanceOrder> previewOrders =
        filteredOrders.take(5).toList();
    final String filterTitle = _executiveSummaryFilterTitle(
      _executiveSummaryFilter,
    );
    final String filterDescription = _executiveSummaryFilterDescription(
      _executiveSummaryFilter,
      filteredCount: filteredOrders.length,
      selectedDate: _selectedDate,
      carryOverCount: carryOverOrders.length,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'Resumo executivo do dia',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pantallazo rapido das ordens abertas em ${_fullDate(_selectedDate)}, incluindo pendencias nao fechadas de dias anteriores.',
                        style: Theme.of(context).textTheme.bodyMedium,
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
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metricChip(
                  'Ordens abertas',
                  '${openOrders.length}',
                  Icons.assignment_late_rounded,
                  selected:
                      _executiveSummaryFilter == _ExecutiveSummaryFilter.allOpen,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.allOpen,
                  ),
                ),
                _metricChip(
                  'Pendentes anteriores',
                  '${carryOverOrders.length}',
                  Icons.history_toggle_off_rounded,
                  selected:
                      _executiveSummaryFilter ==
                      _ExecutiveSummaryFilter.carryOver,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.carryOver,
                  ),
                ),
                _metricChip(
                  'Urgentes',
                  '$urgentCount',
                  Icons.priority_high_rounded,
                  selected:
                      _executiveSummaryFilter == _ExecutiveSummaryFilter.urgent,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.urgent,
                  ),
                ),
                _metricChip(
                  'Agendadas',
                  '$scheduledCount',
                  Icons.event_available_rounded,
                  selected:
                      _executiveSummaryFilter ==
                      _ExecutiveSummaryFilter.scheduled,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.scheduled,
                  ),
                ),
                _metricChip(
                  'Em andamento',
                  '$inProgressCount',
                  Icons.handyman_rounded,
                  selected:
                      _executiveSummaryFilter ==
                      _ExecutiveSummaryFilter.inProgress,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.inProgress,
                  ),
                ),
                _metricChip(
                  'Sem prestador',
                  '$unassignedCount',
                  Icons.person_off_rounded,
                  selected:
                      _executiveSummaryFilter ==
                      _ExecutiveSummaryFilter.unassigned,
                  onTap: () => _setExecutiveSummaryFilter(
                    _ExecutiveSummaryFilter.unassigned,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (filteredOrders.isEmpty)
              _emptyBox(
                _executiveSummaryFilter == _ExecutiveSummaryFilter.allOpen
                    ? 'Nao ha ordens abertas para o dia selecionado. O PDF pode ser gerado mesmo assim como comprovante do painel vazio.'
                    : 'Nao ha ordens para o filtro "$filterTitle" no dia selecionado.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CostaNorteBrand.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      filterTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      filterDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_executiveSummaryFilter ==
                            _ExecutiveSummaryFilter.allOpen &&
                        carryOverOrders.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Text(
                          'Hay ${carryOverOrders.length} ordem(ns) pendente(s) arrastrada(s) de dias anteriores e ainda sem fechamento.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ...previewOrders.map(
                      (MaintenanceOrder order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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

  Widget _buildOperationalSummaryCard() {
    final Map<int, List<MaintenanceOrder>> dayOrdersByLocation =
        <int, List<MaintenanceOrder>>{};
    for (final MaintenanceOrder order in _dayOrders) {
      dayOrdersByLocation.putIfAbsent(
        order.locationId,
        () => <MaintenanceOrder>[],
      );
      dayOrdersByLocation[order.locationId]!.add(order);
    }
    final List<_MaintenanceDepartmentSectionData> sections =
        _buildDepartmentSections(dayOrdersByLocation);
    final List<_MaintenanceDepartmentLocationData> locations = sections
        .expand(
          (_MaintenanceDepartmentSectionData section) => section.locations,
        )
        .toList();
    final int activeLocations = locations
        .where(
          (_MaintenanceDepartmentLocationData item) =>
              item.dayOrders.isNotEmpty,
        )
        .length;
    final int overdueLocations = locations
        .where(
          (_MaintenanceDepartmentLocationData item) =>
              _locationVisualStateFor(item.dayOrders) ==
              _MaintenanceLocationVisualState.overdue,
        )
        .length;
    final int activeExecutionLocations = locations
        .where(
          (_MaintenanceDepartmentLocationData item) =>
              _locationVisualStateFor(item.dayOrders) ==
              _MaintenanceLocationVisualState.active,
        )
        .length;
    final int closedLocations = locations
        .where(
          (_MaintenanceDepartmentLocationData item) =>
              _locationVisualStateFor(item.dayOrders) ==
              _MaintenanceLocationVisualState.closed,
        )
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'Resumo por local',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Painel permanente com apartamentos, chalets e areas comuns de ${_fullDate(_selectedDate)}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickSelectedDate,
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Alterar dia'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metricChip(
                  'Locais ativos',
                  '$activeLocations',
                  Icons.apartment_rounded,
                ),
                _metricChip(
                  'Com atraso',
                  '$overdueLocations',
                  Icons.error_outline_rounded,
                ),
                _metricChip(
                  'Em aberto',
                  '$activeExecutionLocations',
                  Icons.handyman_rounded,
                ),
                _metricChip(
                  'Fechados',
                  '$closedLocations',
                  Icons.task_alt_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <Widget>[
                _MaintenanceLegendTag(
                  label: 'Vencido',
                  color: CostaNorteBrand.error,
                ),
                _MaintenanceLegendTag(
                  label: 'Ativo',
                  color: CostaNorteBrand.goldDeep,
                ),
                _MaintenanceLegendTag(
                  label: 'Fechado',
                  color: CostaNorteBrand.success,
                ),
                _MaintenanceLegendTag(
                  label: 'Sem atividade',
                  color: CostaNorteBrand.mutedInk,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (sections.every((item) => item.locations.isEmpty))
              _emptyBox('Nao ha locais cadastrados para montar a visualizacao.')
            else
              ...sections.map(
                (_MaintenanceDepartmentSectionData section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDepartmentSection(section),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentSection(_MaintenanceDepartmentSectionData section) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: section.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(section.icon, color: section.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CostaNorteBrand.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              _tag(
                section.affectedLocations == 0
                    ? 'Sem pendencias'
                    : '${section.affectedLocations} local(is) ativos',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (section.locations.isEmpty)
            _emptyBox('Nenhum local cadastrado neste setor.')
          else ...<Widget>[
            if (section.groups.length > 1)
              ...section.groups.map(
                (_MaintenanceDepartmentGroupData group) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        group.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _buildSectionLocationLayout(
                        section,
                        group.locations,
                        groupTitle: group.title,
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildSectionLocationLayout(section, section.locations),
          ],
        ],
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

  Widget _buildSectionLocationLayout(
    _MaintenanceDepartmentSectionData section,
    List<_MaintenanceDepartmentLocationData> locations, {
    String? groupTitle,
  }) {
    switch (section.layout) {
      case _MaintenanceSectionLayout.adaptive:
        return _buildAdaptiveLocationWrap(locations, groupTitle: groupTitle);
      case _MaintenanceSectionLayout.fixedGrid:
        return _buildFixedLocationGrid(locations, crossAxisCount: 6);
    }
  }

  Widget _buildFixedLocationGrid(
    List<_MaintenanceDepartmentLocationData> locations, {
    required int crossAxisCount,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        const double spacing = 6;
        const double preferredItemWidth = 148;
        const double minItemWidth = 128;
        int effectiveCrossAxisCount =
            ((maxWidth + spacing) / (preferredItemWidth + spacing)).floor();
        if (effectiveCrossAxisCount < 1) {
          effectiveCrossAxisCount = 1;
        }
        if (effectiveCrossAxisCount > crossAxisCount) {
          effectiveCrossAxisCount = crossAxisCount;
        }

        double itemWidth =
            (maxWidth - (effectiveCrossAxisCount - 1) * spacing) /
            effectiveCrossAxisCount;
        while (effectiveCrossAxisCount > 1 && itemWidth < minItemWidth) {
          effectiveCrossAxisCount -= 1;
          itemWidth =
              (maxWidth - (effectiveCrossAxisCount - 1) * spacing) /
              effectiveCrossAxisCount;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: locations
              .map(
                (_MaintenanceDepartmentLocationData item) => SizedBox(
                  width: itemWidth,
                  child: _MaintenanceLocationCard(
                    title: item.title,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    dayOrders: item.dayOrders,
                    selected: _selectedLocationId == item.location.id,
                    onTap: () =>
                        _openLocationDailyView(item.location, item.dayOrders),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAdaptiveLocationWrap(
    List<_MaintenanceDepartmentLocationData> locations, {
    String? groupTitle,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double maxCardWidth = maxWidth >= 240 ? 240 : maxWidth;
        final bool useStandardWidthForPb = _isPbGroupTitle(groupTitle);
        final double? standardPbCardWidth = useStandardWidthForPb
            ? _standardWidthForPbButtons(
                context,
                locations,
                maxAvailableWidth: maxCardWidth,
              )
            : null;
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locations
                .map(
                  (_MaintenanceDepartmentLocationData item) => ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: standardPbCardWidth ?? 72,
                      maxWidth: standardPbCardWidth ?? maxCardWidth,
                    ),
                    child: _MaintenanceLocationCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      dayOrders: item.dayOrders,
                      selected: _selectedLocationId == item.location.id,
                      adaptToContent: true,
                      onTap: () =>
                          _openLocationDailyView(item.location, item.dayOrders),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildOrderTile(MaintenanceOrder order, {VoidCallback? onDoubleTap}) {
    final bool selected = order.id == _selectedOrderId;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedOrderId = order.id),
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? const Color(0xFFFFF8E7) : CostaNorteBrand.mint,
          border: Border.all(
            color: selected ? CostaNorteBrand.goldDeep : CostaNorteBrand.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    order.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _statusPill(order),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.locationDisplayLabel} - ${order.providerLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _orderScheduleLabel(order),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CostaNorteBrand.mutedInk),
            ),
            if (order.description != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(order.description!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _tag(order.priority.label),
                _tag(order.businessPriority.label),
                _tag(order.serviceLabel),
                if (order.assignedUsername != null)
                  _tag('Atribuido: ${order.assignedUsername}'),
                if (order.estimatedExecutionMinutes != null)
                  _tag('${order.estimatedExecutionMinutes} min'),
                if (order.guestLabel != null)
                  _tag('Hospede: ${order.guestLabel}'),
                if (order.attachments.isNotEmpty)
                  _tag('${order.attachments.length} anexos'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedOrderId = order.id);
                    _editOrder(order: order);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: _sharingOrderId == order.id
                      ? null
                      : () {
                          setState(() => _selectedOrderId = order.id);
                          _shareOrderToWhatsApp(order: order);
                        },
                  icon: Icon(
                    _sharingOrderId == order.id
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                  ),
                  label: Text(
                    _sharingOrderId == order.id
                        ? 'Compartilhando...'
                        : 'Compartilhar',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openLocationHistory(order.locationId),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Historico local'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedOrderId = order.id);
                    _manageAttachments();
                  },
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Anexos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_MaintenanceDepartmentSectionData> _buildDepartmentSections(
    Map<int, List<MaintenanceOrder>> dayOrdersByLocation,
  ) {
    final List<MaintenanceLocation> activeLocations = _locations
        .where((MaintenanceLocation location) => location.active)
        .toList();
    final List<MaintenanceLocation> apartments = <MaintenanceLocation>[];
    final List<MaintenanceLocation> commonAreas = <MaintenanceLocation>[];
    final List<MaintenanceLocation> chalets = <MaintenanceLocation>[];

    for (final MaintenanceLocation location in activeLocations) {
      switch (_locationCategory(location)) {
        case _MaintenanceLocationCategory.apartment:
          apartments.add(location);
          break;
        case _MaintenanceLocationCategory.commonArea:
          commonAreas.add(location);
          break;
        case _MaintenanceLocationCategory.chalet:
          chalets.add(location);
          break;
      }
    }

    apartments.sort(_sortLocations);
    commonAreas.sort(_sortLocations);
    chalets.sort(_sortLocations);

    final Map<String, List<_MaintenanceDepartmentLocationData>> floorGroups =
        <String, List<_MaintenanceDepartmentLocationData>>{};
    for (final MaintenanceLocation location in apartments) {
      final String groupLabel = _floorLabelForLocation(location);
      floorGroups.putIfAbsent(
        groupLabel,
        () => <_MaintenanceDepartmentLocationData>[],
      );
      floorGroups[groupLabel]!.add(
        _buildDepartmentLocationData(
          location,
          dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
        ),
      );
    }

    final List<MaintenanceLocation> generalCommonAreas =
        <MaintenanceLocation>[];
    for (final MaintenanceLocation location in commonAreas) {
      final String groupLabel = _commonAreaFloorGroup(location);
      if (groupLabel == _generalCommonAreasGroupTitle) {
        generalCommonAreas.add(location);
        continue;
      }
      floorGroups.putIfAbsent(
        groupLabel,
        () => <_MaintenanceDepartmentLocationData>[],
      );
      floorGroups[groupLabel]!.add(
        _buildDepartmentLocationData(
          location,
          dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
        ),
      );
    }

    final List<_MaintenanceDepartmentGroupData> floorGroupList =
        floorGroups.entries.map((
          MapEntry<String, List<_MaintenanceDepartmentLocationData>> entry,
        ) {
          final List<_MaintenanceDepartmentLocationData> sortedLocations =
              List<_MaintenanceDepartmentLocationData>.of(entry.value)
                ..sort(_compareDepartmentGroupItems);
          return _MaintenanceDepartmentGroupData(
            title: entry.key,
            locations: sortedLocations,
          );
        }).toList()..sort(
          (
            _MaintenanceDepartmentGroupData a,
            _MaintenanceDepartmentGroupData b,
          ) => _departmentGroupSortValue(
            a.title,
          ).compareTo(_departmentGroupSortValue(b.title)),
        );

    final List<_MaintenanceDepartmentLocationData> generalCommonAreaLocations =
        generalCommonAreas
            .map(
              (MaintenanceLocation location) => _buildDepartmentLocationData(
                location,
                dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
              ),
            )
            .toList()
          ..sort(_compareDepartmentGroupItems);

    final List<_MaintenanceDepartmentLocationData> chaletLocations = chalets
        .map(
          (MaintenanceLocation location) => _buildDepartmentLocationData(
            location,
            dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
          ),
        )
        .toList();

    return <_MaintenanceDepartmentSectionData>[
      _MaintenanceDepartmentSectionData(
        title: 'Andares',
        description:
            'Apartamentos e areas comuns organizados por andar, com leitura uniforme na grade.',
        icon: Icons.apartment_rounded,
        tint: CostaNorteBrand.royalBlueDeep,
        layout: _MaintenanceSectionLayout.adaptive,
        groups: floorGroupList,
      ),
      if (generalCommonAreaLocations.isNotEmpty)
        _MaintenanceDepartmentSectionData(
          title: 'Areas comuns gerais',
          description:
              'Locais compartilhados sem andar operacional definido no cadastro.',
          icon: Icons.weekend_rounded,
          tint: CostaNorteBrand.goldDeep,
          layout: _MaintenanceSectionLayout.adaptive,
          groups: <_MaintenanceDepartmentGroupData>[
            _MaintenanceDepartmentGroupData(
              title: _generalCommonAreasGroupTitle,
              locations: generalCommonAreaLocations,
            ),
          ],
        ),
      _MaintenanceDepartmentSectionData(
        title: 'Chalets',
        description: 'Unidades externas com manutencao dedicada.',
        icon: Icons.cabin_rounded,
        tint: CostaNorteBrand.success,
        layout: _MaintenanceSectionLayout.adaptive,
        groups: <_MaintenanceDepartmentGroupData>[
          _MaintenanceDepartmentGroupData(
            title: 'Conjunto de chalets',
            locations: chaletLocations,
          ),
        ],
      ),
    ];
  }

  _MaintenanceDepartmentLocationData _buildDepartmentLocationData(
    MaintenanceLocation location,
    List<MaintenanceOrder> dayOrders,
  ) {
    final List<MaintenanceOrder> sortedOrders =
        List<MaintenanceOrder>.of(dayOrders)
          ..sort((MaintenanceOrder a, MaintenanceOrder b) {
            return a.referenceDate.compareTo(b.referenceDate);
          });
    return _MaintenanceDepartmentLocationData(
      location: location,
      title: _panelTitleForLocation(location),
      icon: _iconForLocation(location),
      subtitle: _subtitleForLocation(location),
      dayOrders: sortedOrders,
    );
  }

  _MaintenanceLocationCategory _locationCategory(MaintenanceLocation location) {
    switch (location.locationCategory) {
      case MaintenanceLocationCategory.apartment:
        return _MaintenanceLocationCategory.apartment;
      case MaintenanceLocationCategory.chalet:
        return _MaintenanceLocationCategory.chalet;
      case MaintenanceLocationCategory.commonArea:
        return _MaintenanceLocationCategory.commonArea;
    }
  }

  String _floorLabelForLocation(MaintenanceLocation location) {
    final String? floor = location.floor?.trim();
    if (floor != null && floor.isNotEmpty) {
      return _normalizeFloorLabel(floor);
    }
    final int? sequence = _locationSequence(location);
    if (sequence != null && sequence >= 100) {
      return 'Andar ${sequence ~/ 100}';
    }
    if (_locationCategory(location) == _MaintenanceLocationCategory.chalet) {
      return 'Chalets';
    }
    return 'Sem andar';
  }

  String _subtitleForLocation(MaintenanceLocation location) {
    final String code = location.code.trim();
    final String floor = _floorLabelForLocation(location);
    switch (_locationCategory(location)) {
      case _MaintenanceLocationCategory.apartment:
        return code.isEmpty ? floor : '$floor - Ref. $code';
      case _MaintenanceLocationCategory.chalet:
        return code.isEmpty ? 'Unidade externa' : 'Ref. $code';
      case _MaintenanceLocationCategory.commonArea:
        return code.isEmpty ? 'Area comum' : 'Area comum - Ref. $code';
    }
  }

  String _summaryLabelForLocation(MaintenanceLocation location) {
    final String baseLabel = _normalizeLocationDisplayLabel(location.label);
    final String code = location.code.trim();
    if (_locationCategory(location) == _MaintenanceLocationCategory.apartment) {
      return _compactApartmentLabel(baseLabel, fallbackCode: code);
    }
    if (_locationCategory(location) == _MaintenanceLocationCategory.chalet) {
      return _compactChaletLabel(baseLabel);
    }
    return baseLabel;
  }

  String _panelTitleForLocation(MaintenanceLocation location) {
    if (_locationCategory(location) ==
        _MaintenanceLocationCategory.commonArea) {
      return _compactCommonAreaLabel(location);
    }
    return _summaryLabelForLocation(location);
  }

  String _compactApartmentLabel(String value, {String fallbackCode = ''}) {
    final String compact = value.replaceFirst(
      RegExp(
        r'^\s*(?:habitacion(?:es)?|habitaci\u00f3n(?:es)?|habitacao|quarto|apartamento|apto)\s*[-#:]*\s*',
        caseSensitive: false,
      ),
      '',
    );
    final String normalized = compact.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    if (fallbackCode.isNotEmpty) {
      return fallbackCode;
    }
    return value.trim();
  }

  String _compactChaletLabel(String value) {
    final String compact = value.replaceFirst(
      RegExp(r'^\s*chalets?\s*[-#:]*\s*', caseSensitive: false),
      '',
    );
    final String normalized = compact.trim();
    return normalized.isEmpty ? value.trim() : normalized;
  }

  String _compactCommonAreaLabel(MaintenanceLocation location) {
    final String code = location.code.trim();
    final String label = _normalizeLocationDisplayLabel(location.label);
    final String shortLabel = _shortCommonAreaName(label, code: code);
    if (code.isNotEmpty) {
      return '$code - $shortLabel';
    }
    return shortLabel;
  }

  String _shortCommonAreaName(String value, {String code = ''}) {
    const Map<String, String> forcedLabels = <String, String>{
      '100': 'Areas comunes',
      '200': 'Areas comunes',
      '300': 'Areas comunes',
      '400': 'Areas comunes',
      '509': 'Financiero',
      '510': 'Elevador Servicio',
    };
    String normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Area comum';
    }

    final String? forcedLabel = forcedLabels[code];
    if (forcedLabel != null) {
      return forcedLabel;
    }

    if (code.isNotEmpty) {
      normalized = normalized.replaceFirst(
        RegExp('^${RegExp.escape(code)}\\s*[-:]*\\s*', caseSensitive: false),
        '',
      );
    }

    normalized = normalized
        .replaceFirst(RegExp(r'\bandares?\s*\d+\b', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\bpiso(?:s)?\s*\d+\b', caseSensitive: false), '')
        .trim();

    final List<MapEntry<RegExp, String>>
    replacements = <MapEntry<RegExp, String>>[
      MapEntry(
        RegExp(r'\bareas?\s+comuns?\b', caseSensitive: false),
        'Area comum',
      ),
      MapEntry(RegExp(r'\belevadores?\b', caseSensitive: false), 'Elevador'),
      MapEntry(RegExp(r'\brecepcoes?\b', caseSensitive: false), 'Recepcao'),
      MapEntry(RegExp(r'\breservas?\b', caseSensitive: false), 'Reservas'),
      MapEntry(RegExp(r'\bcorredores?\b', caseSensitive: false), 'Corredor'),
      MapEntry(RegExp(r'\bescadas?\b', caseSensitive: false), 'Escada'),
      MapEntry(RegExp(r'\blobby\b', caseSensitive: false), 'Lobby'),
      MapEntry(RegExp(r'\bestacionamento\b', caseSensitive: false), 'Estac.'),
      MapEntry(RegExp(r'\bsala de jogos\b', caseSensitive: false), 'Jogos'),
      MapEntry(RegExp(r'\btelevisao\b', caseSensitive: false), 'TV'),
    ];

    for (final MapEntry<RegExp, String> entry in replacements) {
      if (entry.key.hasMatch(normalized)) {
        return entry.value;
      }
    }

    return normalized;
  }

  String _commonAreaFloorGroup(MaintenanceLocation location) {
    final String? floor = location.floor?.trim();
    if (floor != null && floor.isNotEmpty) {
      return _normalizeFloorLabel(floor);
    }
    final int? sequence = _locationSequence(location);
    if (sequence != null && sequence >= 100) {
      return 'Andar ${sequence ~/ 100}';
    }
    return _generalCommonAreasGroupTitle;
  }

  int _compareDepartmentGroupItems(
    _MaintenanceDepartmentLocationData a,
    _MaintenanceDepartmentLocationData b,
  ) {
    final int categoryCompare = _departmentLocationCategorySortValue(
      a.location,
    ).compareTo(_departmentLocationCategorySortValue(b.location));
    if (categoryCompare != 0) {
      return categoryCompare;
    }
    return _compareLocationCatalogOrder(a.location, b.location);
  }

  int _departmentLocationCategorySortValue(MaintenanceLocation location) {
    switch (_locationCategory(location)) {
      case _MaintenanceLocationCategory.apartment:
        return 0;
      case _MaintenanceLocationCategory.commonArea:
        return 1;
      case _MaintenanceLocationCategory.chalet:
        return 2;
    }
  }

  IconData _iconForLocation(MaintenanceLocation location) {
    final String fingerprint = _locationFingerprint(location);
    if (fingerprint.contains('chalet')) {
      return Icons.cabin_rounded;
    }
    if (_locationCategory(location) == _MaintenanceLocationCategory.apartment) {
      return Icons.meeting_room_rounded;
    }
    if (fingerprint.contains('lobby') || fingerprint.contains('recepc')) {
      return Icons.living_rounded;
    }
    if (fingerprint.contains('tv')) {
      return Icons.tv_rounded;
    }
    if (fingerprint.contains('jogo')) {
      return Icons.sports_esports_rounded;
    }
    if (fingerprint.contains('estacion')) {
      return Icons.local_parking_rounded;
    }
    if (fingerprint.contains('escada') || fingerprint.contains('escalera')) {
      return Icons.stairs_rounded;
    }
    return Icons.domain_rounded;
  }

  String _locationFingerprint(MaintenanceLocation location) {
    final String label = _normalizeLocationDisplayLabel(location.label);
    final String floor = _normalizeFloorLabel(location.floor?.trim() ?? '');
    final String code = location.code.trim();
    return '$label $floor $code'.toLowerCase();
  }

  String _normalizeFloorLabel(String value) {
    final String normalized = _normalizeLocationDisplayLabel(value).trim();
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
    return 'Andar $normalized';
  }

  String _normalizeLocationDisplayLabel(String value) {
    return _normalizeMaintenanceLocationLabel(value);
  }

  int _sortLocations(MaintenanceLocation a, MaintenanceLocation b) {
    return _compareLocationCatalogOrder(a, b);
  }

  int _departmentGroupSortValue(String label) {
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(label);
    return int.tryParse(match?.group(1) ?? '') ?? 9999;
  }

  bool _isPbGroupTitle(String? value) {
    if (value == null) {
      return false;
    }
    return value.trim().toLowerCase() == 'andar pb';
  }

  double _standardWidthForPbButtons(
    BuildContext context,
    List<_MaintenanceDepartmentLocationData> locations, {
    required double maxAvailableWidth,
  }) {
    final TextStyle textStyle =
        Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    double longestTextWidth = 0;
    for (final _MaintenanceDepartmentLocationData item in locations) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: item.title, style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > longestTextWidth) {
        longestTextWidth = painter.width;
      }
    }
    const double horizontalPadding = 7 + 7;
    const double iconWidth = 14;
    const double iconBadgePadding = 5 + 5;
    const double gapAfterIcon = 6;
    const double gapBeforeBadge = 10;
    const double badgeWidth = 28;
    final double standardWidth =
        longestTextWidth +
        horizontalPadding +
        iconWidth +
        iconBadgePadding +
        gapAfterIcon +
        gapBeforeBadge +
        badgeWidth;
    return standardWidth.clamp(72, maxAvailableWidth).toDouble();
  }

  int? _locationSequence(MaintenanceLocation location) {
    final String labelFirst = [
      location.label.trim(),
      location.floor?.trim() ?? '',
      location.code.trim(),
    ].where((String value) => value.isNotEmpty).join(' ');
    final String fallback = [
      location.code.trim(),
      location.label.trim(),
    ].where((String value) => value.isNotEmpty).join(' ');
    final String fingerprint = labelFirst.isEmpty ? fallback : labelFirst;
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(fingerprint);
    return int.tryParse(match?.group(1) ?? '');
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

  Future<void> _openLocationDailyView(
    MaintenanceLocation location,
    List<MaintenanceOrder> dayOrders,
  ) async {
    setState(() {
      _selectedLocationId = location.id;
      if (_selectedLocationId != null &&
          !dayOrders.any(
            (MaintenanceOrder order) => order.id == _selectedOrderId,
          )) {
        _selectedOrderId = dayOrders.isEmpty ? null : dayOrders.first.id;
      }
    });
    try {
      final List<MaintenanceOrder> history = await widget.maintenanceAppService
          .getLocationHistory(location.id);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(_summaryLabelForLocation(location)),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (location.code.trim().isNotEmpty) ...<Widget>[
                    Text(
                      'Ref. ${location.code.trim()}',
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(color: CostaNorteBrand.mutedInk),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Resumo de ${_fullDate(_selectedDate)}',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O painel inferior foi ajustado para este local. Duplo toque em uma ordem abre as acoes rapidas.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium
                        ?.copyWith(color: CostaNorteBrand.mutedInk),
                  ),
                  const SizedBox(height: 16),
                  if (dayOrders.isEmpty)
                    _emptyBox('Nao ha ordens deste local no dia selecionado.')
                  else
                    ...dayOrders.map(
                      (MaintenanceOrder order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOrderTile(
                          order,
                          onDoubleTap: () {
                            Navigator.of(dialogContext).pop();
                            _openOrderActionDialog(order);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Historico completo',
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    _emptyBox('Esse local ainda nao possui historico.')
                  else
                    ...history.map(
                      (MaintenanceOrder order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          tileColor: CostaNorteBrand.mint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: CostaNorteBrand.line),
                          ),
                          title: Text(order.title),
                          subtitle: Text(
                            '${_dateTimeLabel(order.referenceDate)} - ${order.status.label} - ${order.providerLabel}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Resumo do local',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Widget _metricChip(
    String label,
    String value,
    IconData icon, {
    bool selected = false,
    VoidCallback? onTap,
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
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
                  order.priority == MaintenancePriority.urgent ||
                  order.businessPriority ==
                      MaintenanceBusinessPriority.criticalOperation,
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

  String _executiveSummaryFilterDescription(
    _ExecutiveSummaryFilter filter, {
    required int filteredCount,
    required DateTime selectedDate,
    required int carryOverCount,
  }) {
    switch (filter) {
      case _ExecutiveSummaryFilter.allOpen:
        return carryOverCount == 0
            ? 'Lista curta para leitura rapida. O PDF leva a relacao completa das ordens abertas de ${_fullDate(selectedDate)}.'
            : 'Lista curta para leitura rapida. Pendencias anteriores aparecem junto ao dia para acelerar o follow-up operacional.';
      case _ExecutiveSummaryFilter.carryOver:
        return 'Mostrando $filteredCount ordem(ns) ainda aberta(s) de dias anteriores para concentrar o follow-up pendente.';
      case _ExecutiveSummaryFilter.urgent:
        return 'Mostrando $filteredCount ordem(ns) marcada(s) como urgente(s) ou critica(s), com PDF dedicado para impressao imediata.';
      case _ExecutiveSummaryFilter.scheduled:
        return 'Mostrando $filteredCount ordem(ns) com agenda definida para ${_fullDate(selectedDate)}.';
      case _ExecutiveSummaryFilter.inProgress:
        return 'Mostrando $filteredCount ordem(ns) em execucao no momento para acompanhamento rapido.';
      case _ExecutiveSummaryFilter.unassigned:
        return 'Mostrando $filteredCount ordem(ns) ainda sem prestador definido para apoiar triagem e distribuicao.';
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
                    order.priority == MaintenancePriority.urgent ||
                    order.businessPriority ==
                        MaintenanceBusinessPriority.criticalOperation,
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
        .where((MaintenanceOrder order) => !_sameDay(order.referenceDate, _selectedDate))
        .toList();
    final List<MaintenanceOrder> filteredDayOrders = filteredOrders
        .where((MaintenanceOrder order) => _sameDay(order.referenceDate, _selectedDate))
        .toList();

    return MaintenanceDailyExecutiveReport(
      carryOverOpenCount: filteredCarryOver.length,
      dayOpenCount: filteredDayOrders.length,
      totalOpenCount: filteredOrders.length,
      urgentCount: filteredOrders
          .where(
            (MaintenanceOrder order) =>
                order.priority == MaintenancePriority.urgent ||
                order.businessPriority ==
                    MaintenanceBusinessPriority.criticalOperation,
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

  Future<void> _createOrder() async {
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
          ),
        );
    if (draft == null) {
      return;
    }
    await _saveOrderDraft(draft);
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

      if (editingOrderId == null) {
        await widget.maintenanceAppService.createOrder(draft.toCreateModel());
      } else {
        await widget.maintenanceAppService.updateOrder(
          editingOrderId,
          draft.toUpdateModel(),
        );
      }
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: editingOrderId == null ? 'Ordem criada' : 'Ordem atualizada',
        message: 'A ordem de manutencao foi salva com sucesso.',
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

  Future<void> _openLocationHistory(int locationId) async {
    try {
      final List<MaintenanceOrder> history = await widget.maintenanceAppService
          .getLocationHistory(locationId);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => _LocationHistoryDialog(
          history: history,
          locationLabel: history.isEmpty
              ? 'Local'
              : history.first.locationDisplayLabel,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Historico do local',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
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
        title: 'Historial de ${order.title}',
        events: history,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Historial de la orden',
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
      ..writeln('Prioridade tecnica: ${order.priority.label}')
      ..writeln('Prioridade operacional: ${order.businessPriority.label}')
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
                    ? () =>
                          Navigator.of(context).pop(_MaintenanceOrderAction.edit)
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
                onPressed: () => Navigator.of(
                  context,
                ).pop(_MaintenanceOrderAction.history),
                icon: loadingHistory
                    ? const Icon(Icons.hourglass_top_rounded)
                    : const Icon(Icons.history_rounded),
                label: Text(
                  loadingHistory ? 'Cargando...' : 'Historial',
                ),
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

enum _MaintenanceLocationCategory { apartment, commonArea, chalet }

enum _MaintenanceSectionLayout { fixedGrid, adaptive }

enum _MaintenanceLocationVisualState { neutral, active, overdue, closed }

class _MaintenanceLocationVisualPalette {
  const _MaintenanceLocationVisualPalette({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}

class _MaintenanceDepartmentSectionData {
  const _MaintenanceDepartmentSectionData({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.layout,
    required this.groups,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final _MaintenanceSectionLayout layout;
  final List<_MaintenanceDepartmentGroupData> groups;

  List<_MaintenanceDepartmentLocationData> get locations => groups
      .expand((_MaintenanceDepartmentGroupData group) => group.locations)
      .toList();

  int get affectedLocations => locations
      .where(
        (_MaintenanceDepartmentLocationData item) => item.dayOrders.isNotEmpty,
      )
      .length;

  int get urgentLocations => locations
      .where(
        (_MaintenanceDepartmentLocationData item) =>
            item.dayOrders.any(_isOverdueStatic),
      )
      .length;
}

class _MaintenanceDepartmentGroupData {
  const _MaintenanceDepartmentGroupData({
    required this.title,
    required this.locations,
  });

  final String title;
  final List<_MaintenanceDepartmentLocationData> locations;
}

class _MaintenanceDepartmentLocationData {
  const _MaintenanceDepartmentLocationData({
    required this.location,
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.dayOrders,
  });

  final MaintenanceLocation location;
  final String title;
  final IconData icon;
  final String subtitle;
  final List<MaintenanceOrder> dayOrders;
}

class _MaintenanceLocationCard extends StatelessWidget {
  const _MaintenanceLocationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.dayOrders,
    required this.selected,
    required this.onTap,
    this.adaptToContent = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<MaintenanceOrder> dayOrders;
  final bool selected;
  final VoidCallback onTap;
  final bool adaptToContent;

  @override
  Widget build(BuildContext context) {
    final _MaintenanceLocationVisualState visualState = _locationVisualStateFor(
      dayOrders,
    );
    final _MaintenanceLocationVisualPalette palette = _paletteForLocationState(
      visualState,
    );
    final Widget iconBadge = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: palette.foregroundColor, size: 14),
    );
    final Widget pendingBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: dayOrders.isNotEmpty
            ? palette.backgroundColor
            : CostaNorteBrand.mist,
      ),
      child: Text(
        dayOrders.isNotEmpty ? '${dayOrders.length}' : '0',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dayOrders.isNotEmpty
              ? palette.foregroundColor
              : CostaNorteBrand.mutedInk,
        ),
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFFFFF8E7)
              : dayOrders.isNotEmpty
              ? CostaNorteBrand.mint
              : visualState == _MaintenanceLocationVisualState.neutral
              ? Colors.white
              : Colors.white,
          border: Border.all(
            color: selected ? CostaNorteBrand.goldDeep : palette.borderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (adaptToContent)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  iconBadge,
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  pendingBadge,
                ],
              )
            else
              Row(
                children: <Widget>[
                  iconBadge,
                  const SizedBox(width: 6),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  pendingBadge,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceLegendTag extends StatelessWidget {
  const _MaintenanceLegendTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

bool _isOverdueStatic(MaintenanceOrder order) {
  if (order.status == MaintenanceOrderStatus.completed ||
      order.status == MaintenanceOrderStatus.cancelled) {
    return false;
  }
  final DateTime? deadline = order.expectedCompletionAt;
  if (deadline == null) {
    return false;
  }
  return deadline.isBefore(DateTime.now());
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

_MaintenanceLocationVisualState _locationVisualStateFor(
  List<MaintenanceOrder> dayOrders,
) {
  if (dayOrders.isEmpty) {
    return _MaintenanceLocationVisualState.neutral;
  }
  if (dayOrders.any(_isOverdueStatic)) {
    return _MaintenanceLocationVisualState.overdue;
  }
  final bool hasActiveOrder = dayOrders.any(
    (MaintenanceOrder order) =>
        order.status != MaintenanceOrderStatus.completed &&
        order.status != MaintenanceOrderStatus.cancelled,
  );
  if (hasActiveOrder) {
    return _MaintenanceLocationVisualState.active;
  }
  return _MaintenanceLocationVisualState.closed;
}

_MaintenanceLocationVisualPalette _paletteForLocationState(
  _MaintenanceLocationVisualState state,
) {
  return switch (state) {
    _MaintenanceLocationVisualState.overdue =>
      const _MaintenanceLocationVisualPalette(
        label: 'Com prazo vencido',
        foregroundColor: CostaNorteBrand.error,
        backgroundColor: Color(0x1FB3261E),
        borderColor: Color(0x59B3261E),
      ),
    _MaintenanceLocationVisualState.active =>
      const _MaintenanceLocationVisualPalette(
        label: 'Em aberto',
        foregroundColor: CostaNorteBrand.goldDeep,
        backgroundColor: Color(0x1FD79F08),
        borderColor: Color(0x59D79F08),
      ),
    _MaintenanceLocationVisualState.closed =>
      const _MaintenanceLocationVisualPalette(
        label: 'Fechado no dia',
        foregroundColor: CostaNorteBrand.success,
        backgroundColor: Color(0x1F2F7D32),
        borderColor: Color(0x592F7D32),
      ),
    _MaintenanceLocationVisualState.neutral =>
      const _MaintenanceLocationVisualPalette(
        label: 'Sem atividade',
        foregroundColor: CostaNorteBrand.mutedInk,
        backgroundColor: CostaNorteBrand.mist,
        borderColor: CostaNorteBrand.line,
      ),
  };
}

class _MaintenanceOrderDraft {
  const _MaintenanceOrderDraft({
    required this.locationId,
    required this.providerId,
    required this.title,
    required this.description,
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.guestName,
    required this.guestReference,
    required this.businessPriority,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int locationId;
  final int? providerId;
  final String title;
  final String? description;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? guestName;
  final String? guestReference;
  final MaintenanceBusinessPriority businessPriority;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  CreateMaintenanceOrderModel toCreateModel() {
    return CreateMaintenanceOrderModel(
      locationId: locationId,
      providerId: providerId,
      title: title,
      description: description,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      guestReference: guestReference,
      businessPriority: businessPriority,
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
      title: title,
      description: description,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      guestReference: guestReference,
      businessPriority: businessPriority,
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
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenanceOrder? initialOrder;

  @override
  State<_MaintenanceOrderDialog> createState() =>
      _MaintenanceOrderDialogState();
}

class _MaintenanceOrderDialogState extends State<_MaintenanceOrderDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late int _locationId;
  int? _providerId;
  late MaintenanceRequestOrigin _requestOrigin;
  late MaintenanceBusinessPriority _businessPriority;
  late bool _hasSchedule;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _guestNameController;
  late final TextEditingController _guestReferenceController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final MaintenanceOrder? order = widget.initialOrder;
    _locationId = order?.locationId ?? widget.locations.first.id;
    _providerId = order?.providerId;
    _requestOrigin =
        order?.requestOrigin ?? MaintenanceRequestOrigin.internalRole;
    _businessPriority =
        order?.businessPriority ?? MaintenanceBusinessPriority.internalStandard;
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
    _guestReferenceController = TextEditingController(
      text: order?.guestReference ?? '',
    );
    _locationController = TextEditingController(text: _selectedLocationTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _guestNameController.dispose();
    _guestReferenceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  MaintenanceLocation get _selectedLocation => widget.locations.firstWhere(
    (MaintenanceLocation item) => item.id == _locationId,
    orElse: () => widget.locations.first,
  );

  String get _selectedLocationTitle =>
      _formatLocationPickerTitle(_selectedLocation);

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
                widget.initialOrder == null ? 'Nova ordem' : 'Editar ordem',
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
                    if (value == MaintenanceRequestOrigin.guestRequest) {
                      _businessPriority =
                          MaintenanceBusinessPriority.guestPriority;
                    } else if (_businessPriority ==
                        MaintenanceBusinessPriority.guestPriority) {
                      _businessPriority =
                          MaintenanceBusinessPriority.internalStandard;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaintenanceBusinessPriority>(
                value: _businessPriority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade operacional',
                ),
                items: MaintenanceBusinessPriority.values
                    .map(
                      (MaintenanceBusinessPriority item) =>
                          DropdownMenuItem<MaintenanceBusinessPriority>(
                            value: item,
                            child: Text(item.label),
                          ),
                    )
                    .toList(),
                onChanged: (MaintenanceBusinessPriority? value) {
                  if (value != null) setState(() => _businessPriority = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _providerId,
                isExpanded: true,
                style: const TextStyle(overflow: TextOverflow.ellipsis),
                decoration: const InputDecoration(labelText: 'Prestador'),
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
                TextFormField(
                  controller: _guestReferenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia do hospede',
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
    final String? guestReference = _guestReferenceController.text.trim().isEmpty
        ? null
        : _guestReferenceController.text.trim();
    if (_requestOrigin == MaintenanceRequestOrigin.guestRequest &&
        guestName == null &&
        guestReference == null) {
      AppAlerts.warning(
        context,
        title: 'Dados do hospede',
        message: 'Informe o nome ou uma referencia do hospede.',
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
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requestOrigin: _requestOrigin,
        requestedForGuest:
            _requestOrigin == MaintenanceRequestOrigin.guestRequest,
        guestName: guestName,
        guestReference: guestReference,
        businessPriority: _businessPriority,
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
    _codeController = TextEditingController();
    _labelController = TextEditingController();
    _floorController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListView(
            children: widget.locations
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
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<MaintenanceLocationType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: MaintenanceLocationType.values
                    .map(
                      (MaintenanceLocationType item) =>
                          DropdownMenuItem<MaintenanceLocationType>(
                            value: item,
                            child: Text(item.label),
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
                                child: Text(item.label),
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
        ),
      ],
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
        title: 'Historial de ${_catalogLocationTitle(location)}',
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
    _nameController = TextEditingController();
    _serviceLabelController = TextEditingController();
    _scopeController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serviceLabelController.dispose();
    _scopeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListView(
            children: widget.providers
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
                          onPressed: _historyLoadingKey == 'provider:${item.id}'
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
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<MaintenanceProviderType>(
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
                decoration: const InputDecoration(labelText: 'Contato'),
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
            contact: _contactController.text,
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
            contact: _contactController.text,
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
        title: 'Historial de ${provider.name}',
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

class _LocationHistoryDialog extends StatelessWidget {
  const _LocationHistoryDialog({
    required this.history,
    required this.locationLabel,
  });

  final List<MaintenanceOrder> history;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 840,
      maxHeight: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Historico do local',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(locationLabel),
          const SizedBox(height: 14),
          Expanded(
            child: history.isEmpty
                ? _emptyScrollableBox('Esse local ainda nao possui historico.')
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final MaintenanceOrder order = history[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: CostaNorteBrand.line),
                        ),
                        title: Text(order.title),
                        subtitle: Text(
                          '${_dateTimeLabel(order.referenceDate)} Â· ${order.status.label} Â· ${order.providerNameSnapshot}',
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

String _fullDate(DateTime date) =>
    '${_weekLabels[date.weekday - 1]}, ${date.day} de ${_monthLabels[date.month - 1]} de ${date.year}';

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
