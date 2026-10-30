import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/audit/audit_models.dart';
import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/files/file_save_result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/sync/schedule_sync_service.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/whatsapp/manual_whatsapp_dialog.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../../core/widgets/operational_timeline.dart';
import '../application/maintenance_app_service.dart';
import '../application/maintenance_daily_report_pdf_exporter.dart';
import '../application/maintenance_provider_selection.dart';
import '../domain/maintenance_models.dart';

enum MaintenanceSection { operationalSummary }

enum _MaintenanceAgendaMode { day, week, month }

extension on _MaintenanceAgendaMode {
  String get label => switch (this) {
    _MaintenanceAgendaMode.day => 'diaria',
    _MaintenanceAgendaMode.week => 'semanal',
    _MaintenanceAgendaMode.month => 'mensal',
  };

  String get buttonLabel => switch (this) {
    _MaintenanceAgendaMode.day => 'Dia',
    _MaintenanceAgendaMode.week => 'Semana',
    _MaintenanceAgendaMode.month => 'Mes',
  };
}

enum _MaintenanceQuickLauncher {
  airConditioning,
  elevators,
  doorsAndWindows,
  internet,
  cameras,
  telephones,
  itSupport,
  internal,
}

enum _MaintenanceOrderCreationChoice {
  general,
  airConditioning,
  elevators,
  doorsAndWindows,
  internet,
  cameras,
  telephones,
  itSupport,
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

