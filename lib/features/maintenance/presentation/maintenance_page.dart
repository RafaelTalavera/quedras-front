import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/feedback/app_share.dart';
import '../../../core/sync/auto_refresh_controller.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../../core/widgets/horizontal_scrollable_container.dart';
import '../application/maintenance_app_service.dart';
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

enum MaintenanceSection {
  operationalSummary,
  selectedDay,
  monthlyAgenda,
  summary,
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
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final MaintenanceAppService maintenanceAppService;
  final MaintenancePageController? controller;
  final ValueChanged<MaintenanceSection>? onSectionChanged;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _operationalSummaryKey = GlobalKey();
  final GlobalKey _selectedDayKey = GlobalKey();
  final GlobalKey _monthlyAgendaKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();

  late final AutoRefreshController _autoRefreshController;
  List<MaintenanceLocation> _locations = const <MaintenanceLocation>[];
  List<MaintenanceProvider> _providers = const <MaintenanceProvider>[];
  List<MaintenanceOrder> _orders = const <MaintenanceOrder>[];
  MaintenanceSummaryReport? _summaryReport;
  late DateTime _selectedDate;
  late DateTime _reportStartDate;
  late DateTime _reportEndDate;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingSummary = false;
  bool _saving = false;
  int? _sharingOrderId;
  String? _errorMessage;
  String? _summaryErrorMessage;
  int? _selectedOrderId;
  int? _selectedLocationId;
  MaintenanceSection _currentSection = MaintenanceSection.operationalSummary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _scrollController.addListener(_handleScroll);
    _selectedDate = _today();
    _reportStartDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _reportEndDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    _autoRefreshController = AutoRefreshController(
      interval: AppRuntimeConfig.operationalRefreshInterval,
      onRefresh: () => _load(showLoading: false),
      canRefresh: _canAutoRefresh,
    );
    _autoRefreshController.start();
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
    _autoRefreshController.dispose();
    widget.controller?._detach(this);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoRefreshController.handleLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _load(showLoading: false);
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
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _editOrder,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _shareOrderToWhatsApp,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Compartir'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _startOrder,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Iniciar'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _completeOrder,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Concluir'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _cancelOrder,
                  icon: const Icon(Icons.cancel_schedule_send_rounded),
                  label: const Text('Cancelar'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _selectedOrder == null
                      ? null
                      : _manageAttachments,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Anexos'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _manageCatalogs,
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Catalogos'),
                ),
                OutlinedButton.icon(
                  onPressed: _canRefreshPage ? _refreshPage : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_refreshingData ? 'Atualizando...' : 'Atualizar'),
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
          else ...<Widget>[
            KeyedSubtree(
              key: _operationalSummaryKey,
              child: _buildOperationalSummaryCard(),
            ),
            const SizedBox(height: 18),
            KeyedSubtree(key: _selectedDayKey, child: _buildSelectedDayCard()),
            const SizedBox(height: 18),
            KeyedSubtree(key: _monthlyAgendaKey, child: _buildAgendaCard()),
            const SizedBox(height: 18),
            KeyedSubtree(key: _summaryKey, child: _buildSummaryCard()),
          ],
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

  MaintenanceLocation? get _selectedLocation {
    if (_selectedLocationId == null) {
      return null;
    }
    for (final MaintenanceLocation location in _locations) {
      if (location.id == _selectedLocationId) {
        return location;
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

  List<MaintenanceOrder> get _focusedDayOrders {
    final int? locationId = _selectedLocationId;
    if (locationId == null) {
      return _dayOrders;
    }
    return _dayOrders
        .where((MaintenanceOrder order) => order.locationId == locationId)
        .toList();
  }

  List<MaintenanceOrder> get _focusedPendingDayOrders {
    return _focusedDayOrders.where(_isPendingOrder).toList()
      ..sort((MaintenanceOrder a, MaintenanceOrder b) {
        return a.referenceDate.compareTo(b.referenceDate);
      });
  }

  List<MaintenanceOrder> get _focusedResolvedDayOrders {
    return _focusedDayOrders
        .where((MaintenanceOrder order) => !_isPendingOrder(order))
        .toList()
      ..sort((MaintenanceOrder a, MaintenanceOrder b) {
        return b.referenceDate.compareTo(a.referenceDate);
      });
  }

  void _handleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final Map<MaintenanceSection, BuildContext?> contexts =
          <MaintenanceSection, BuildContext?>{
            MaintenanceSection.operationalSummary:
                _operationalSummaryKey.currentContext,
            MaintenanceSection.selectedDay: _selectedDayKey.currentContext,
            MaintenanceSection.monthlyAgenda: _monthlyAgendaKey.currentContext,
            MaintenanceSection.summary: _summaryKey.currentContext,
          };
      const double anchorY = 180;
      MaintenanceSection best = _currentSection;
      double? bestDistance;
      for (final MapEntry<MaintenanceSection, BuildContext?> entry
          in contexts.entries) {
        final RenderObject? renderObject = entry.value?.findRenderObject();
        if (renderObject is! RenderBox) {
          continue;
        }
        final double distance =
            (renderObject.localToGlobal(Offset.zero).dy - anchorY).abs();
        if (bestDistance == null || distance < bestDistance) {
          bestDistance = distance;
          best = entry.key;
        }
      }
      _setCurrentSection(best);
    });
  }