  Future<bool> openOrderFromNotification(
    int orderId,
    DateTime referenceDate, {
    MaintenanceNotificationType? notificationType,
  }) async {
    return await _state?._openOrderFromNotification(
          orderId,
          referenceDate,
          notificationType: notificationType,
        ) ??
        false;
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
    this.isSupervisor = false,
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final MaintenanceAppService maintenanceAppService;
  final ScheduleSyncService scheduleSyncService;
  final bool isSupervisor;
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
  MaintenanceCalendar? _calendar;
  MaintenanceDailyExecutiveReport? _executiveReport;
  late DateTime _selectedDate;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingProviders = false;
  bool _saving = false;
  bool _exportingDailyReport = false;
  bool _openingDailyReport = false;
  bool _isActiveInTree = false;
  bool _isAppResumed = true;
  int? _sharingOrderId;
  int? _loadingHistoryOrderId;
  String? _errorMessage;
  int? _selectedOrderId;
  _MaintenanceAgendaMode _agendaMode = _MaintenanceAgendaMode.week;
  int _agendaLocationId = 0;
  int _agendaProviderId = 0;
  String _agendaStatus = '';
  String _agendaPriority = '';
  _ExecutiveSummaryFilter _executiveSummaryFilter =
      _ExecutiveSummaryFilter.allOpen;
  MaintenanceSection _currentSection = MaintenanceSection.operationalSummary;
  final MaintenanceDailyReportPdfExporter _dailyReportPdfExporter =
      DefaultMaintenanceDailyReportPdfExporter();

  static const List<_MaintenanceQuickLauncher> _quickLaunchers =
      <_MaintenanceQuickLauncher>[
        _MaintenanceQuickLauncher.airConditioning,
        _MaintenanceQuickLauncher.elevators,
        _MaintenanceQuickLauncher.doorsAndWindows,
        _MaintenanceQuickLauncher.internet,
        _MaintenanceQuickLauncher.cameras,
        _MaintenanceQuickLauncher.telephones,
        _MaintenanceQuickLauncher.itSupport,
        _MaintenanceQuickLauncher.internal,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isActiveInTree = true;
    widget.controller?._attach(this);
    _selectedDate = _today();
    _subscribeToSyncEvents();
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
    _isActiveInTree = false;
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromSyncEvents();
    widget.controller?._detach(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _isActiveInTree = true;
    _subscribeToSyncEvents();
  }

  @override
  void deactivate() {
    _isActiveInTree = false;
    _unsubscribeFromSyncEvents();
    super.deactivate();
  }

  void _subscribeToSyncEvents() {
    if (_syncSubscription != null) {
      return;
    }
    _syncSubscription = widget.scheduleSyncService.events.listen(
      _handleSyncEvent,
    );
  }

  void _unsubscribeFromSyncEvents() {
    final StreamSubscription<ScheduleSyncEvent>? subscription =
        _syncSubscription;
    _syncSubscription = null;
    subscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
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
            title: '',
            icon: Icons.build_circle_rounded,
            photoAlignment: Alignment.centerRight,
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildHeroActionGroup('Criar ordem', <Widget>[
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _createOrder(),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('General'),
                  ),
                  ..._quickLaunchers.map(
                    (_MaintenanceQuickLauncher launcher) => OutlinedButton.icon(
                      onPressed: _saving ? null : () => _createOrder(launcher),
                      icon: Icon(_launcherIcon(launcher)),
                      label: Text(_launcherLabel(launcher)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildHeroActionGroup('Consultas', <Widget>[
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _openOrderStatusOverview,
                          icon: const Icon(Icons.assignment_late_rounded),
                          label: const Text('Estado das ordens'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickSelectedDate,
                          icon: const Icon(Icons.edit_calendar_rounded),
                          label: const Text('Alterar dia'),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildHeroActionGroup('Gestao', <Widget>[
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
                      ]),
                    ),
                  ],
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
              children: <Widget>[
                _buildMaintenanceAgendaCard(),
                const SizedBox(height: 16),
                _buildOperationalMapCard(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeroActionGroup(String title, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: buttons),
      ],
    );
  }

  Widget _buildMaintenanceAgendaCard() {
    final (DateTime rangeStart, DateTime rangeEndExclusive) = _agendaRange(
      _selectedDate,
    );
    final List<DateTime> days = List<DateTime>.generate(
      rangeEndExclusive.difference(rangeStart).inDays,
      (int index) => rangeStart.add(Duration(days: index)),
    );
    final MaintenanceCalendar? calendar = _calendar;
    final List<MaintenanceOrder> scheduled =
        (calendar?.scheduledOrders ?? const <MaintenanceOrder>[])
            .where(
              (MaintenanceOrder order) =>
                  order.scheduledStartAt != null &&
                  order.scheduledEndAt != null,
            )
            .toList();
    final List<MaintenanceOrder> backlog =
        calendar?.backlogOrders ?? const <MaintenanceOrder>[];
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
                        'Agenda ${_agendaMode.label} de manutencao',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_shortDate(days.first)} a ${_shortDate(days.last)} · Horario operacional 06:00-23:00',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Periodo anterior',
                  onPressed: _refreshingData
                      ? null
                      : () => _moveAgendaPeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _refreshingData
                      ? null
                      : () => _setAgendaDate(_today()),
                  child: const Text('Hoje'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Proximo periodo',
                  onPressed: _refreshingData
                      ? null
                      : () => _moveAgendaPeriod(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<_MaintenanceAgendaMode>(
              segments: _MaintenanceAgendaMode.values
                  .map(
                    (_MaintenanceAgendaMode mode) => ButtonSegment(
                      value: mode,
                      label: Text(mode.buttonLabel),
                    ),
                  )
                  .toList(),
              selected: <_MaintenanceAgendaMode>{_agendaMode},
              onSelectionChanged: _refreshingData
                  ? null
                  : (Set<_MaintenanceAgendaMode> selection) {
                      _changeAgendaMode(selection.single);
                    },
            ),
            const SizedBox(height: 14),
            _buildAgendaFilters(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: const <Widget>[
                OperationalTimelineLegend(
                  color: CostaNorteBrand.royalBlueDeep,
                  label: 'Agendada',
                ),
                OperationalTimelineLegend(
                  color: CostaNorteBrand.success,
                  label: 'Em andamento / concluida',
                ),
                OperationalTimelineLegend(
                  color: CostaNorteBrand.error,
                  label: 'Cancelada',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (scheduled.isEmpty)
              _emptyBox('Nao ha ordens agendadas neste periodo.')
            else if (_agendaMode == _MaintenanceAgendaMode.month)
              _buildMonthlyMaintenanceAgenda(scheduled)
            else
              OperationalTimeline<MaintenanceOrder>(
                days: days,
                selectedDate: _selectedDate,
                events: scheduled.expand(_maintenanceTimelineEvents).toList(),
                onDayTap: _setAgendaDate,
                onEventTap: _openOrderActionDialog,
                onEventMove: _moveMaintenanceTimelineEvent,
              ),
            const SizedBox(height: 18),
            Text(
              'Backlog sem agenda (${backlog.length}${calendar?.backlogHasMore == true ? '+' : ''})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (backlog.isEmpty)
              Text(
                'Nenhuma ordem aberta aguarda agendamento.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: backlog
                    .map(
                      (MaintenanceOrder order) => ActionChip(
                        avatar: Icon(
                          order.priority == MaintenancePriority.urgent
                              ? Icons.priority_high_rounded
                              : Icons.build_outlined,
                          size: 18,
                        ),
                        label: Text(
                          '${order.locationDisplayLabel} · ${order.title}',
                        ),
                        onPressed: () => _openOrderActionDialog(order),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _agendaDropdown<int>(
          label: 'Local',
          value: _agendaLocationId,
          items: <DropdownMenuItem<int>>[
            const DropdownMenuItem<int>(value: 0, child: Text('Todos')),
            ..._locations.map(
              (MaintenanceLocation location) => DropdownMenuItem<int>(
                value: location.id,
                child: Text('${location.code} - ${location.label}'),
              ),
            ),
          ],
          onChanged: (int value) =>
              _changeAgendaFilter(() => _agendaLocationId = value),
        ),
        _agendaDropdown<int>(
          label: 'Prestador',
          value: _agendaProviderId,
          items: <DropdownMenuItem<int>>[
            const DropdownMenuItem<int>(value: 0, child: Text('Todos')),
            ..._providers.map(
              (MaintenanceProvider provider) => DropdownMenuItem<int>(
                value: provider.id,
                child: Text(provider.name),
              ),
            ),
          ],
          onChanged: (int value) =>
              _changeAgendaFilter(() => _agendaProviderId = value),
        ),
        _agendaDropdown<String>(
          label: 'Estado',
          value: _agendaStatus,
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('Todos')),
            ...MaintenanceOrderStatus.values.map(
              (MaintenanceOrderStatus status) => DropdownMenuItem<String>(
                value: status.apiValue,
                child: Text(status.label),
              ),
            ),
          ],
          onChanged: (String value) =>
              _changeAgendaFilter(() => _agendaStatus = value),
        ),
        _agendaDropdown<String>(
          label: 'Prioridade',
          value: _agendaPriority,
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('Todas')),
            ...MaintenancePriority.values.map(
              (MaintenancePriority priority) => DropdownMenuItem<String>(
                value: priority.apiValue,
                child: Text(priority.label),
              ),
            ),
          ],
          onChanged: (String value) =>
              _changeAgendaFilter(() => _agendaPriority = value),
        ),
        TextButton.icon(
          onPressed: _hasAgendaFilters && !_refreshingData
              ? _clearAgendaFilters
              : null,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Limpar filtros'),
        ),
      ],
    );
  }

  Widget _agendaDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            items: items,
            onChanged: _refreshingData
                ? null
                : (T? next) {
                    if (next != null) {
                      onChanged(next);
                    }
                  },
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyMaintenanceAgenda(List<MaintenanceOrder> orders) {
    final List<MaintenanceOrder> sorted = List<MaintenanceOrder>.of(orders)
      ..sort(
        (MaintenanceOrder left, MaintenanceOrder right) =>
            left.scheduledStartAt!.compareTo(right.scheduledStartAt!),
      );
    return Column(
      children: sorted
          .map(
            (MaintenanceOrder order) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 64,
                child: Text(
                  _shortDate(order.scheduledStartAt!),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              title: Text(order.title),
              subtitle: Text(
                '${order.locationDisplayLabel} · ${_formatTime(order.scheduledStartAt!)}-${_formatTime(order.scheduledEndAt!)}',
              ),
              trailing: _statusPill(order),
              onTap: () => _openOrderActionDialog(order),
            ),
          )
          .toList(),
    );
  }

  Iterable<OperationalTimelineEvent<MaintenanceOrder>>
  _maintenanceTimelineEvents(MaintenanceOrder order) sync* {
    final DateTime start = order.scheduledStartAt!;
    final DateTime end = order.scheduledEndAt!;
    DateTime day = DateTime(start.year, start.month, start.day);
    final DateTime lastDay = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(lastDay)) {
      final DateTime operationalStart = day.add(const Duration(hours: 6));
      final DateTime operationalEnd = day.add(const Duration(hours: 23));
      final DateTime segmentStart = start.isAfter(operationalStart)
          ? start
          : operationalStart;
      final DateTime segmentEnd = end.isBefore(operationalEnd)
          ? end
          : operationalEnd;
      if (segmentEnd.isAfter(segmentStart)) {
        yield OperationalTimelineEvent<MaintenanceOrder>(
          value: order,
          date: day,
          startMinutes: segmentStart.hour * 60 + segmentStart.minute,
          endMinutes: segmentEnd.hour * 60 + segmentEnd.minute,
          label:
              '${order.locationDisplayLabel} · ${order.title} ${_formatTime(start)}-${_formatTime(end)}',
          color: switch (order.status) {
            MaintenanceOrderStatus.inProgress ||
            MaintenanceOrderStatus.completed => CostaNorteBrand.success,
            MaintenanceOrderStatus.cancelled => CostaNorteBrand.error,
            MaintenanceOrderStatus.open ||
            MaintenanceOrderStatus.assigned ||
            MaintenanceOrderStatus.scheduled => CostaNorteBrand.royalBlueDeep,
          },
          draggable:
              order.status == MaintenanceOrderStatus.open ||
              order.status == MaintenanceOrderStatus.assigned ||
              order.status == MaintenanceOrderStatus.scheduled,
        );
      }
      day = day.add(const Duration(days: 1));
    }
  }

  (DateTime, DateTime) _agendaRange(DateTime selectedDate) {
    final DateTime day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return switch (_agendaMode) {
      _MaintenanceAgendaMode.day => (day, day.add(const Duration(days: 1))),
      _MaintenanceAgendaMode.week => (
        _startOfWeek(day),
        _startOfWeek(day).add(const Duration(days: 7)),
      ),
      _MaintenanceAgendaMode.month => (
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1),
      ),
    };
  }

  bool get _hasAgendaFilters =>
      _agendaLocationId != 0 ||
      _agendaProviderId != 0 ||
      _agendaStatus.isNotEmpty ||
      _agendaPriority.isNotEmpty;

  Future<void> _moveAgendaPeriod(int offset) async {
    final DateTime next = switch (_agendaMode) {
      _MaintenanceAgendaMode.day => _selectedDate.add(Duration(days: offset)),
      _MaintenanceAgendaMode.week => _selectedDate.add(
        Duration(days: offset * 7),
      ),
      _MaintenanceAgendaMode.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
        1,
      ),
    };
    await _setAgendaDate(next);
  }

  Future<void> _changeAgendaMode(_MaintenanceAgendaMode mode) async {
    setState(() => _agendaMode = mode);
    await _load(showLoading: false);
  }

  Future<void> _changeAgendaFilter(VoidCallback update) async {
    setState(update);
    await _load(showLoading: false);
  }

  Future<void> _clearAgendaFilters() async {
    setState(() {
      _agendaLocationId = 0;
      _agendaProviderId = 0;
      _agendaStatus = '';
      _agendaPriority = '';
    });
    await _load(showLoading: false);
  }

  Future<void> _setAgendaDate(DateTime date) async {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    await _load(showLoading: false);
  }

  Future<void> _moveMaintenanceTimelineEvent(
    MaintenanceOrder order,
    DateTime date,
    int startMinutes,
  ) async {
    final DateTime? currentStart = order.scheduledStartAt;
    final DateTime? currentEnd = order.scheduledEndAt;
    if (currentStart == null || currentEnd == null) {
      return;
    }
    final DateTime proposedStart = DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    await _rescheduleOrder(
      order,
      initialStart: proposedStart,
      initialEnd: proposedStart.add(currentEnd.difference(currentStart)),
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

  Future<bool> _openOrderFromNotification(
    int orderId,
    DateTime referenceDate, {
    MaintenanceNotificationType? notificationType,
  }) async {
    if (!mounted) return false;
    setState(() {
      _selectedDate = DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
      );
      _agendaMode = _MaintenanceAgendaMode.day;
      _agendaLocationId = 0;
      _agendaProviderId = 0;
      _agendaStatus = '';
      _agendaPriority = '';
    });
    _setCurrentSection(MaintenanceSection.operationalSummary);
    await _load(showLoading: false);
    if (!mounted) return false;
    final List<MaintenanceOrder> candidates = <MaintenanceOrder>[
      ..._orders,
      ...?_executiveReport?.allOpenOrders,
    ];
    MaintenanceOrder? selected;
    for (final MaintenanceOrder order in candidates) {
      if (order.id == orderId) {
        selected = order;
        break;
      }
    }
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A ordem vinculada ao aviso nao esta mais disponivel.'),
        ),
      );
      return false;
    }
    setState(() => _selectedOrderId = selected!.id);
    await _openOrderActionDialog(selected, notificationType: notificationType);
    return true;
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
      final (DateTime rangeStart, DateTime rangeEndExclusive) = _agendaRange(
        _selectedDate,
      );
      final Future<MaintenanceCalendar> calendarFuture = widget
          .maintenanceAppService
          .getCalendar(
            rangeStart: _formatLocalDateTimeApi(rangeStart),
            rangeEndExclusive: _formatLocalDateTimeApi(rangeEndExclusive),
            locationId: _agendaLocationId == 0 ? null : _agendaLocationId,
            providerId: _agendaProviderId == 0 ? null : _agendaProviderId,
            status: _maintenanceStatusOrNull(_agendaStatus),
            priority: _maintenancePriorityOrNull(_agendaPriority),
          );
      final Future<MaintenanceDailyExecutiveReport> executiveReportFuture =
          widget.maintenanceAppService.getDailyExecutiveReport(
            date: _formatDateApi(_selectedDate),
          );
      final Future<List<MaintenanceProvider>> providersFuture = widget
          .maintenanceAppService
          .listProviders();
      final List<MaintenanceLocation> locations = await locationsFuture;
      final MaintenanceCalendar calendar = await calendarFuture;
      final MaintenanceDailyExecutiveReport executiveReport =
          await executiveReportFuture;
      final List<MaintenanceProvider> providers = await providersFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = List<MaintenanceLocation>.of(locations)
          ..sort(_compareLocationCatalogOrder);
        _providers = providers;
        _calendar = calendar;
        _orders = <MaintenanceOrder>[
          ...calendar.scheduledOrders,
          ...calendar.backlogOrders,
        ];
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
    return mounted &&
        _isActiveInTree &&
        _isAppResumed &&
        !_loading &&
        !_refreshingData &&
        !_loadingProviders &&
        !_saving;
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

  Future<void> _openOrderStatusOverview() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AppDialogShell(
                maxWidth: 1120,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Estado das ordens',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildExecutiveSummaryCard(
                          onFilterChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  Widget _buildOperationalMapCard() {
    final List<MaintenanceOrder> openOrders = _operationalOpenOrders;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: _buildOperationalLocationMap(openOrders),
      ),
    );
  }

  List<MaintenanceOrder> get _operationalOpenOrders {
    final Map<int, MaintenanceOrder> ordersById = <int, MaintenanceOrder>{};
    for (final MaintenanceOrder order in <MaintenanceOrder>[
      ...?_executiveReport?.allOpenOrders,
      ...?_calendar?.scheduledOrders,
      ...?_calendar?.backlogOrders,
    ]) {
      if (_isOrderOpenForExecutiveSummary(order)) {
        ordersById[order.id] = order;
      }
    }
    return ordersById.values.toList()
      ..sort((MaintenanceOrder a, MaintenanceOrder b) {
        final int byReference = a.referenceDate.compareTo(b.referenceDate);
        return byReference != 0 ? byReference : a.id.compareTo(b.id);
      });
  }

  Widget _buildExecutiveSummaryCard({
    ValueChanged<_ExecutiveSummaryFilter>? onFilterChanged,
  }) {
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
                      onFilterChanged: onFilterChanged,
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
                      onFilterChanged: onFilterChanged,
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
                      onFilterChanged: onFilterChanged,
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
                      onFilterChanged: onFilterChanged,
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
                      onFilterChanged: onFilterChanged,
                    ),
                    compact: true,
                  ),
                ),
              ],
            ),
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