  Future<void> _scrollToSection(MaintenanceSection section) async {
    final BuildContext? target = switch (section) {
      MaintenanceSection.operationalSummary =>
        _operationalSummaryKey.currentContext,
      MaintenanceSection.selectedDay => _selectedDayKey.currentContext,
      MaintenanceSection.monthlyAgenda => _monthlyAgendaKey.currentContext,
      MaintenanceSection.summary => _summaryKey.currentContext,
    };
    if (target == null) {
      return;
    }
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
    _setCurrentSection(section);
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
      _summaryErrorMessage = null;
    });
    try {
      final String monthStart = _formatDateApi(
        DateTime(_selectedDate.year, _selectedDate.month, 1),
      );
      final String monthEnd = _formatDateApi(
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
      );
      final List<MaintenanceLocation> locations = await widget
          .maintenanceAppService
          .listLocations();
      final List<MaintenanceProvider> providers = await widget
          .maintenanceAppService
          .listProviders();
      final List<MaintenanceOrder> orders = await widget.maintenanceAppService
          .listOrders(dateFrom: monthStart, dateTo: monthEnd);
      final MaintenanceSummaryReport summaryReport = await widget
          .maintenanceAppService
          .getSummaryReport(
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = locations;
        _providers = providers;
        _orders = orders;
        _summaryReport = summaryReport;
        _loading = false;
        _refreshingData = false;
        _loadingSummary = false;
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
        _loadingSummary = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  bool get _canRefreshPage =>
      !_loading && !_refreshingData && !_loadingSummary && !_saving;

  bool _canAutoRefresh() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return mounted &&
        !_loading &&
        !_refreshingData &&
        !_loadingSummary &&
        !_saving &&
        (route?.isCurrent ?? true);
  }

  Future<void> _refreshPage() async {
    if (!_canRefreshPage) {
      return;
    }
    await _load(showLoading: false);
  }

  Widget _buildSelectedDayCard() {
    final MaintenanceLocation? selectedLocation = _selectedLocation;
    final int openCount = _focusedPendingDayOrders
        .where(
          (MaintenanceOrder order) =>
              order.status == MaintenanceOrderStatus.open,
        )
        .length;
    final int inProgressCount = _focusedPendingDayOrders
        .where(
          (MaintenanceOrder order) =>
              order.status == MaintenanceOrderStatus.inProgress,
        )
        .length;
    final int completedCount = _focusedResolvedDayOrders
        .where(
          (MaintenanceOrder order) =>
              order.status == MaintenanceOrderStatus.completed,
        )
        .length;
    final int activeLocations = _focusedPendingDayOrders
        .map((MaintenanceOrder order) => order.locationId)
        .toSet()
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
                        selectedLocation == null
                            ? 'Dia selecionado'
                            : 'Dia selecionado em foco',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedLocation == null
                            ? _fullDate(_selectedDate)
                            : '${_fullDate(_selectedDate)} - ${selectedLocation.label}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickSelectedDate,
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Alterar dia'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (selectedLocation != null) ...<Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _tag('Local: ${selectedLocation.label}'),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedLocationId = null),
                    icon: const Icon(Icons.layers_clear_rounded),
                    label: const Text('Ver todos os locais'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metricChip(
                  selectedLocation == null ? 'Pendentes' : 'Pendentes do local',
                  '${_focusedPendingDayOrders.length}',
                  Icons.pending_actions_rounded,
                ),
                _metricChip(
                  'Abertas',
                  '$openCount',
                  Icons.assignment_late_rounded,
                ),
                _metricChip(
                  'Em andamento',
                  '$inProgressCount',
                  Icons.handyman_rounded,
                ),
                _metricChip(
                  'Concluidas',
                  '$completedCount',
                  Icons.task_alt_rounded,
                ),
                _metricChip(
                  selectedLocation == null ? 'Locais ativos' : 'Locais em foco',
                  '$activeLocations',
                  Icons.apartment_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildPendingDayView(),
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
            Text(
              'Resumo por local',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Painel permanente com apartamentos, chalets e areas comuns do dia selecionado.',
              style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildPendingDayView() {
    if (_focusedDayOrders.isEmpty) {
      return _emptyBox(
        _selectedLocation == null
            ? 'Nao ha ordens registradas para este dia.'
            : 'Nao ha ordens registradas para este local no dia selecionado.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pendencias priorizadas para o dia',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'A lista abaixo destaca o que ainda precisa de acao operacional.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: CostaNorteBrand.mutedInk),
        ),
        const SizedBox(height: 16),
        if (_focusedPendingDayOrders.isEmpty)
          _emptyBox(
            _selectedLocation == null
                ? 'Nao ha ordens pendentes para este dia.'
                : 'Nao ha ordens pendentes para este local neste dia.',
          )
        else
          ..._focusedPendingDayOrders.map(
            (MaintenanceOrder order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOrderTile(
                order,
                onDoubleTap: () => _openOrderActionDialog(order),
              ),
            ),
          ),
        if (_focusedResolvedDayOrders.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Ja resolvidas no dia',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ..._focusedResolvedDayOrders.map(
            (MaintenanceOrder order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOrderTile(
                order,
                onDoubleTap: () => _openOrderActionDialog(order),
              ),
            ),
          ),
        ],
      ],
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
                      _buildSectionLocationLayout(section, group.locations),
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

  Widget _buildSectionLocationLayout(
    _MaintenanceDepartmentSectionData section,
    List<_MaintenanceDepartmentLocationData> locations,
  ) {
    switch (section.layout) {
      case _MaintenanceSectionLayout.adaptive:
        return _buildAdaptiveLocationWrap(locations);
      case _MaintenanceSectionLayout.fixedGrid:
        return _buildFixedLocationGrid(
          locations,
          crossAxisCount: section.crossAxisCount,
        );
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
        final double itemWidth =
            (maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: locations
              .map(
                (_MaintenanceDepartmentLocationData item) => SizedBox(
                  width: itemWidth,
                  child: _MaintenanceLocationCard(
                    title: _summaryLabelForLocation(item.location),
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
    List<_MaintenanceDepartmentLocationData> locations,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double maxCardWidth = maxWidth >= 420 ? 420 : maxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locations
                .map(
                  (_MaintenanceDepartmentLocationData item) => ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 150,
                      maxWidth: maxCardWidth,
                    ),
                    child: _MaintenanceLocationCard(
                      title: _summaryLabelForLocation(item.location),
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

  Widget _buildAgendaCard() {
    final List<_MaintenanceDayCell> cells = _calendarCells();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Agenda mensal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _selectedDate.month - 1,
                    decoration: const InputDecoration(
                      labelText: 'Mes da agenda',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      _monthLabels.length,
                      (int index) => DropdownMenuItem<int>(
                        value: index,
                        child: Text(_monthLabels[index]),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value == null) {
                        return;
                      }
                      _changeMonth(value + 1);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: _weekLabels
                  .map(
                    (String label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: CostaNorteBrand.mutedInk),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 92,
              ),
              itemBuilder: (BuildContext context, int index) {
                final _MaintenanceDayCell cell = cells[index];
                if (!cell.inMonth) {
                  return const SizedBox.shrink();
                }
                final DateTime date = cell.date!;
                return _MaintenanceAgendaDayCard(
                  date: date,
                  orders: cell.orders,
                  selected: _sameDay(date, _selectedDate),
                  onTap: () => setState(() => _selectedDate = date),
                  onDoubleTap: () => _openDayOrderActions(date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final MaintenanceSummaryReport? summary = _summaryReport;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Resumo do periodo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Consolidado por estado, responsavel e tipo de local no periodo consultado.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _loadingSummary ? null : _pickReportStart,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text('Inicio: ${_shortDate(_reportStartDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingSummary ? null : _pickReportEnd,
                  icon: const Icon(Icons.event_rounded),
                  label: Text('Fim: ${_shortDate(_reportEndDate)}'),
                ),
                FilledButton.icon(
                  onPressed: _loadingSummary ? null : _reloadSummary,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_loadingSummary ? 'Buscando...' : 'Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_summaryErrorMessage != null) ...<Widget>[
              Text(
                _summaryErrorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 12),
            ],
            if (summary == null)
              _emptyBox('O resumo ainda nao esta disponivel.')
            else ...<Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _metricChip(
                    'Abertas',
                    '${summary.openCount}',
                    Icons.pending_rounded,
                  ),
                  _metricChip(
                    'Atribuidas',
                    '${summary.assignedCount}',
                    Icons.assignment_ind_rounded,
                  ),
                  _metricChip(
                    'Agendadas',
                    '${summary.scheduledCount}',
                    Icons.calendar_month_rounded,
                  ),
                  _metricChip(
                    'Em andamento',
                    '${summary.inProgressCount}',
                    Icons.handyman_rounded,
                  ),
                  _metricChip(
                    'Concluidas',
                    '${summary.completedCount}',
                    Icons.task_alt_rounded,
                  ),
                  _metricChip(
                    'Urgentes',
                    '${summary.urgentCount}',
                    Icons.priority_high_rounded,
                  ),
                  _metricChip(
                    'Sem responsavel',
                    '${summary.unassignedCount}',
                    Icons.person_off_rounded,
                  ),
                  _metricChip(
                    'Prioridade hospede',
                    '${summary.guestPriorityCount}',
                    Icons.hotel_rounded,
                  ),
                  _metricChip(
                    'Resolucao media',
                    '${summary.averageResolutionHours.toStringAsFixed(1)}h',
                    Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildBreakdownBlock(
                title: 'Por responsavel',
                groupBy: MaintenanceSummaryGroupBy.provider,
                items: summary.providerBreakdown,
              ),
              const SizedBox(height: 16),
              _buildBreakdownBlock(
                title: 'Por tipo de responsavel',
                groupBy: MaintenanceSummaryGroupBy.providerType,
                items: summary.providerTypeBreakdown,
              ),
              const SizedBox(height: 16),
              _buildBreakdownBlock(
                title: 'Por tipo de local',
                groupBy: MaintenanceSummaryGroupBy.locationType,
                items: summary.locationTypeBreakdown,
              ),
              const SizedBox(height: 16),
              _buildBreakdownBlock(
                title: 'Por estado',
                groupBy: MaintenanceSummaryGroupBy.status,
                items: summary.statusBreakdown,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownBlock({
    required String title,
    required MaintenanceSummaryGroupBy groupBy,
    required List<MaintenanceSummaryBreakdown> items,
  }) {
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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _emptyBox('Nenhum dado encontrado para esse agrupamento.')
          else
            HorizontalScrollableContainer(
              child: DataTable(
                columnSpacing: 16,
                columns: const <DataColumn>[
                  DataColumn(label: Text('Grupo')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Abertas')),
                  DataColumn(label: Text('Agendadas')),
                  DataColumn(label: Text('Em andamento')),
                  DataColumn(label: Text('Concluidas')),
                  DataColumn(label: Text('Canceladas')),
                  DataColumn(label: Text('Urgentes')),
                ],
                rows: items
                    .map(
                      (MaintenanceSummaryBreakdown item) => DataRow(
                        cells: <DataCell>[
                          DataCell(
                            InkWell(
                              onTap: () => _openSummaryDetails(groupBy, item),
                              child: Text(item.label),
                            ),
                          ),
                          DataCell(Text('${item.totalCount}')),
                          DataCell(Text('${item.openCount}')),
                          DataCell(Text('${item.scheduledCount}')),
                          DataCell(Text('${item.inProgressCount}')),
                          DataCell(Text('${item.completedCount}')),
                          DataCell(Text('${item.cancelledCount}')),
                          DataCell(Text('${item.urgentCount}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
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
          color: selected ? CostaNorteBrand.foam : Colors.white,
          border: Border.all(
            color: selected ? CostaNorteBrand.royalBlue : CostaNorteBrand.line,
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
              '${order.locationLabelSnapshot} Â· ${order.providerLabel}',
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
                  _tag('Asignado: ${order.assignedUsername}'),
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
                        ? 'Compartindo...'
                        : 'Compartir',
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

  bool _isPendingOrder(MaintenanceOrder order) {
    return order.status != MaintenanceOrderStatus.completed &&
        order.status != MaintenanceOrderStatus.cancelled;
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

    final Map<String, List<_MaintenanceDepartmentLocationData>>
    apartmentGroups = <String, List<_MaintenanceDepartmentLocationData>>{};
    for (final MaintenanceLocation location in apartments) {
      final String groupLabel = _floorLabelForLocation(location);
      apartmentGroups.putIfAbsent(
        groupLabel,
        () => <_MaintenanceDepartmentLocationData>[],
      );
      apartmentGroups[groupLabel]!.add(
        _buildDepartmentLocationData(
          location,
          dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
        ),
      );
    }

    final List<_MaintenanceDepartmentGroupData> apartmentGroupList =
        apartmentGroups.entries
            .map(
              (
                MapEntry<String, List<_MaintenanceDepartmentLocationData>>
                entry,
              ) => _MaintenanceDepartmentGroupData(
                title: entry.key,
                locations: entry.value,
              ),
            )
            .toList()
          ..sort(
            (
              _MaintenanceDepartmentGroupData a,
              _MaintenanceDepartmentGroupData b,
            ) => _departmentGroupSortValue(
              a.title,
            ).compareTo(_departmentGroupSortValue(b.title)),
          );

    final List<_MaintenanceDepartmentLocationData> commonAreaLocations =
        commonAreas
            .map(
              (MaintenanceLocation location) => _buildDepartmentLocationData(
                location,
                dayOrdersByLocation[location.id] ?? const <MaintenanceOrder>[],
              ),
            )
            .toList();

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
        title: 'Apartamentos',
        description: 'Quartos e unidades internas organizados por piso.',
        icon: Icons.apartment_rounded,
        tint: CostaNorteBrand.royalBlueDeep,
        layout: _MaintenanceSectionLayout.fixedGrid,
        crossAxisCount: 6,
        groups: apartmentGroupList,
      ),
      _MaintenanceDepartmentSectionData(
        title: 'Areas comuns',
        description: 'Lobby, circulacoes e espacos coletivos do hotel.',
        icon: Icons.weekend_rounded,
        tint: CostaNorteBrand.goldDeep,
        layout: _MaintenanceSectionLayout.adaptive,
        groups: <_MaintenanceDepartmentGroupData>[
          _MaintenanceDepartmentGroupData(
            title: 'Espacos compartilhados',
            locations: commonAreaLocations,
          ),
        ],
      ),
      _MaintenanceDepartmentSectionData(
        title: 'Chalets',
        description: 'Unidades externas com manutencao dedicada.',
        icon: Icons.cabin_rounded,
        tint: CostaNorteBrand.success,
        layout: _MaintenanceSectionLayout.fixedGrid,
        crossAxisCount: 6,
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
      return floor;
    }
    final int? sequence = _locationSequence(location);
    if (sequence != null && sequence >= 100) {
      return 'Piso ${sequence ~/ 100}';
    }
    if (_locationCategory(location) == _MaintenanceLocationCategory.chalet) {
      return 'Chalets';
    }
    return 'Sem piso';
  }

  String _subtitleForLocation(MaintenanceLocation location) {
    final String code = location.code.trim();
    final String floor = _floorLabelForLocation(location);
    switch (_locationCategory(location)) {
      case _MaintenanceLocationCategory.apartment:
        if (code.isEmpty) {
          return floor;
        }
        return '$floor · $code';
      case _MaintenanceLocationCategory.chalet:
        return code.isEmpty ? 'Unidade externa' : code;
      case _MaintenanceLocationCategory.commonArea:
        return code.isEmpty ? 'Area comum' : 'Area comum · $code';
    }
  }

  String _summaryLabelForLocation(MaintenanceLocation location) {
    final String code = location.code.trim();
    final String baseLabel = code.isNotEmpty ? code : location.label.trim();
    if (_locationCategory(location) == _MaintenanceLocationCategory.chalet) {
      return _compactChaletLabel(baseLabel);
    }
    return baseLabel;
  }

  String _compactChaletLabel(String value) {
    final String compact = value.replaceFirst(
      RegExp(r'^\s*chalets?\s*[-#:]*\s*', caseSensitive: false),
      '',
    );
    final String normalized = compact.trim();
    return normalized.isEmpty ? value.trim() : normalized;
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
    return '${location.code} ${location.label}'.toLowerCase();
  }

  int _sortLocations(MaintenanceLocation a, MaintenanceLocation b) {
    final int categoryCompare = _locationCategory(
      a,
    ).index.compareTo(_locationCategory(b).index);
    if (categoryCompare != 0) {
      return categoryCompare;
    }
    final int floorCompare = _departmentGroupSortValue(
      _floorLabelForLocation(a),
    ).compareTo(_departmentGroupSortValue(_floorLabelForLocation(b)));
    if (floorCompare != 0) {
      return floorCompare;
    }
    final int? aSequence = _locationSequence(a);
    final int? bSequence = _locationSequence(b);
    if (aSequence != null && bSequence != null && aSequence != bSequence) {
      return aSequence.compareTo(bSequence);
    }
    return a.label.compareTo(b.label);
  }

  int _departmentGroupSortValue(String label) {
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(label);
    return int.tryParse(match?.group(1) ?? '') ?? 9999;
  }

  int? _locationSequence(MaintenanceLocation location) {
    final String fingerprint = '${location.code} ${location.label}';
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(fingerprint);
    return int.tryParse(match?.group(1) ?? '');
  }

  Future<void> _openLocationDailyView(
    MaintenanceLocation location,
    List<MaintenanceOrder> dayOrders,
  ) async {
    setState(() {
      _selectedLocationId = location.id;
      if (_selectedLocationId != null &&
          !_focusedDayOrders.any(
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
          title: Text(location.label),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
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
                          tileColor: Colors.white,
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

  Widget _metricChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CostaNorteBrand.mist,
        borderRadius: BorderRadius.circular(16),
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

  List<_MaintenanceDayCell> _calendarCells() {
    final DateTime monthStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final int daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final int leadingEmpty = monthStart.weekday - 1;
    final List<_MaintenanceDayCell> cells = <_MaintenanceDayCell>[];
    for (int index = 0; index < leadingEmpty; index++) {
      cells.add(_MaintenanceDayCell.empty());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        day,
      );
      final List<MaintenanceOrder> orders = _orders
          .where(
            (MaintenanceOrder order) => _sameDay(order.referenceDate, date),
          )
          .toList();
      cells.add(_MaintenanceDayCell(date: date, orders: orders));
    }
    while (cells.length % 7 != 0) {
      cells.add(_MaintenanceDayCell.empty());
    }
    return cells;
  }

  Future<void> _changeMonth(int month) async {
    final DateTime nextDate = DateTime(_selectedDate.year, month, 1);
    setState(() {
      _selectedDate = nextDate;
    });
    await _load();
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
    final bool monthChanged = picked.month != _selectedDate.month;
    setState(() {
      _selectedDate = picked;
    });
    if (monthChanged) {
      await _load();
    }
  }

  Future<void> _pickReportStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportStartDate,
      firstDate: DateTime(_selectedDate.year - 2, 1, 1),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _reportStartDate = picked;
      if (_reportStartDate.isAfter(_reportEndDate)) {
        _reportEndDate = _reportStartDate;
      }
    });
  }

  Future<void> _pickReportEnd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportEndDate,
      firstDate: DateTime(_selectedDate.year - 2, 1, 1),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _reportEndDate = picked;
      if (_reportEndDate.isBefore(_reportStartDate)) {
        _reportStartDate = _reportEndDate;
      }
    });
  }

  Future<void> _reloadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryErrorMessage = null;
    });
    try {
      final MaintenanceSummaryReport summaryReport = await widget
          .maintenanceAppService
          .getSummaryReport(
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _summaryReport = summaryReport;
        _loadingSummary = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSummary = false;
        _summaryErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _createOrder() async {
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
              : history.first.locationLabelSnapshot,
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

  Future<void> _openDayOrderActions(DateTime date) async {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
    final MaintenanceOrder? order = await _pickOrder(
      'Ordens do dia',
      emptyMessage: 'Nao ha ordens registradas para este dia.',
    );
    if (order == null || !mounted) {
      return;
    }
    await _openOrderActionDialog(order);
  }

  Future<void> _openOrderActionDialog(MaintenanceOrder order) async {
    final _MaintenanceOrderAction? action =
        await showDialog<_MaintenanceOrderAction>(
          context: context,
          builder: (BuildContext context) => _MaintenanceOrderActionDialog(
            order: order,
            sharing: _sharingOrderId == order.id,
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
    }
  }

  Future<MaintenanceOrder?> _pickOrder(
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
                  '${item.title} Â· ${item.locationLabelSnapshot} Â· ${item.providerNameSnapshot}',
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
      ..writeln('Local: ${order.locationLabelSnapshot}')
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
      buffer.writeln('Asignado a: ${order.assignedUsername}');
    }
    if (order.estimatedExecutionMinutes != null) {
      buffer.writeln('Tempo estimado: ${order.estimatedExecutionMinutes} min');
    }
    if ((order.description ?? '').trim().isNotEmpty) {
      buffer.writeln('Descricao: ${order.description!.trim()}');
    }
    return buffer.toString().trim();
  }

  Future<void> _openSummaryDetails(
    MaintenanceSummaryGroupBy groupBy,
    MaintenanceSummaryBreakdown breakdown,
  ) async {
    try {
      final MaintenanceSummaryDetail detail = await widget.maintenanceAppService
          .getSummaryDetails(
            groupBy: groupBy,
            code: breakdown.code,
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) =>
            _SummaryDetailsDialog(detail: detail),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Detalhe do resumo',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }
}

class _MaintenanceDayCell {
  const _MaintenanceDayCell({required this.date, required this.orders})
    : inMonth = true;

  const _MaintenanceDayCell.empty()
    : date = null,
      orders = const <MaintenanceOrder>[],
      inMonth = false;

  final DateTime? date;
  final List<MaintenanceOrder> orders;
  final bool inMonth;
}

enum _MaintenanceOrderAction {
  edit,
  share,
  start,
  complete,
  cancel,
  attachments,
}

class _MaintenanceOrderActionDialog extends StatelessWidget {
  const _MaintenanceOrderActionDialog({
    required this.order,
    required this.sharing,
  });

  final MaintenanceOrder order;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
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
            '${order.locationLabelSnapshot} Â· ${order.providerLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_MaintenanceOrderAction.edit),
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
                label: Text(sharing ? 'Compartindo...' : 'Compartir'),
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

class _MaintenanceAgendaDayCard extends StatelessWidget {
  const _MaintenanceAgendaDayCard({
    required this.date,
    required this.orders,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime date;
  final List<MaintenanceOrder> orders;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final bool hasUrgent = orders.any(
      (MaintenanceOrder order) => order.priority == MaintenancePriority.urgent,
    );
    final Color background = selected
        ? const Color(0xFFFFF3D8)
        : orders.isNotEmpty
        ? const Color(0xFFEAF1FF)
        : Colors.white;
    final Color border = selected
        ? CostaNorteBrand.goldDeep
        : orders.isNotEmpty
        ? CostaNorteBrand.royalBlue
        : CostaNorteBrand.line;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (hasUrgent)
                  const Icon(
                    Icons.priority_high_rounded,
                    size: 16,
                    color: CostaNorteBrand.error,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              '${orders.length} ordem(ns)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: CostaNorteBrand.mutedInk,
              ),
            ),
          ],
        ),
      ),
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
    this.crossAxisCount = 4,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final _MaintenanceSectionLayout layout;
  final List<_MaintenanceDepartmentGroupData> groups;
  final int crossAxisCount;

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
    required this.icon,
    required this.subtitle,
    required this.dayOrders,
  });

  final MaintenanceLocation location;
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? CostaNorteBrand.foam
              : visualState == _MaintenanceLocationVisualState.neutral
              ? Colors.white
              : Colors.white,
          border: Border.all(
            color: selected ? CostaNorteBrand.royalBlue : palette.borderColor,
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
    required this.priority,
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.guestName,
    required this.guestReference,
    required this.businessPriority,
    required this.estimatedExecutionMinutes,
    required this.assignedUsername,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int locationId;
  final int? providerId;
  final String title;
  final String? description;
  final MaintenancePriority priority;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? guestName;
  final String? guestReference;
  final MaintenanceBusinessPriority businessPriority;
  final int? estimatedExecutionMinutes;
  final String? assignedUsername;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  CreateMaintenanceOrderModel toCreateModel() {
    return CreateMaintenanceOrderModel(
      locationId: locationId,
      providerId: providerId,
      title: title,
      description: description,
      priority: priority,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      guestReference: guestReference,
      businessPriority: businessPriority,
      estimatedExecutionMinutes: estimatedExecutionMinutes,
      assignedUsername: assignedUsername,
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
      priority: priority,
      requestOrigin: requestOrigin,
      requestedForGuest: requestedForGuest,
      guestName: guestName,
      guestReference: guestReference,
      businessPriority: businessPriority,
      estimatedExecutionMinutes: estimatedExecutionMinutes,
      assignedUsername: assignedUsername,
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
  late MaintenancePriority _priority;
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
  late final TextEditingController _assignedUsernameController;
  late final TextEditingController _estimatedMinutesController;

  @override
  void initState() {
    super.initState();
    final MaintenanceOrder? order = widget.initialOrder;
    _locationId = order?.locationId ?? widget.locations.first.id;
    _providerId = order?.providerId;
    _priority = order?.priority ?? MaintenancePriority.medium;
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
    _assignedUsernameController = TextEditingController(
      text: order?.assignedUsername ?? '',
    );
    _estimatedMinutesController = TextEditingController(
      text: order?.estimatedExecutionMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _guestNameController.dispose();
    _guestReferenceController.dispose();
    _assignedUsernameController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
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
              DropdownButtonFormField<int>(
                value: _locationId,
                decoration: const InputDecoration(labelText: 'Local'),
                items: widget.locations
                    .map(
                      (MaintenanceLocation item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text('${item.label} · ${item.code}'),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  if (value != null) setState(() => _locationId = value);
                },
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
                decoration: const InputDecoration(labelText: 'Prestador'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sem responsavel definido'),
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
                controller: _assignedUsernameController,
                decoration: const InputDecoration(
                  labelText: 'Usuario asignado',
                ),
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
              TextFormField(
                controller: _estimatedMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tempo estimado (minutos)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MaintenancePriority>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade tecnica',
                ),
                items: MaintenancePriority.values
                    .map(
                      (MaintenancePriority item) =>
                          DropdownMenuItem<MaintenancePriority>(
                            value: item,
                            child: Text(item.label),
                          ),
                    )
                    .toList(),
                onChanged: (MaintenancePriority? value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 12),
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

    final String estimatedRaw = _estimatedMinutesController.text.trim();
    final int? estimatedMinutes = estimatedRaw.isEmpty
        ? null
        : int.tryParse(estimatedRaw);
    if (estimatedRaw.isNotEmpty &&
        (estimatedMinutes == null || estimatedMinutes <= 0)) {
      AppAlerts.warning(
        context,
        title: 'Tempo invalido',
        message: 'Informe um tempo estimado em minutos maior que zero.',
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
        priority: _priority,
        requestOrigin: _requestOrigin,
        requestedForGuest:
            _requestOrigin == MaintenanceRequestOrigin.guestRequest,
        guestName: guestName,
        guestReference: guestReference,
        businessPriority: _businessPriority,
        estimatedExecutionMinutes: startAt != null && endAt != null
            ? endAt.difference(startAt).inMinutes
            : estimatedMinutes,
        assignedUsername: _assignedUsernameController.text.trim().isEmpty
            ? null
            : _assignedUsernameController.text.trim(),
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
                    onCreate: _createLocation,
                    onUpdate: _updateLocation,
                  ),
                  _CatalogProviderPane(
                    providers: _providers,
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
        ..sort((MaintenanceLocation a, MaintenanceLocation b) {
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
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
            ..sort((MaintenanceLocation a, MaintenanceLocation b) {
              return a.label.toLowerCase().compareTo(b.label.toLowerCase());
            });
    });
    return location;
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
                label: const Text('Agregar foto'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () =>
                          _pickAndUpload(MaintenanceAttachmentType.attachment),
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Agregar arquivo'),
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
    required this.onCreate,
    required this.onUpdate,
  });

  final List<MaintenanceLocation> locations;
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListView(
            children: widget.locations
                .map(
                  (MaintenanceLocation item) => ListTile(
                    title: Text(item.label),
                    subtitle: Text(
                      '${item.locationType.label} - ${item.locationCategory.label} - ${item.code}',
                    ),
                    trailing: Text(item.active ? 'Ativo' : 'Inativo'),
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
                decoration: const InputDecoration(labelText: 'Codigo'),
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
    if (_codeController.text.trim().isEmpty ||
        _labelController.text.trim().isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Informe codigo e nome do local.',
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
            code: _codeController.text,
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
            code: _codeController.text,
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
}

class _CatalogProviderPane extends StatefulWidget {
  const _CatalogProviderPane({
    required this.providers,
    required this.onCreate,
    required this.onUpdate,
  });

  final List<MaintenanceProvider> providers;
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
                    trailing: Text(item.active ? 'Ativo' : 'Inativo'),
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

class _SummaryDetailsDialog extends StatelessWidget {
  const _SummaryDetailsDialog({required this.detail});

  final MaintenanceSummaryDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 940,
      maxHeight: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(detail.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _summaryTag('Total', '${detail.summary.totalCount}'),
              _summaryTag('Abertas', '${detail.summary.openCount}'),
              _summaryTag('Agendadas', '${detail.summary.scheduledCount}'),
              _summaryTag('Em andamento', '${detail.summary.inProgressCount}'),
              _summaryTag('Concluidas', '${detail.summary.completedCount}'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: detail.items.isEmpty
                ? _emptyScrollableBox(
                    'Nenhuma ordem encontrada para esse grupo.',
                  )
                : ListView.separated(
                    itemCount: detail.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final MaintenanceSummaryDetailItem item =
                          detail.items[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: CostaNorteBrand.line),
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.locationLabel} · ${item.providerName ?? 'Sem responsavel'} · ${item.status.label}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(item.priority.label),
                            Text(
                              item.businessPriority.label,
                              style: Theme.of(context).textTheme.bodySmall,
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
}

Widget _summaryTag(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: CostaNorteBrand.mist,
      border: Border.all(color: CostaNorteBrand.line),
    ),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: CostaNorteBrand.ink),
        children: <InlineSpan>[
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
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