  Widget _buildOperationalLocationMap(List<MaintenanceOrder> openOrders) {
    final Map<int, List<MaintenanceOrder>> ordersByLocation =
        <int, List<MaintenanceOrder>>{};
    for (final MaintenanceOrder order in openOrders) {
      ordersByLocation
          .putIfAbsent(order.locationId, () => <MaintenanceOrder>[])
          .add(order);
    }

    final List<MaintenanceLocation> apartments =
        _locations
            .where(
              (MaintenanceLocation location) =>
                  location.active &&
                  location.locationCategory ==
                      MaintenanceLocationCategory.apartment,
            )
            .toList()
          ..sort(_compareLocationCatalogOrder);
    final List<MaintenanceLocation> commonAreas =
        _locations
            .where(
              (MaintenanceLocation location) =>
                  location.active &&
                  location.locationCategory ==
                      MaintenanceLocationCategory.commonArea,
            )
            .toList()
          ..sort(_compareLocationCatalogOrder);
    final List<MaintenanceLocation> chalets =
        _locations
            .where(
              (MaintenanceLocation location) =>
                  location.active &&
                  location.locationCategory ==
                      MaintenanceLocationCategory.chalet,
            )
            .toList()
          ..sort(_compareLocationCatalogOrder);

    final Map<String, List<MaintenanceLocation>> locationsByFloor =
        <String, List<MaintenanceLocation>>{};
    for (final MaintenanceLocation location in apartments) {
      locationsByFloor
          .putIfAbsent(
            _operationalFloorLabel(location),
            () => <MaintenanceLocation>[],
          )
          .add(location);
    }
    final Map<String, List<MaintenanceLocation>> commonAreasByFloor =
        <String, List<MaintenanceLocation>>{};
    for (final MaintenanceLocation location in commonAreas) {
      commonAreasByFloor
          .putIfAbsent(
            _operationalFloorLabel(location),
            () => <MaintenanceLocation>[],
          )
          .add(location);
    }
    final List<String> floorLabels = <String>{
      ...locationsByFloor.keys,
      ...commonAreasByFloor.keys,
    }.toList()..sort(_compareOperationalFloors);
    final List<String> groundFloorLabels = floorLabels
        .where(_isOperationalGroundFloor)
        .toList();
    final List<String> buildingFloorLabels = floorLabels
        .where((String floor) => !_isOperationalGroundFloor(floor))
        .toList();
    final List<MaintenanceLocation> groundFloorLocations =
        <MaintenanceLocation>[
          for (final String floor
              in groundFloorLabels) ...<MaintenanceLocation>[
            ...?locationsByFloor[floor],
            ...?commonAreasByFloor[floor],
          ],
        ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: CostaNorteBrand.mist.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Mapa operacional',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),

          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _operationalMapLegend('Urgente', CostaNorteBrand.error),
              _operationalMapLegend('En andamento', CostaNorteBrand.success),
              _operationalMapLegend('Agendada', CostaNorteBrand.royalBlueDeep),
              _operationalMapLegend('Aberta', CostaNorteBrand.goldDeep),
            ],
          ),
          const SizedBox(height: 14),
          if (_locations.isEmpty)
            _emptyBox('Cadastre os locais para visualizar o mapa operacional.')
          else ...<Widget>[
            if (buildingFloorLabels.isNotEmpty)
              _buildOperationalMapSection(
                icon: Icons.apartment_rounded,
                title: 'Edificio principal',
                children: buildingFloorLabels
                    .map(
                      (String floor) => _buildOperationalFloorRow(
                        floor,
                        <MaintenanceLocation>[
                          ...?locationsByFloor[floor],
                          ...?commonAreasByFloor[floor],
                        ],
                        ordersByLocation,
                      ),
                    )
                    .toList(),
              ),
            if (chalets.isNotEmpty) ...<Widget>[
              if (buildingFloorLabels.isNotEmpty) const SizedBox(height: 12),
              _buildOperationalMapSection(
                icon: Icons.cottage_rounded,
                title: 'Chales',
                children: <Widget>[
                  _buildOperationalFloorLocationsRow(chalets, ordersByLocation),
                ],
              ),
            ],
            if (groundFloorLocations.isNotEmpty) ...<Widget>[
              if (buildingFloorLabels.isNotEmpty || chalets.isNotEmpty)
                const SizedBox(height: 12),
              _buildOperationalMapSection(
                icon: Icons.meeting_room_rounded,
                title: 'PB',
                children: <Widget>[
                  _buildGroundFloorLocationsGrid(
                    groundFloorLocations,
                    ordersByLocation,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOperationalMapSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: CostaNorteBrand.royalBlueDeep),
              const SizedBox(width: 7),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildOperationalFloorRow(
    String floor,
    List<MaintenanceLocation> locations,
    Map<int, List<MaintenanceOrder>> ordersByLocation,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget locationsRow = _buildOperationalFloorLocationsRow(
            locations,
            ordersByLocation,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(floor, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 7),
                locationsRow,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 92,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    floor,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              Expanded(child: locationsRow),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOperationalFloorLocationsRow(
    List<MaintenanceLocation> locations,
    Map<int, List<MaintenanceOrder>> ordersByLocation,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int index = 0; index < locations.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 4),
          Expanded(
            child: _buildOperationalLocationTile(
              locations[index],
              ordersByLocation[locations[index].id] ??
                  const <MaintenanceOrder>[],
              compact: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroundFloorLocationsGrid(
    List<MaintenanceLocation> locations,
    Map<int, List<MaintenanceOrder>> ordersByLocation,
  ) {
    if (locations.isEmpty) {
      return const SizedBox.shrink();
    }

    const double spacing = 8;
    const double minimumTileWidth = 150;
    const int maximumColumns = 4;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int fittingColumns =
            ((constraints.maxWidth + spacing) / (minimumTileWidth + spacing))
                .floor();
        final int columnCount = fittingColumns.clamp(
          1,
          locations.length < maximumColumns ? locations.length : maximumColumns,
        );
        final double tileWidth =
            (constraints.maxWidth - (spacing * (columnCount - 1))) /
            columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final MaintenanceLocation location in locations)
              SizedBox(
                width: tileWidth,
                child: _buildOperationalLocationTile(
                  location,
                  ordersByLocation[location.id] ?? const <MaintenanceOrder>[],
                  compact: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOperationalLocationTile(
    MaintenanceLocation location,
    List<MaintenanceOrder> orders, {
    bool compact = false,
  }) {
    final Color stateColor = _operationalLocationColor(orders);
    final bool hasOrders = orders.isNotEmpty;
    return Semantics(
      button: true,
      label:
          '${location.label}, ${orders.length} ordem${orders.length == 1 ? '' : 'ns'} aberta${orders.length == 1 ? '' : 's'}${hasOrders ? '' : '. Duplo clique para criar uma ordem'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasOrders ? () => _openLocationOrders(location, orders) : null,
          onDoubleTap: hasOrders
              ? null
              : () => _openCreateOrderLauncherForLocation(location),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compact ? 0 : 86,
              minHeight: compact ? 46 : 52,
            ),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 10,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: hasOrders
                    ? stateColor.withValues(alpha: 0.12)
                    : const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasOrders ? stateColor : CostaNorteBrand.line,
                  width: hasOrders ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: compact ? 6 : 9,
                    height: compact ? 6 : 9,
                    decoration: BoxDecoration(
                      color: hasOrders ? stateColor : CostaNorteBrand.line,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: compact ? 3 : 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            location.locationCategory ==
                                    MaintenanceLocationCategory.commonArea
                                ? _normalizeMaintenanceLocationLabel(
                                    location.label,
                                  )
                                : compact && location.code.trim().isNotEmpty
                                ? location.code.trim()
                                : _normalizeMaintenanceLocationLabel(
                                    location.label,
                                  ),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontSize: compact ? 11 : null),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hasOrders
                                ? '${orders.length} aberta${orders.length == 1 ? '' : 's'}'
                                : 'Sem ordens',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: compact ? 9 : null,
                                  color: hasOrders
                                      ? stateColor
                                      : CostaNorteBrand.mutedInk,
                                  fontWeight: hasOrders
                                      ? FontWeight.w700
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _operationalMapLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color _operationalLocationColor(List<MaintenanceOrder> orders) {
    if (orders.any(
      (MaintenanceOrder order) => order.priority == MaintenancePriority.urgent,
    )) {
      return CostaNorteBrand.error;
    }
    if (orders.any(
      (MaintenanceOrder order) =>
          order.status == MaintenanceOrderStatus.inProgress,
    )) {
      return CostaNorteBrand.success;
    }
    if (orders.any(
      (MaintenanceOrder order) =>
          order.status == MaintenanceOrderStatus.scheduled,
    )) {
      return CostaNorteBrand.royalBlueDeep;
    }
    return CostaNorteBrand.goldDeep;
  }

  String _operationalFloorLabel(MaintenanceLocation location) {
    final String explicitFloor = (location.floor ?? '').trim();
    if (explicitFloor.isNotEmpty) {
      final String? floorNumber = RegExp(
        r'\d+',
      ).firstMatch(explicitFloor)?.group(0);
      if (floorNumber != null) {
        if (int.tryParse(floorNumber) == 0) {
          return 'PB';
        }
        return '$floorNumberº andar';
      }
      if (_isOperationalGroundFloor(explicitFloor)) {
        return 'PB';
      }
      return _normalizeMaintenanceLocationLabel(explicitFloor);
    }
    final String locationReference = '${location.code} ${location.label}';
    final Match? referencedFloor = RegExp(
      r'(?:andar|piso)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(locationReference);
    final String? referencedFloorNumber = referencedFloor?.group(1);
    if (referencedFloorNumber != null) {
      if (int.tryParse(referencedFloorNumber) == 0) {
        return 'PB';
      }
      return '$referencedFloorNumberº andar';
    }
    if (_isOperationalGroundFloor(locationReference)) {
      return 'PB';
    }
    if (location.locationCategory == MaintenanceLocationCategory.commonArea) {
      return 'PB';
    }
    final Match? roomNumber = RegExp(r'\d+').firstMatch(location.code);
    final String? code = roomNumber?.group(0);
    if (code != null && code.length >= 3) {
      return '${code.substring(0, 1)}º andar';
    }
    return 'Sem andar';
  }

  int _compareOperationalFloors(String a, String b) {
    final int? aNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(a)?.group(0) ?? '',
    );
    final int? bNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(b)?.group(0) ?? '',
    );
    if (aNumber != null && bNumber != null) {
      return bNumber.compareTo(aNumber);
    }
    if (aNumber != null) return -1;
    if (bNumber != null) return 1;
    return a.compareTo(b);
  }

  bool _isOperationalGroundFloor(String floor) {
    final String normalized = floor.trim().toLowerCase();
    return normalized == 'pb' ||
        RegExp(r'\bpb\b').hasMatch(normalized) ||
        RegExp(r'(?:andar|piso)\s*0\b').hasMatch(normalized) ||
        normalized == '0' ||
        normalized.contains('planta baixa') ||
        normalized.contains('planta baja') ||
        normalized.contains('terreo') ||
        normalized.contains('térreo');
  }

  Future<void> _openLocationOrders(
    MaintenanceLocation location,
    List<MaintenanceOrder> orders,
  ) async {
    final MaintenanceOrder? selected = await showDialog<MaintenanceOrder>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: Text(
          '${_normalizeMaintenanceLocationLabel(location.label)} - ordens abertas',
        ),
        children: orders
            .map(
              (MaintenanceOrder order) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(order),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              order.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${order.status.label} - ${order.providerLabel}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedOrderId = selected.id);
    await _openOrderActionDialog(selected);
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

  void _setExecutiveSummaryFilter(
    _ExecutiveSummaryFilter filter, {
    ValueChanged<_ExecutiveSummaryFilter>? onFilterChanged,
  }) {
    if (_executiveSummaryFilter == filter) {
      return;
    }
    setState(() {
      _executiveSummaryFilter = filter;
    });
    onFilterChanged?.call(filter);
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

  Future<void> _createOrder([
    _MaintenanceQuickLauncher? launcher,
    MaintenanceLocation? initialLocation,
  ]) async {
    await _loadProviders();
    if (!mounted) {
      return;
    }
    final List<MaintenanceProvider> activeProviders =
        canonicalMaintenanceProviders(
          _providers.where((MaintenanceProvider item) => item.active).toList(),
        );
    final List<MaintenanceProvider> dialogProviders = _prioritizeProviders(
      activeProviders,
      launcher,
    );
    final int? initialProviderId =
        _initialProviderIdForLauncher(dialogProviders, launcher) ??
        (dialogProviders.isEmpty ? null : dialogProviders.first.id);
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
            initialLocationId: initialLocation?.id,
          ),
        );
    if (draft == null) {
      return;
    }
    await _saveOrderDraft(draft);
  }

  Future<void> _openCreateOrderLauncherForLocation(
    MaintenanceLocation location,
  ) async {
    final _MaintenanceOrderCreationChoice? choice =
        await showDialog<_MaintenanceOrderCreationChoice>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Criar ordem - ${location.label}'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _MaintenanceOrderCreationChoice.values
                    .map(
                      (_MaintenanceOrderCreationChoice item) =>
                          OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(item),
                            icon: Icon(_creationChoiceIcon(item)),
                            label: Text(_creationChoiceLabel(item)),
                          ),
                    )
                    .toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
    if (choice == null || !mounted) {
      return;
    }
    await _createOrder(_launcherForCreationChoice(choice), location);
  }

  _MaintenanceQuickLauncher? _launcherForCreationChoice(
    _MaintenanceOrderCreationChoice choice,
  ) {
    return switch (choice) {
      _MaintenanceOrderCreationChoice.general => null,
      _MaintenanceOrderCreationChoice.airConditioning =>
        _MaintenanceQuickLauncher.airConditioning,
      _MaintenanceOrderCreationChoice.elevators =>
        _MaintenanceQuickLauncher.elevators,
      _MaintenanceOrderCreationChoice.doorsAndWindows =>
        _MaintenanceQuickLauncher.doorsAndWindows,
      _MaintenanceOrderCreationChoice.internet =>
        _MaintenanceQuickLauncher.internet,
      _MaintenanceOrderCreationChoice.cameras =>
        _MaintenanceQuickLauncher.cameras,
      _MaintenanceOrderCreationChoice.telephones =>
        _MaintenanceQuickLauncher.telephones,
      _MaintenanceOrderCreationChoice.itSupport =>
        _MaintenanceQuickLauncher.itSupport,
      _MaintenanceOrderCreationChoice.internal =>
        _MaintenanceQuickLauncher.internal,
    };
  }

  String _creationChoiceLabel(_MaintenanceOrderCreationChoice choice) {
    return switch (choice) {
      _MaintenanceOrderCreationChoice.general => 'General',
      _MaintenanceOrderCreationChoice.airConditioning => 'Ar-condicionado',
      _MaintenanceOrderCreationChoice.elevators => 'Elevadores',
      _MaintenanceOrderCreationChoice.doorsAndWindows => 'Portas e janelas',
      _MaintenanceOrderCreationChoice.internet => 'Internet',
      _MaintenanceOrderCreationChoice.cameras => 'Cameras',
      _MaintenanceOrderCreationChoice.telephones => 'Telefones',
      _MaintenanceOrderCreationChoice.itSupport => 'TI',
      _MaintenanceOrderCreationChoice.internal => 'Interno',
    };
  }

  IconData _creationChoiceIcon(_MaintenanceOrderCreationChoice choice) {
    final _MaintenanceQuickLauncher? launcher = _launcherForCreationChoice(
      choice,
    );
    return launcher == null
        ? Icons.add_circle_outline_rounded
        : _launcherIcon(launcher);
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
      _MaintenanceQuickLauncher.doorsAndWindows =>
        provider.specialty == MaintenanceProviderSpecialty.doorsAndWindows,
      _MaintenanceQuickLauncher.internet =>
        provider.specialty == MaintenanceProviderSpecialty.internet,
      _MaintenanceQuickLauncher.cameras =>
        provider.specialty == MaintenanceProviderSpecialty.cameras,
      _MaintenanceQuickLauncher.telephones =>
        provider.specialty == MaintenanceProviderSpecialty.telephones,
      _MaintenanceQuickLauncher.itSupport =>
        provider.specialty == MaintenanceProviderSpecialty.itSupport,
      _MaintenanceQuickLauncher.internal =>
        provider.providerType == MaintenanceProviderType.internal &&
            provider.specialty ==
                MaintenanceProviderSpecialty.generalMaintenance,
    };
  }

  String _launcherLabel(_MaintenanceQuickLauncher launcher) {
    return switch (launcher) {
      _MaintenanceQuickLauncher.elevators => 'Elevadores',
      _MaintenanceQuickLauncher.airConditioning => 'Ar-condicionado',
      _MaintenanceQuickLauncher.doorsAndWindows => 'Portas e janelas',
      _MaintenanceQuickLauncher.internet => 'Internet',
      _MaintenanceQuickLauncher.cameras => 'Câmeras',
      _MaintenanceQuickLauncher.telephones => 'Telefones',
      _MaintenanceQuickLauncher.itSupport => 'TI',
      _MaintenanceQuickLauncher.internal => 'Interno',
    };
  }

  IconData _launcherIcon(_MaintenanceQuickLauncher launcher) {
    return switch (launcher) {
      _MaintenanceQuickLauncher.elevators => Icons.elevator_rounded,
      _MaintenanceQuickLauncher.airConditioning => Icons.ac_unit_rounded,
      _MaintenanceQuickLauncher.doorsAndWindows =>
        Icons.door_front_door_rounded,
      _MaintenanceQuickLauncher.internet => Icons.router_rounded,
      _MaintenanceQuickLauncher.cameras => Icons.videocam_rounded,
      _MaintenanceQuickLauncher.telephones => Icons.phone_rounded,
      _MaintenanceQuickLauncher.itSupport => Icons.computer_rounded,
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
      await _prepareOrderWhatsapp(selected);
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
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: editingOrderId == null ? 'Ordem criada' : 'Ordem atualizada',
        message: 'A ordem de manutencao foi salva com sucesso.',
      );
      if (mounted) {
        await _prepareOrderWhatsapp(savedOrder);
      }
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

  Future<void> _startOrder(MaintenanceOrder order) async {
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

  Future<void> _completeOrder(MaintenanceOrder order) async {
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

  Future<void> _cancelOrder(MaintenanceOrder order) async {
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
        isSupervisor: widget.isSupervisor,
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

  Future<void> _manageAttachments(MaintenanceOrder order) async {
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

  Future<void> _openOrderActionDialog(
    MaintenanceOrder order, {
    MaintenanceNotificationType? notificationType,
  }) async {
    final _MaintenanceOrderAction? action =
        await showDialog<_MaintenanceOrderAction>(
          context: context,
          builder: (BuildContext context) => _MaintenanceOrderActionDialog(
            order: order,
            sharing: _sharingOrderId == order.id,
            loadingHistory: _loadingHistoryOrderId == order.id,
            notificationType: notificationType,
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
      case _MaintenanceOrderAction.reschedule:
        await _rescheduleOrder(order);
        return;
      case _MaintenanceOrderAction.share:
        await _shareOrderToWhatsApp(order: order);
        return;
      case _MaintenanceOrderAction.start:
        await _startOrder(order);
        return;
      case _MaintenanceOrderAction.complete:
        await _completeOrder(order);
        return;
      case _MaintenanceOrderAction.cancel:
        await _cancelOrder(order);
        return;
      case _MaintenanceOrderAction.attachments:
        await _manageAttachments(order);
        return;
      case _MaintenanceOrderAction.history:
        await _openOrderHistory(order);
        return;
    }
  }

  Future<void> _rescheduleOrder(
    MaintenanceOrder order, {
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    final DateTime defaultStart =
        initialStart ??
        order.scheduledStartAt ??
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 9);
    final _MaintenanceRescheduleDraft? draft =
        await showDialog<_MaintenanceRescheduleDraft>(
          context: context,
          builder: (BuildContext context) => _MaintenanceRescheduleDialog(
            order: order,
            initialStart: defaultStart,
            initialEnd:
                initialEnd ??
                order.scheduledEndAt ??
                defaultStart.add(const Duration(hours: 1)),
          ),
        );
    if (draft == null || !mounted) {
      return;
    }
    try {
      final MaintenanceOrder updated = await widget.maintenanceAppService
          .rescheduleOrder(
            order.id,
            RescheduleMaintenanceOrderModel(
              scheduledStartAt: _formatLocalDateTimeApi(draft.start),
              scheduledEndAt: _formatLocalDateTimeApi(draft.end),
              reason: draft.reason,
              expectedScheduleVersion: order.scheduleVersion,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() => _selectedOrderId = updated.id);
      await _load(showLoading: false);
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Agenda atualizada',
        message: 'A ordem foi reagendada com sucesso.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 409) {
        await _load(showLoading: false);
        if (!mounted) {
          return;
        }
        await AppAlerts.warning(
          context,
          title: 'Agenda alterada por outro usuario',
          message:
              'A agenda foi recarregada. Revise o horario atual antes de tentar novamente.',
        );
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Nao foi possivel reagendar',
        message: error.message,
      );
    } catch (error) {
      if (mounted) {
        await AppAlerts.error(
          context,
          title: 'Nao foi possivel reagendar',
          message: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
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
                  '${item.title} - ${item.locationDisplayLabel} - ${_normalizeMaintenanceProviderName(item.providerNameSnapshot)}',
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
      ..writeln(
        'Servico: ${_normalizeMaintenanceServiceLabel(order.serviceLabel)}',
      )
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

  Future<void> _prepareOrderWhatsapp(MaintenanceOrder order) async {
    final MaintenanceProvider? provider = _findProviderById(order.providerId);
    try {
      await showManualWhatsappDialog(
        context,
        providerName: provider?.name ?? order.providerLabel,
        phoneNumber: provider == null
            ? null
            : maintenanceProviderWhatsappNumber(provider),
        message: _buildOrderShareMessage(order),
      );
    } catch (error) {
      if (mounted) {
        await AppAlerts.warning(
          context,
          title: 'Aviso não preparado',
          message: 'O aviso não pôde ser preparado: $error',
        );
      }
    }
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

class _MaintenanceRescheduleDraft {
  const _MaintenanceRescheduleDraft({
    required this.start,
    required this.end,
    required this.reason,
  });

  final DateTime start;
  final DateTime end;
  final String reason;
}

class _MaintenanceRescheduleDialog extends StatefulWidget {
  const _MaintenanceRescheduleDialog({
    required this.order,
    required this.initialStart,
    required this.initialEnd,
  });

  final MaintenanceOrder order;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_MaintenanceRescheduleDialog> createState() =>
      _MaintenanceRescheduleDialogState();
}

class _MaintenanceRescheduleDialogState
    extends State<_MaintenanceRescheduleDialog> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _reasonController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.order.scheduledStartAt == null
            ? 'Agendar ordem'
            : 'Reagendar ordem',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${widget.order.locationDisplayLabel} · ${widget.order.title}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              _dateTimeTile(
                label: 'Inicio',
                value: _start,
                onChanged: (DateTime value) => setState(() => _start = value),
              ),
              const SizedBox(height: 8),
              _dateTimeTile(
                label: 'Fim',
                value: _end,
                onChanged: (DateTime value) => setState(() => _end = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Motivo da alteracao',
                  hintText: 'Informe por que o horario esta sendo alterado',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_validationMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _validationMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: CostaNorteBrand.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.event_available_rounded),
          label: const Text('Confirmar reagendamento'),
        ),
      ],
    );
  }

  Widget _dateTimeTile({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return OutlinedButton(
      onPressed: () => _pickDateTime(value, onChanged),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text('$label: ${_dateTimeLabel(value)}')),
              const Icon(Icons.edit_calendar_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime(
    DateTime current,
    ValueChanged<DateTime> onChanged,
  ) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 3),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  void _submit() {
    final String reason = _reasonController.text.trim();
    final String? validationMessage = reason.isEmpty
        ? 'Informe o motivo do reagendamento.'
        : !_end.isAfter(_start)
        ? 'O fim deve ser posterior ao inicio.'
        : null;
    if (validationMessage != null) {
      setState(() => _validationMessage = validationMessage);
      return;
    }
    Navigator.of(context).pop(
      _MaintenanceRescheduleDraft(start: _start, end: _end, reason: reason),
    );
  }
}

enum _MaintenanceOrderAction {
  edit,
  reschedule,
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
    this.notificationType,
  });

  final MaintenanceOrder order;
  final bool sharing;
  final bool loadingHistory;
  final MaintenanceNotificationType? notificationType;

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
    final DateTime? scheduledEndAt = order.scheduledEndAt;
    final bool scheduledWindowEnded =
        order.status == MaintenanceOrderStatus.scheduled &&
        scheduledEndAt != null &&
        !DateTime.now().isBefore(scheduledEndAt);
    final bool canComplete =
        order.status == MaintenanceOrderStatus.inProgress ||
        scheduledWindowEnded;
    final bool canCancel =
        order.status != MaintenanceOrderStatus.completed &&
        order.status != MaintenanceOrderStatus.cancelled;
    return AlertDialog(
      title: Text(
        notificationType == MaintenanceNotificationType.dueToStart
            ? 'Hora de iniciar a ordem'
            : notificationType == MaintenanceNotificationType.overdue
            ? 'Horario previsto encerrado'
            : 'Ordem do dia',
      ),
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
          if (notificationType != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              notificationType == MaintenanceNotificationType.dueToStart
                  ? 'Confirme o inicio, edite ou reagende se necessario.'
                  : 'Conclua a ordem se o servico terminou ou reagende se precisar de mais tempo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
                onPressed: canEdit
                    ? () => Navigator.of(
                        context,
                      ).pop(_MaintenanceOrderAction.reschedule)
                    : null,
                icon: const Icon(Icons.event_repeat_rounded),
                label: Text(
                  order.scheduledStartAt == null ? 'Agendar' : 'Reagendar',
                ),
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
                label: Text(sharing ? 'Preparando...' : 'Avisar no WhatsApp'),
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
    this.initialLocationId,
    this.initialProviderId,
    this.launcherLabel,
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenanceOrder? initialOrder;
  final int? initialLocationId;
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
    _locationId =
        order?.locationId ??
        widget.initialLocationId ??
        widget.locations.first.id;
    _providerId = order?.providerId ?? widget.initialProviderId;
    _orderKind = order?.orderKind ?? MaintenanceOrderKind.corrective;
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

  String? get _selectedProviderWhatsapp {
    final MaintenanceProvider? provider = _selectedProvider;
    return provider == null
        ? null
        : maintenanceProviderWhatsappNumber(provider);
  }

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
                        ? 'Selecione um prestador para a ordem.'
                        : _selectedProviderWhatsapp == null
                        ? 'Aviso manual indisponível: configure número e habilite WhatsApp no cadastro.'
                        : 'Aviso manual disponível: $_selectedProviderWhatsapp',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    ...widget.providers.map(
                      (MaintenanceProvider item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(_maintenanceProviderDisplayName(item)),
                      ),
                    ),
                  ],
                  onChanged: (int? value) =>
                      setState(() => _providerId = value),
                ),
                const SizedBox(height: 12),
              ] else ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(
                    _selectedProvider == null
                        ? 'Prestador não encontrado'
                        : _maintenanceProviderDisplayName(_selectedProvider!),
                  ),
                  subtitle: Text(
                    _selectedProviderWhatsapp == null
                        ? 'WhatsApp não informado'
                        : 'WhatsApp: $_selectedProviderWhatsapp',
                  ),
                ),
                const SizedBox(height: 4),
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
        message: 'Selecione um prestador para a ordem.',
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
                        '${_maintenanceProviderDisplayName(item)} - ${item.specialty.label}',
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
    required this.isSupervisor,
  });

  final List<MaintenanceLocation> locations;
  final List<MaintenanceProvider> providers;
  final MaintenanceAppService service;
  final bool isSupervisor;

  @override
  State<_MaintenanceCatalogsDialog> createState() =>
      _MaintenanceCatalogsDialogState();
}

class _MaintenanceCatalogsDialogState
    extends State<_MaintenanceCatalogsDialog> {
  late List<MaintenanceLocation> _locations;
  late List<MaintenanceProvider> _providers;
  int _selectedCatalog = 0;
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
      maxWidth: 1080,
      maxHeight: 760,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          final Widget catalogSelector = compact
              ? _buildCompactCatalogSelector()
              : SizedBox(width: 220, child: _buildCatalogNavigation());
          final Widget content = _selectedCatalog == 0
              ? _CatalogLocationPane(
                  key: const ValueKey<String>('locations'),
                  locations: _locations,
                  service: widget.service,
                  onHistoryError: _setHistoryError,
                  onCreate: _createLocation,
                  onUpdate: _updateLocation,
                  onDelete: widget.isSupervisor ? _deleteLocation : null,
                )
              : _CatalogProviderPane(
                  key: const ValueKey<String>('providers'),
                  providers: _providers,
                  service: widget.service,
                  onHistoryError: _setHistoryError,
                  onCreate: _createProvider,
                  onUpdate: _updateProvider,
                  onDelete: widget.isSupervisor ? _deleteProvider : null,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CostaNorteBrand.foam,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: CostaNorteBrand.royalBlueDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Catálogos de manutenção',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Organize os locais atendidos e quem executa cada serviço.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_historyError != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _historyError!,
                  style: const TextStyle(color: CostaNorteBrand.error),
                ),
              ],
              const SizedBox(height: 20),
              if (compact) ...<Widget>[
                catalogSelector,
                const SizedBox(height: 16),
              ],
              Expanded(
                child: compact
                    ? content
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          catalogSelector,
                          const VerticalDivider(width: 32),
                          Expanded(child: content),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactCatalogSelector() {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        ButtonSegment<int>(
          value: 0,
          icon: const Icon(Icons.place_outlined),
          label: Text('Locais (${_locations.length})'),
        ),
        ButtonSegment<int>(
          value: 1,
          icon: const Icon(Icons.groups_outlined),
          label: Text('Prestadores (${_providers.length})'),
        ),
      ],
      selected: <int>{_selectedCatalog},
      onSelectionChanged: (Set<int> value) {
        setState(() {
          _selectedCatalog = value.first;
          _historyError = null;
        });
      },
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? CostaNorteBrand.royalBlueDeep
              : CostaNorteBrand.mutedInk;
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? CostaNorteBrand.foam
              : Colors.white;
        }),
      ),
      showSelectedIcon: false,
    );
  }

  Widget _buildCatalogNavigation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'GESTÃO DE CATÁLOGOS',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 10),
        _CatalogNavigationCard(
          selected: _selectedCatalog == 0,
          icon: Icons.place_outlined,
          title: 'Locais',
          description: 'Quartos, chalés e áreas comuns',
          count: _locations.length,
          onTap: () => _selectCatalog(0),
        ),
        const SizedBox(height: 10),
        _CatalogNavigationCard(
          selected: _selectedCatalog == 1,
          icon: Icons.groups_outlined,
          title: 'Prestadores',
          description: 'Equipe interna e prestadores',
          count: _providers.length,
          onTap: () => _selectCatalog(1),
        ),
      ],
    );
  }

  void _selectCatalog(int index) {
    setState(() {
      _selectedCatalog = index;
      _historyError = null;
    });
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

  Future<void> _deleteLocation(int locationId) async {
    await widget.service.deleteLocation(locationId);
    setState(() {
      _locations = _locations
          .where((MaintenanceLocation item) => item.id != locationId)
          .toList();
    });
  }

  Future<void> _deleteProvider(int providerId) async {
    await widget.service.deleteProvider(providerId);
    setState(() {
      _providers = _providers
          .where((MaintenanceProvider item) => item.id != providerId)
          .toList();
    });
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

class _CatalogNavigationCard extends StatelessWidget {
  const _CatalogNavigationCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CostaNorteBrand.foam : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? CostaNorteBrand.royalBlue : CostaNorteBrand.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                color: selected
                    ? CostaNorteBrand.royalBlueDeep
                    : CostaNorteBrand.mutedInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: CostaNorteBrand.ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
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
}

class _CatalogLocationPane extends StatefulWidget {
  const _CatalogLocationPane({
    super.key,
    required this.locations,
    required this.service,
    required this.onHistoryError,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
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
  final Future<void> Function(int)? onDelete;

  @override
  State<_CatalogLocationPane> createState() => _CatalogLocationPaneState();
}

class _CatalogLocationPaneState extends State<_CatalogLocationPane> {
  MaintenanceLocation? _selected;
  bool _showEditor = false;
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
    return _showEditor
        ? _buildLocationCatalogForm()
        : _buildLocationCatalogList();
  }

  Widget _buildLocationCatalogList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Locais cadastrados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filled(
              tooltip: 'Adicionar local',
              onPressed: _startCreate,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${_filteredLocations.length} de ${widget.locations.length} locais',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
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
          Text(
            _selected == null ? 'Adicionar local' : 'Editar local',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            _selected == null
                ? 'Cadastre um novo espaço para receber ordens.'
                : 'Atualize os dados de ${_catalogLocationTitle(_selected!)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
                  onPressed: _saving ? null : _closeEditor,
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
          if (_selected != null && widget.onDelete != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Excluir local'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CostaNorteBrand.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _dismissActiveInput() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _load(MaintenanceLocation item) {
    _dismissActiveInput();
    setState(() {
      _showEditor = true;
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
    _dismissActiveInput();
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

  void _startCreate() {
    _clear();
    setState(() => _showEditor = true);
  }

  void _closeEditor() {
    _clear();
    setState(() => _showEditor = false);
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
      if (mounted) {
        setState(() => _showEditor = false);
      }
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

  Future<void> _deleteSelected() async {
    final MaintenanceLocation? location = _selected;
    final Future<void> Function(int)? onDelete = widget.onDelete;
    if (location == null || onDelete == null) {
      return;
    }
    final bool confirmed = await AppAlerts.confirm(
      context,
      title: 'Excluir local',
      message:
          'Deseja excluir ${_catalogLocationTitle(location)}? Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await onDelete(location.id);
      if (!mounted) return;
      _closeEditor();
      await AppAlerts.success(
        context,
        title: 'Local excluído',
        message: 'O local foi removido do catálogo.',
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.error(
        context,
        title: 'Não foi possível excluir',
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
    super.key,
    required this.providers,
    required this.service,
    required this.onHistoryError,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
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
  final Future<void> Function(int)? onDelete;

  @override
  State<_CatalogProviderPane> createState() => _CatalogProviderPaneState();
}

class _CatalogProviderPaneState extends State<_CatalogProviderPane> {
  MaintenanceProvider? _selected;
  bool _showEditor = false;
  late final TextEditingController _searchController;
  late final TextEditingController _nameController;
  late final TextEditingController _serviceLabelController;
  late final TextEditingController _scopeController;
  late final TextEditingController _contactController;
  late final TextEditingController _whatsappController;
  MaintenanceProviderType _type = MaintenanceProviderType.internal;
  MaintenanceProviderSpecialty _specialty =
      MaintenanceProviderSpecialty.generalMaintenance;
  bool _active = true;
  bool _whatsappEnabled = false;
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
    _whatsappController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _serviceLabelController.dispose();
    _scopeController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  List<MaintenanceProvider> get _filteredProviders {
    final List<MaintenanceProvider> canonicalProviders =
        canonicalMaintenanceProviders(widget.providers);
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return canonicalProviders;
    }
    return canonicalProviders.where((MaintenanceProvider item) {
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
    return _showEditor
        ? _buildProviderCatalogForm()
        : _buildProviderCatalogList();
  }

  Widget _buildProviderCatalogList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Prestadores cadastrados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filled(
              tooltip: 'Adicionar prestador',
              onPressed: _startCreate,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${_filteredProviders.length} prestadores',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Buscar prestador',
            hintText: 'Nome, serviço, WhatsApp...',
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
                    title: Text(_maintenanceProviderDisplayName(item)),
                    subtitle: Text(
                      '${item.providerType.label} · ${item.specialty.label} · ${_normalizeMaintenanceServiceLabel(item.serviceLabel)}'
                      '${(item.whatsappNumber ?? item.contact ?? '').isEmpty ? '' : ' · ${(item.whatsappNumber ?? item.contact)!}'}',
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
      ],
    );
  }

  Widget _buildProviderCatalogForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _selected == null ? 'Adicionar prestador' : 'Editar prestador',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            _selected == null
                ? 'Cadastre a equipe interna ou um prestador externo.'
                : 'Atualize os dados de ${_maintenanceProviderDisplayName(_selected!)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
              if (value != null) {
                setState(() {
                  _specialty = value;
                  if (value == MaintenanceProviderSpecialty.doorsAndWindows) {
                    _serviceLabelController.text = value.label;
                  }
                });
              }
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
            decoration: const InputDecoration(
              labelText: 'Contato geral',
              hintText: 'Telefone, e-mail ou observação',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappController,
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
            value: _whatsappEnabled,
            onChanged: (bool value) => setState(() => _whatsappEnabled = value),
            title: const Text('Disponível para contato por WhatsApp'),
            subtitle: const Text(
              'O operador prepara e envia o aviso manualmente.',
            ),
          ),
          const SizedBox(height: 4),
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
                  onPressed: _saving ? null : _closeEditor,
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
          if (_selected != null && widget.onDelete != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Excluir prestador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CostaNorteBrand.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _dismissActiveInput() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _load(MaintenanceProvider item) {
    _dismissActiveInput();
    setState(() {
      _showEditor = true;
      _selected = item;
      _type = item.providerType;
      _specialty = item.specialty;
      _nameController.text = _maintenanceProviderDisplayName(item);
      _serviceLabelController.text = _normalizeMaintenanceServiceLabel(
        item.serviceLabel,
      );
      _scopeController.text = item.scopeDescription ?? '';
      _contactController.text = item.contact ?? '';
      _whatsappController.text = item.whatsappNumber ?? '';
      _whatsappEnabled = item.whatsappEnabled;
      _active = item.active;
    });
  }

  void _clear() {
    _dismissActiveInput();
    setState(() {
      _selected = null;
      _type = MaintenanceProviderType.internal;
      _specialty = MaintenanceProviderSpecialty.generalMaintenance;
      _nameController.clear();
      _serviceLabelController.clear();
      _scopeController.clear();
      _contactController.clear();
      _whatsappController.clear();
      _whatsappEnabled = false;
      _active = true;
    });
  }

  void _startCreate() {
    _clear();
    setState(() => _showEditor = true);
  }

  void _closeEditor() {
    _clear();
    setState(() => _showEditor = false);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _serviceLabelController.text.trim().isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Informe nome e servico do prestador.',
      );
      return;
    }
    final String? normalizedWhatsapp = _normalizeWhatsappNumber(
      _whatsappController.text,
    );
    if (_whatsappController.text.trim().isNotEmpty &&
        normalizedWhatsapp == null) {
      await AppAlerts.warning(
        context,
        title: 'WhatsApp invalido',
        message:
            'Informe o numero no formato internacional, por exemplo 5511999998888.',
      );
      return;
    }
    if (_whatsappEnabled && normalizedWhatsapp == null) {
      await AppAlerts.warning(
        context,
        title: 'WhatsApp obrigatório',
        message:
            'Informe um número válido para habilitar o contato por WhatsApp.',
      );
      return;
    }
    setState(() => _saving = true);
    final String serviceLabel =
        _specialty == MaintenanceProviderSpecialty.doorsAndWindows
        ? _specialty.label
        : _serviceLabelController.text.trim();
    final String providerName =
        _specialty == MaintenanceProviderSpecialty.doorsAndWindows
        ? _specialty.label
        : _nameController.text.trim();
    try {
      late final MaintenanceProvider savedProvider;
      if (_selected == null) {
        savedProvider = await widget.onCreate(
          CreateMaintenanceProviderModel(
            providerType: _type,
            specialty: _specialty,
            name: providerName,
            serviceLabel: serviceLabel,
            scopeDescription: _scopeController.text,
            contact: _contactController.text.trim(),
            active: _active,
            whatsappNumber: normalizedWhatsapp,
            whatsappEnabled: _whatsappEnabled,
          ),
        );
      } else {
        savedProvider = await widget.onUpdate(
          _selected!.id,
          UpdateMaintenanceProviderModel(
            providerType: _type,
            specialty: _specialty,
            name: providerName,
            serviceLabel: serviceLabel,
            scopeDescription: _scopeController.text,
            contact: _contactController.text.trim(),
            active: _active,
            whatsappNumber: normalizedWhatsapp,
            whatsappEnabled: _whatsappEnabled,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      _load(savedProvider);
      await AppAlerts.success(
        context,
        title: 'Prestador salvo',
        message: 'As alteracoes foram confirmadas pelo servidor.',
      );
      if (mounted) {
        _closeEditor();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Prestadores',
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
        title: 'Historico de ${_maintenanceProviderDisplayName(provider)}',
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

  Future<void> _deleteSelected() async {
    final MaintenanceProvider? provider = _selected;
    final Future<void> Function(int)? onDelete = widget.onDelete;
    if (provider == null || onDelete == null) {
      return;
    }
    final bool confirmed = await AppAlerts.confirm(
      context,
      title: 'Excluir prestador',
      message:
          'Deseja excluir ${_maintenanceProviderDisplayName(provider)}? Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await onDelete(provider.id);
      if (!mounted) return;
      _closeEditor();
      await AppAlerts.success(
        context,
        title: 'Prestador excluído',
        message: 'O prestador foi removido do catálogo.',
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlerts.error(
        context,
        title: 'Não foi possível excluir',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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

String _normalizeMaintenanceServiceLabel(String value) {
  final String normalized = value.trim();
  if (RegExp(
    r'^(?:servi(?:cio|ço)\s+(?:de\s+)?)?(?:mantenimiento|manteniento|manuten[cç][aã]o)\s+de\s+aires?(?:\s+acondicionados?)?$',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return MaintenanceProviderSpecialty.airConditioning.label;
  }
  if (RegExp(
    r'^(?:AA|ar[ -]?condicionado|aires?[ -]?acondicionados?)$',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return MaintenanceProviderSpecialty.airConditioning.label;
  }
  if (RegExp(r'^internet$', caseSensitive: false).hasMatch(normalized)) {
    return MaintenanceProviderSpecialty.internet.label;
  }
  return normalized;
}

String _normalizeMaintenanceProviderName(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return 'Sem prestador';
  }
  if (RegExp(
    r'^(?:servi(?:cio|ço)\s+(?:de\s+)?)?(?:mantenimiento|manteniento|manuten[cç][aã]o)\s+de\s+aires?(?:\s+acondicionados?)?$',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return 'Manutenção de ar-condicionado';
  }
  if (RegExp(r'\binternet\b', caseSensitive: false).hasMatch(normalized)) {
    return MaintenanceProviderSpecialty.internet.label;
  }
  return normalized;
}

String _maintenanceProviderDisplayName(MaintenanceProvider provider) {
  if (provider.specialty == MaintenanceProviderSpecialty.doorsAndWindows) {
    return MaintenanceProviderSpecialty.doorsAndWindows.label;
  }
  return _normalizeMaintenanceProviderName(provider.name);
}

String _normalizeMaintenanceLocationLabel(String value) {
  String normalized = value.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  normalized = normalized.replaceAll(
    RegExp(r'\b(?:area|área)s?\s+comu(?:m|ns)\b', caseSensitive: false),
    'Área comum',
  );
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

DateTime _startOfWeek(DateTime value) {
  final DateTime date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

MaintenanceOrderStatus? _maintenanceStatusOrNull(String apiValue) {
  for (final MaintenanceOrderStatus status in MaintenanceOrderStatus.values) {
    if (status.apiValue == apiValue) {
      return status;
    }
  }
  return null;
}

MaintenancePriority? _maintenancePriorityOrNull(String apiValue) {
  for (final MaintenancePriority priority in MaintenancePriority.values) {
    if (priority.apiValue == apiValue) {
      return priority;
    }
  }
  return null;
}

DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

TimeOfDay _addMinutes(TimeOfDay value, int minutesToAdd) {
  final int totalMinutes = value.hour * 60 + value.minute + minutesToAdd;
  return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
}
