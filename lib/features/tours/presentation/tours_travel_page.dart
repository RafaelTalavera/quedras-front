import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audit/audit_models.dart';
import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/feedback/app_share.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/sync/schedule_sync_service.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../../core/widgets/horizontal_scrollable_container.dart';
import '../../../core/widgets/operational_timeline.dart';
import '../application/tours_app_service.dart';
import '../domain/tours_models.dart';

const List<String> _week = <String>[
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sab',
  'Dom',
];
const List<String> _months = <String>[
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

enum ToursTravelSection { selectedDay, monthlyAgenda, summary }

enum _ToursAgendaView { day, week, month }

enum _ToursTimelineFilter { paid, pending, cancelled }

class ToursTravelPageController {
  _ToursTravelPageState? _state;
  Future<void> scrollToSection(ToursTravelSection section) async =>
      _state?._scrollToSection(section);
  void _attach(_ToursTravelPageState state) => _state = state;
  void _detach(_ToursTravelPageState state) {
    if (identical(_state, state)) _state = null;
  }
}

class ToursTravelPage extends StatefulWidget {
  const ToursTravelPage({
    required this.toursAppService,
    required this.scheduleSyncService,
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final ToursAppService toursAppService;
  final ScheduleSyncService scheduleSyncService;
  final ToursTravelPageController? controller;
  final ValueChanged<ToursTravelSection>? onSectionChanged;

  @override
  State<ToursTravelPage> createState() => _ToursTravelPageState();
}

class _ToursTravelPageState extends State<ToursTravelPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;
  List<ToursProvider> _providers = <ToursProvider>[];
  List<ToursBooking> _bookings = <ToursBooking>[];
  ToursSummaryReport? _summaryReport;
  late DateTime _selectedDate;
  late DateTime _reportStart;
  late DateTime _reportEnd;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingAgenda = false;
  bool _loadingProviders = false;
  bool _saving = false;
  bool _loadingSummary = false;
  int? _sharingBookingId;
  int? _loadingHistoryBookingId;
  String? _error;
  String? _agendaError;
  String? _summaryError;
  ToursTravelSection _currentSection = ToursTravelSection.selectedDay;
  String? _loadedAgendaKey;
  String? _loadedSummaryKey;
  _ToursAgendaView _agendaView = _ToursAgendaView.week;
  _ToursTimelineFilter? _timelineFilter;

  List<ToursProvider> get _activeProviders =>
      _providers.where((ToursProvider p) => p.active).toList()..sort(
        (ToursProvider a, ToursProvider b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  List<ToursBooking> get _dayBookings => _bookings
      .where((ToursBooking b) => _sameDay(b.startAt, _selectedDate))
      .toList();
  List<ToursBooking> get _monthBookings =>
      _bookings
          .where(
            (ToursBooking b) =>
                b.startAt.year == _selectedDate.year &&
                b.startAt.month == _selectedDate.month,
          )
          .toList()
        ..sort(
          (ToursBooking a, ToursBooking b) => a.startAt.compareTo(b.startAt),
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _selectedDate = _today();
    _reportStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _reportEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    _syncSubscription = widget.scheduleSyncService.events.listen(
      _handleSyncEvent,
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant ToursTravelPage oldWidget) {
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
      unawaited(_refreshActiveData(showLoading: false));
    }
  }

  Future<void> _scrollToSection(ToursTravelSection section) async {
    await _showSection(section);
  }

  void _setCurrentSection(ToursTravelSection section) {
    if (_currentSection == section) return;
    _currentSection = section;
    widget.onSectionChanged?.call(section);
  }

  Future<void> _showSection(ToursTravelSection section) async {
    if (section == ToursTravelSection.monthlyAgenda) {
      await _openAgendaDialog();
      return;
    }
    if (section == ToursTravelSection.summary) {
      await _openSummaryDialog();
      return;
    }
    _setCurrentSection(section);
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) {
        _loading = true;
      } else {
        _refreshingData = true;
      }
      _error = null;
    });
    try {
      final DateTime rangeStart = _agendaView == _ToursAgendaView.week
          ? _weekStart(_selectedDate)
          : _agendaView == _ToursAgendaView.month
          ? _monthStart(_selectedDate)
          : _selectedDate;
      final DateTime rangeEnd = _agendaView == _ToursAgendaView.week
          ? rangeStart.add(const Duration(days: 6))
          : _agendaView == _ToursAgendaView.month
          ? _monthEnd(_selectedDate)
          : _selectedDate;
      final Future<List<ToursBooking>> bookingsFuture = widget.toursAppService
          .listBookings(
            dateFrom: _formatDate(rangeStart),
            dateTo: _formatDate(rangeEnd),
          );
      final List<ToursBooking> bookings = await bookingsFuture;
      if (!mounted) return;
      setState(() {
        _replaceCachedBookings(
          startDate: rangeStart,
          endDate: rangeEnd,
          bookings: bookings,
        );
        _loading = false;
        _refreshingData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshingData = false;
        _error = _describeError(error);
      });
    }
  }

  bool _canAutoRefresh() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return mounted &&
        !_loading &&
        !_refreshingData &&
        !_loadingAgenda &&
        !_loadingProviders &&
        !_loadingSummary &&
        !_saving &&
        (route?.isCurrent ?? true);
  }

  Future<void> _refreshActiveData({bool showLoading = false}) async {
    await _load(showLoading: showLoading);
    if (_currentSection == ToursTravelSection.monthlyAgenda) {
      await _loadAgenda(force: true);
    }
    if (_currentSection == ToursTravelSection.summary) {
      await _reloadSummary(force: true);
    }
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain != ScheduleSyncDomain.tours || !_canAutoRefresh()) {
      return;
    }
    if (!_isRelevantSyncEvent(event)) {
      return;
    }
    unawaited(_refreshActiveData(showLoading: false));
  }

  bool _isRelevantSyncEvent(ScheduleSyncEvent event) {
    switch (_currentSection) {
      case ToursTravelSection.selectedDay:
        return event.affectsDay(_selectedDate);
      case ToursTravelSection.monthlyAgenda:
        return event.affectsRange(
          DateTime(_selectedDate.year, _selectedDate.month, 1),
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
        );
      case ToursTravelSection.summary:
        return event.affectsRange(_reportStart, _reportEnd);
    }
  }

  Future<void> _setSelectedDate(DateTime date) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final bool dateChanged = !_sameDay(normalizedDate, _selectedDate);
    final bool monthChanged =
        normalizedDate.year != _selectedDate.year ||
        normalizedDate.month != _selectedDate.month;
    setState(() {
      _selectedDate = normalizedDate;
    });
    if (dateChanged || monthChanged) {
      await _load(showLoading: false);
      if (_currentSection == ToursTravelSection.monthlyAgenda) {
        await _loadAgenda(force: monthChanged);
      }
    }
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _weekStart(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));

  DateTime _monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);

  String _monthKeyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _summaryKeyFor(DateTime startDate, DateTime endDate) =>
      '${_formatDate(startDate)}|${_formatDate(endDate)}';

  bool get _hasAgendaForSelectedMonth =>
      _loadedAgendaKey == _monthKeyFor(_selectedDate);

  bool get _hasSummaryForSelectedRange =>
      _loadedSummaryKey == _summaryKeyFor(_reportStart, _reportEnd);

  Future<void> _loadAgenda({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _loadingAgenda = true;
      _agendaError = null;
    });
    try {
      final List<ToursBooking> bookings = await widget.toursAppService
          .listBookings(
            dateFrom: _formatDate(_monthStart(_selectedDate)),
            dateTo: _formatDate(_monthEnd(_selectedDate)),
          );
      if (!mounted) return;
      setState(() {
        _replaceCachedBookings(
          startDate: _monthStart(_selectedDate),
          endDate: _monthEnd(_selectedDate),
          bookings: bookings,
        );
        _loadedAgendaKey = _monthKeyFor(_selectedDate);
        _loadingAgenda = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAgenda = false;
        _agendaError = _describeError(error);
      });
    }
  }

  Future<void> _reloadSummary({bool force = false}) async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final Future<List<ToursBooking>> bookingsFuture = widget.toursAppService
          .listBookings(
            dateFrom: _formatDate(_reportStart),
            dateTo: _formatDate(_reportEnd),
          );
      final ToursSummaryReport summaryReport = await widget.toursAppService
          .getSummaryReport(
            dateFrom: _formatDate(_reportStart),
            dateTo: _formatDate(_reportEnd),
          );
      final List<ToursBooking> bookings = await bookingsFuture;
      if (!mounted) return;
      setState(() {
        _replaceCachedBookings(
          startDate: _reportStart,
          endDate: _reportEnd,
          bookings: bookings,
        );
        _summaryReport = summaryReport;
        _loadedSummaryKey = _summaryKeyFor(_reportStart, _reportEnd);
        _loadingSummary = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = _describeError(error);
      });
    }
  }

  Future<void> _openAgendaDialog() async {
    _setCurrentSection(ToursTravelSection.monthlyAgenda);
    await _loadAgenda();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialogShell(
          maxWidth: 1080,
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                children: <Widget>[
                  _buildSectionDialogHeader(
                    context,
                    title: 'Agenda mensal',
                    subtitle:
                        'Visualizacao mensal de tours e viagens com acesso rapido por dia.',
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildAgendaCard(
                        context,
                        asCard: false,
                        onDialogRefresh: () => setDialogState(() {}),
                        onDaySelected: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      _setCurrentSection(ToursTravelSection.selectedDay);
    }
  }

  Future<void> _openSummaryDialog() async {
    _setCurrentSection(ToursTravelSection.summary);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialogShell(
          maxWidth: 1120,
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                children: <Widget>[
                  _buildSectionDialogHeader(
                    context,
                    title: 'Periodo',
                    subtitle:
                        'Consolidado de agendamentos, horas, pagamentos e comissao para o intervalo consultado.',
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildSummaryCard(
                        context,
                        asCard: false,
                        onDialogRefresh: () => setDialogState(() {}),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      _setCurrentSection(ToursTravelSection.selectedDay);
    }
  }

  Widget _buildSectionDialogHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureProvidersLoaded({bool force = false}) async {
    if (!mounted) return false;
    setState(() {
      _loadingProviders = true;
      _error = null;
    });
    try {
      final List<ToursProvider> providers = await widget.toursAppService
          .listProviders();
      if (!mounted) return false;
      setState(() {
        _providers = providers;
        _loadingProviders = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _loadingProviders = false;
        _error = _describeError(error);
      });
      return false;
    }
  }

  void _replaceCachedBookings({
    required DateTime startDate,
    required DateTime endDate,
    required List<ToursBooking> bookings,
  }) {
    final DateTime normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final DateTime normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    final List<ToursBooking> nextBookings = _bookings.where((ToursBooking b) {
      final DateTime bookingDate = DateTime(
        b.startAt.year,
        b.startAt.month,
        b.startAt.day,
      );
      return bookingDate.isBefore(normalizedStart) ||
          bookingDate.isAfter(normalizedEnd);
    }).toList()..addAll(bookings);
    nextBookings.sort(
      (ToursBooking a, ToursBooking b) => a.startAt.compareTo(b.startAt),
    );
    _bookings = nextBookings;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            title: 'Tours e viagens',
            icon: Icons.explore_rounded,
            photoAlignment: Alignment.centerRight,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saving ? null : _createBooking,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Lancar agendamento'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSection(ToursTravelSection.monthlyAgenda),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Agenda'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSection(ToursTravelSection.summary),
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Periodo'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _loadingProviders
                      ? null
                      : _manageProvider,
                  icon: const Icon(Icons.business_rounded),
                  label: const Text('Fornecedores'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...<Widget>[
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
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
            _buildOperationalAgenda(context),
            const SizedBox(height: 18),
            _buildDayCard(context),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(BuildContext context) {
    final List<ToursBooking> scheduled = _dayBookings
        .where((ToursBooking b) => b.status == ToursBookingStatus.scheduled)
        .toList();
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
                        'Dia selecionado',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fullDate(_selectedDate),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metric(
                  context,
                  Icons.event_note_rounded,
                  'Agendados',
                  '${scheduled.length}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_dayBookings.isEmpty)
              _emptyBox(
                context,
                'Nao ha tours ou viagens registrados para este dia.',
              )
            else
              ..._dayBookings.map(
                (ToursBooking b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _bookingTile(
                    context,
                    b,
                    sharing: _sharingBookingId == b.id,
                    onEdit: _isBookingEditable(b)
                        ? () => _editBooking(booking: b)
                        : null,
                    onPayment: _canRegisterPayment(b)
                        ? () => _markPayment(booking: b)
                        : null,
                    onShare: () => _shareBooking(booking: b),
                    onCancel: _isBookingEditable(b)
                        ? () => _cancelBooking(booking: b)
                        : null,
                    onHistory: () => _openBookingHistory(b),
                    loadingHistory: _loadingHistoryBookingId == b.id,
                    onDoubleTap: () => _openBookingActionDialog(b),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalAgenda(BuildContext context) {
    final DateTime start = _agendaView == _ToursAgendaView.week
        ? _weekStart(_selectedDate)
        : _selectedDate;
    final List<DateTime> days = List<DateTime>.generate(
      _agendaView == _ToursAgendaView.week ? 7 : 1,
      (int index) => start.add(Duration(days: index)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<_ToursAgendaView>(
              style: operationalTimelineSegmentStyle(),
              segments: const <ButtonSegment<_ToursAgendaView>>[
                ButtonSegment(
                  value: _ToursAgendaView.day,
                  label: Text('Diaria'),
                ),
                ButtonSegment(
                  value: _ToursAgendaView.week,
                  label: Text('Semanal'),
                ),
                ButtonSegment(
                  value: _ToursAgendaView.month,
                  label: Text('Mensal'),
                ),
              ],
              selected: <_ToursAgendaView>{_agendaView},
              onSelectionChanged: (Set<_ToursAgendaView> value) {
                setState(() => _agendaView = value.first);
                unawaited(_load(showLoading: false));
              },
            ),
            const SizedBox(height: 14),
            if (_agendaView == _ToursAgendaView.month)
              _buildAgendaCard(context, asCard: false)
            else ...<Widget>[
              Row(
                children: <Widget>[
                  IconButton.outlined(
                    onPressed: () => _moveAgenda(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _setAgendaDate(_today()),
                    child: const Text('Hoje'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () => _moveAgenda(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Expanded(
                    child: Text('Horario operacional: 06:00 a 23:00'),
                  ),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 16,
                      runSpacing: 8,
                      children: <Widget>[
                        OperationalTimelineLegend(
                          color: CostaNorteBrand.royalBlueDeep,
                          label: 'Pago',
                          selected:
                              _timelineFilter == _ToursTimelineFilter.paid,
                          onTap: () =>
                              _toggleTimelineFilter(_ToursTimelineFilter.paid),
                        ),
                        OperationalTimelineLegend(
                          color: CostaNorteBrand.goldDeep,
                          label: 'Pendente',
                          selected:
                              _timelineFilter == _ToursTimelineFilter.pending,
                          onTap: () => _toggleTimelineFilter(
                            _ToursTimelineFilter.pending,
                          ),
                        ),
                        OperationalTimelineLegend(
                          color: CostaNorteBrand.error,
                          label: 'Cancelado',
                          selected:
                              _timelineFilter == _ToursTimelineFilter.cancelled,
                          onTap: () => _toggleTimelineFilter(
                            _ToursTimelineFilter.cancelled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OperationalTimeline<ToursBooking>(
                days: days,
                selectedDate: _selectedDate,
                events: _bookings
                    .where(_matchesTimelineFilter)
                    .map(
                      (
                        ToursBooking booking,
                      ) => OperationalTimelineEvent<ToursBooking>(
                        value: booking,
                        date: booking.startAt,
                        startMinutes:
                            booking.startAt.hour * 60 + booking.startAt.minute,
                        endMinutes:
                            booking.endAt.hour * 60 + booking.endAt.minute,
                        label:
                            '${booking.clientName} ${_time(booking.startAt)}-${_time(booking.endAt)}',
                        color: booking.status == ToursBookingStatus.cancelled
                            ? CostaNorteBrand.error
                            : booking.paid
                            ? CostaNorteBrand.royalBlueDeep
                            : CostaNorteBrand.goldDeep,
                        draggable: _isBookingEditable(booking),
                      ),
                    )
                    .toList(),
                onDayTap: _setAgendaDate,
                onEventTap: _openBookingActionDialog,
                onEventMove: _moveBookingFromTimeline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setAgendaDate(DateTime date) async {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    await _load(showLoading: false);
  }

  void _toggleTimelineFilter(_ToursTimelineFilter filter) {
    setState(() {
      _timelineFilter = _timelineFilter == filter ? null : filter;
    });
  }

  bool _matchesTimelineFilter(ToursBooking booking) {
    switch (_timelineFilter) {
      case _ToursTimelineFilter.paid:
        return booking.status != ToursBookingStatus.cancelled && booking.paid;
      case _ToursTimelineFilter.pending:
        return booking.status != ToursBookingStatus.cancelled && !booking.paid;
      case _ToursTimelineFilter.cancelled:
        return booking.status == ToursBookingStatus.cancelled;
      case null:
        return true;
    }
  }

  Future<void> _moveAgenda(int direction) async {
    final int days = _agendaView == _ToursAgendaView.week ? 7 : 1;
    await _setAgendaDate(_selectedDate.add(Duration(days: days * direction)));
  }

  Future<void> _moveBookingFromTimeline(
    ToursBooking booking,
    DateTime date,
    int startMinutes,
  ) async {
    final Duration duration = booking.endAt.difference(booking.startAt);
    final DateTime proposedStart = DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    final DateTime proposedEnd = proposedStart.add(duration);
    final bool overlap = _bookings.any(
      (ToursBooking item) =>
          item.id != booking.id &&
          item.status == ToursBookingStatus.scheduled &&
          proposedStart.isBefore(item.endAt) &&
          proposedEnd.isAfter(item.startAt),
    );
    if (overlap) {
      await AppAlerts.warning(
        context,
        title: 'Horario ocupado',
        message: 'Solte o agendamento em um horario livre para continuar.',
      );
      return;
    }
    await _editBooking(
      booking: booking,
      proposedStart: proposedStart,
      proposedEnd: proposedEnd,
    );
  }

  Widget _buildAgendaCard(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
    VoidCallback? onDaySelected,
  }) {
    final List<_DayCell> cells = _calendarCells();
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (asCard)
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
                  initialValue: _selectedDate.month - 1,
                  decoration: const InputDecoration(
                    labelText: 'Mes da agenda',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  items: List<DropdownMenuItem<int>>.generate(
                    _months.length,
                    (int i) => DropdownMenuItem<int>(
                      value: i,
                      child: Text(_months[i]),
                    ),
                  ),
                  onChanged: (int? value) {
                    if (value == null) return;
                    unawaited(
                      _setSelectedDate(
                        DateTime(_selectedDate.year, value + 1, 1),
                      ).then((_) => onDialogRefresh?.call()),
                    );
                  },
                ),
              ),
            ],
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                initialValue: _selectedDate.month - 1,
                decoration: const InputDecoration(
                  labelText: 'Mes da agenda',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  _months.length,
                  (int i) =>
                      DropdownMenuItem<int>(value: i, child: Text(_months[i])),
                ),
                onChanged: (int? value) {
                  if (value == null) return;
                  unawaited(
                    _setSelectedDate(
                      DateTime(_selectedDate.year, value + 1, 1),
                    ).then((_) => onDialogRefresh?.call()),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (_loadingAgenda && !_hasAgendaForSelectedMonth)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          if (_agendaError != null) ...<Widget>[
            Text(_agendaError!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 12),
          ],
          Row(
            children: _week
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: CostaNorteBrand.mutedInk,
                        ),
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
              final _DayCell cell = cells[index];
              if (!cell.inMonth) return const SizedBox.shrink();
              return _ToursAgendaDayCard(
                date: cell.date,
                bookings: cell.bookings,
                selected: _sameDay(cell.date, _selectedDate),
                onTap: () => unawaited(
                  _setSelectedDate(cell.date).then((_) {
                    if (onDaySelected != null) {
                      onDaySelected();
                    } else {
                      onDialogRefresh?.call();
                    }
                  }),
                ),
                onDoubleTap: () => _openCalendarDayActions(cell.date),
              );
            },
          ),
        ],
      ],
    );

    if (!asCard) return content;

    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
  }) {
    final ToursSummaryReport? summary = _summaryReport;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (asCard) ...<Widget>[
          Text(
            'Resumo do periodo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Consolidado de agendamentos, horas, pagamentos e comissao para o intervalo consultado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _loadingSummary
                  ? null
                  : () async {
                      await _pickReportStart();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.date_range_rounded),
              label: Text('Inicio: ${_short(_reportStart)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loadingSummary
                  ? null
                  : () async {
                      await _pickReportEnd();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.event_rounded),
              label: Text('Fim: ${_short(_reportEnd)}'),
            ),
            FilledButton.icon(
              onPressed: _loadingSummary
                  ? null
                  : () async {
                      await _reloadSummary(force: true);
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_loadingSummary ? 'Buscando...' : 'Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_summaryError != null) ...<Widget>[
          Text(_summaryError!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 12),
        ],
        if (_loadingSummary && !_hasSummaryForSelectedRange)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _metric(
                context,
                Icons.event_available_rounded,
                'Agendamentos',
                '${summary?.scheduledCount ?? 0}',
              ),
              _metric(
                context,
                Icons.cancel_schedule_send_rounded,
                'Cancelados',
                '${summary?.cancelledCount ?? 0}',
              ),
              _metric(
                context,
                Icons.schedule_rounded,
                'Horas',
                _hours(summary?.totalHours ?? 0),
              ),
              _metric(
                context,
                Icons.attach_money_rounded,
                'Cobrado',
                _money(summary?.grossAmount ?? 0),
              ),
              _metric(
                context,
                Icons.payments_rounded,
                'Recebido',
                _money(summary?.paidAmount ?? 0),
              ),
              _metric(
                context,
                Icons.hourglass_bottom_rounded,
                'Pendente',
                _money(summary?.pendingAmount ?? 0),
              ),
              _metric(
                context,
                Icons.account_balance_wallet_rounded,
                'Comissao',
                _money(summary?.commissionAmount ?? 0),
              ),
              _metric(
                context,
                Icons.savings_rounded,
                'Liquido',
                _money(summary?.netAmount ?? 0),
              ),
              _metric(
                context,
                Icons.stacked_line_chart_rounded,
                'Ticket medio',
                _money(summary?.averageTicket ?? 0),
              ),
            ],
          ),
        const SizedBox(height: 20),
        if (summary == null || _summaryIsEmpty(summary))
          _emptyBox(
            context,
            'Nenhum tour ou viagem possui dados ativos no periodo informado.',
          )
        else ...<Widget>[
          _buildSummaryTableSection(
            context,
            title: 'Resumo por prestador',
            description:
                'Clique no nome para abrir o detalhe dos bookings desse parceiro no periodo.',
            columns: const <DataColumn>[
              DataColumn(label: Text('Prestador')),
              DataColumn(label: Text('Agendados')),
              DataColumn(label: Text('Pagos')),
              DataColumn(label: Text('Pendentes')),
              DataColumn(label: Text('Horas')),
              DataColumn(label: Text('Cobrado')),
              DataColumn(label: Text('Comissao')),
            ],
            rows: summary.providerBreakdown
                .map(
                  (ToursSummaryBreakdown item) => DataRow(
                    cells: <DataCell>[
                      DataCell(
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            InkWell(
                              onTap: _loadingSummary
                                  ? null
                                  : () => _openSummaryDetails(
                                      groupBy: ToursSummaryGroupBy.provider,
                                      item: item,
                                    ),
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (item.active == false)
                              _summaryBadge(context, 'Inativo'),
                          ],
                        ),
                      ),
                      DataCell(Text('${item.scheduledCount}')),
                      DataCell(Text('${item.paidCount}')),
                      DataCell(Text('${item.pendingCount}')),
                      DataCell(Text(_hours(item.totalHours))),
                      DataCell(Text(_money(item.grossAmount))),
                      DataCell(Text(_money(item.commissionAmount))),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _buildSummaryTableSection(
            context,
            title: 'Resumo por tipo',
            description:
                'Tours e viagens separados por tipo de servico, com detalhe em modal.',
            columns: const <DataColumn>[
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Agendados')),
              DataColumn(label: Text('Pagos')),
              DataColumn(label: Text('Pendentes')),
              DataColumn(label: Text('Horas')),
              DataColumn(label: Text('Cobrado')),
              DataColumn(label: Text('Comissao')),
            ],
            rows: summary.serviceTypeBreakdown
                .map(
                  (ToursSummaryBreakdown item) => _summaryDataRow(
                    groupBy: ToursSummaryGroupBy.serviceType,
                    item: item,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _buildSummaryTableSection(
            context,
            title: 'Resumo por pagamento',
            description:
                'Meios de pagamento com dados do periodo e acesso ao detalhe das reservas pagas.',
            columns: const <DataColumn>[
              DataColumn(label: Text('Metodo')),
              DataColumn(label: Text('Pagos')),
              DataColumn(label: Text('Horas')),
              DataColumn(label: Text('Cobrado')),
              DataColumn(label: Text('Comissao')),
            ],
            rows: summary.paymentMethodBreakdown
                .map(
                  (ToursSummaryBreakdown item) => DataRow(
                    cells: <DataCell>[
                      DataCell(
                        InkWell(
                          onTap: _loadingSummary
                              ? null
                              : () => _openSummaryDetails(
                                  groupBy: ToursSummaryGroupBy.paymentMethod,
                                  item: item,
                                ),
                          child: Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      DataCell(Text('${item.paidCount}')),
                      DataCell(Text(_hours(item.totalHours))),
                      DataCell(Text(_money(item.grossAmount))),
                      DataCell(Text(_money(item.commissionAmount))),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );

    if (!asCard) return content;

    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    );
  }

  bool _summaryIsEmpty(ToursSummaryReport summary) {
    return summary.scheduledCount == 0 &&
        summary.cancelledCount == 0 &&
        summary.providerBreakdown.isEmpty &&
        summary.serviceTypeBreakdown.isEmpty &&
        summary.paymentMethodBreakdown.isEmpty;
  }

  Widget _buildSummaryTableSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<DataColumn> columns,
    required List<DataRow> rows,
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
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CostaNorteBrand.line),
            ),
            child: HorizontalScrollableContainer(
              child: DataTable(columnSpacing: 18, columns: columns, rows: rows),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _summaryDataRow({
    required ToursSummaryGroupBy groupBy,
    required ToursSummaryBreakdown item,
  }) {
    return DataRow(
      cells: <DataCell>[
        DataCell(
          InkWell(
            onTap: _loadingSummary
                ? null
                : () => _openSummaryDetails(groupBy: groupBy, item: item),
            child: Text(
              item.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        DataCell(Text('${item.scheduledCount}')),
        DataCell(Text('${item.paidCount}')),
        DataCell(Text('${item.pendingCount}')),
        DataCell(Text(_hours(item.totalHours))),
        DataCell(Text(_money(item.grossAmount))),
        DataCell(Text(_money(item.commissionAmount))),
      ],
    );
  }

  Widget _summaryBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CostaNorteBrand.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Future<void> _openSummaryDetails({
    required ToursSummaryGroupBy groupBy,
    required ToursSummaryBreakdown item,
  }) async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final ToursSummaryDetail detail = await widget.toursAppService
          .getSummaryDetail(
            groupBy: groupBy,
            groupKey: item.groupKey,
            dateFrom: _formatDate(_reportStart),
            dateTo: _formatDate(_reportEnd),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSummary = false;
      });
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AppDialogShell(
            maxWidth: AppDialogDimensions.wideFormWidth,
            maxHeight: 720,
            child: SingleChildScrollView(
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
                              detail.label,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${groupBy.label} · ${_short(_reportStart)} a ${_short(_reportEnd)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (detail.active == false)
                        _summaryBadge(context, 'Inativo'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _metric(
                        context,
                        Icons.event_available_rounded,
                        'Agendados',
                        '${detail.summary.scheduledCount}',
                      ),
                      _metric(
                        context,
                        Icons.schedule_rounded,
                        'Horas',
                        _hours(detail.summary.totalHours),
                      ),
                      _metric(
                        context,
                        Icons.attach_money_rounded,
                        'Cobrado',
                        _money(detail.summary.grossAmount),
                      ),
                      _metric(
                        context,
                        Icons.account_balance_wallet_rounded,
                        'Comissao',
                        _money(detail.summary.commissionAmount),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (detail.items.isEmpty)
                    _emptyBox(
                      context,
                      'Nenhum booking ativo encontrado para esse recorte.',
                    )
                  else
                    ...detail.items.map(
                      (ToursSummaryDetailItem booking) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSummaryDetailTile(context, booking),
                      ),
                    ),
                  const SizedBox(height: 8),
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
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSummary = false;
        _summaryError = _describeError(error);
      });
    }
  }

  Widget _buildSummaryDetailTile(
    BuildContext context,
    ToursSummaryDetailItem booking,
  ) {
    final Color color = booking.status == ToursBookingStatus.cancelled
        ? CostaNorteBrand.error
        : booking.paid
        ? CostaNorteBrand.success
        : CostaNorteBrand.goldDeep;
    final String paymentCopy = booking.status == ToursBookingStatus.cancelled
        ? (booking.description ?? 'Agendamento cancelado')
        : booking.paid
        ? 'Pago${booking.paymentMethod != null ? ' · ${booking.paymentMethod!.label}' : ''}'
        : 'Pagamento pendente';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CostaNorteBrand.line),
      ),
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
                      booking.clientName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hospede / unidade: ${booking.guestReference}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CostaNorteBrand.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  booking.status == ToursBookingStatus.cancelled
                      ? 'Cancelado'
                      : booking.paid
                      ? 'Pago'
                      : 'Pendente',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _summaryBadge(
                context,
                '${booking.serviceType.label} - ${_short(booking.startAt)} ${_time(booking.startAt)}-${_time(booking.endAt)}',
              ),
              _summaryBadge(context, booking.providerName),
              if ((booking.providerOfferingName ?? '').trim().isNotEmpty)
                _summaryBadge(context, booking.providerOfferingName!),
            ],
          ),
          Text(
            '${_money(booking.amount)} · Comissao ${_money(booking.commissionAmount)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(paymentCopy, style: Theme.of(context).textTheme.bodyMedium),
          if ((booking.description ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              booking.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  List<_DayCell> _calendarCells() {
    final DateTime firstDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final int daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final int leading = (firstDay.weekday + 6) % 7;
    final List<_DayCell> cells = <_DayCell>[];
    for (int i = 0; i < leading; i++) {
      cells.add(
        _DayCell(
          firstDay.subtract(Duration(days: leading - i)),
          const <ToursBooking>[],
          false,
        ),
      );
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        day,
      );
      cells.add(
        _DayCell(
          date,
          _monthBookings
              .where((ToursBooking b) => _sameDay(b.startAt, date))
              .toList(),
          true,
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(
        _DayCell(
          cells.last.date.add(const Duration(days: 1)),
          const <ToursBooking>[],
          false,
        ),
      );
    }
    return cells;
  }

  Future<void> _createBooking() async {
    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }
    if (_activeProviders.isEmpty) {
      await AppAlerts.info(
        context,
        title: 'Fornecedores',
        message:
            'Cadastre ao menos um fornecedor antes de lancar um tour ou viagem.',
      );
      return;
    }
    final _BookingDraft? draft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) => _BookingDialog(
        providers: _activeProviders,
        initialDate: _selectedDate,
      ),
    );
    if (draft == null) return;
    await _persist(
      () => widget.toursAppService.createBooking(draft.toCreateModel()),
      'Falha ao salvar agendamento',
    );
  }

  Future<void> _editBooking({
    ToursBooking? booking,
    DateTime? proposedStart,
    DateTime? proposedEnd,
  }) async {
    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }
    final ToursBooking? selected =
        booking ??
        await _pickBooking(
          'Editar agendamento',
          canSelect: _isBookingEditable,
          emptyMessage: 'Nao ha agendamentos ativos para editar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final List<ToursProvider> providers = _providers
        .where((ToursProvider p) => p.active || p.id == selected.providerId)
        .toList();
    final _BookingDraft? draft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) => _BookingDialog(
        providers: providers,
        initialDate: proposedStart ?? selected.startAt,
        booking: selected,
        proposedStart: proposedStart,
        proposedEnd: proposedEnd,
      ),
    );
    if (draft == null) return;
    await _persist(
      () => widget.toursAppService.updateBooking(
        selected.id,
        draft.toUpdateModel(),
      ),
      'Falha ao atualizar agendamento',
    );
  }

  Future<void> _markPayment({ToursBooking? booking}) async {
    final ToursBooking? selected =
        booking ??
        await _pickBooking(
          'Informar pago',
          canSelect: _canRegisterPayment,
          emptyMessage:
              'Todos os agendamentos deste dia ja estao pagos ou cancelados.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final _PaymentDraft? draft = await showDialog<_PaymentDraft>(
      context: context,
      builder: (BuildContext context) => const _PaymentDialog(),
    );
    if (draft == null) return;
    await _persist(
      () => widget.toursAppService.updatePayment(
        selected.id,
        UpdateToursPaymentModel(
          paymentMethod: draft.method,
          paymentDate: _formatDate(draft.date),
          paymentNotes: draft.notes,
        ),
      ),
      'Falha ao registrar pagamento',
    );
  }

  Future<void> _shareBooking({ToursBooking? booking}) async {
    final ToursBooking? selected =
        booking ??
        await _pickBooking(
          'Compartilhar',
          emptyMessage: 'Nao ha agendamentos para compartilhar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    if (_sharingBookingId != null) {
      return;
    }

    setState(() => _sharingBookingId = selected.id);
    try {
      await AppShare.shareText(
        context,
        text: _buildBookingShareMessage(selected),
        subject: 'Agendamento de ${selected.providerName}',
        failureTitle: 'Falha ao compartilhar',
        failureMessagePrefix:
            'Nao foi possivel preparar a mensagem do agendamento',
      );
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _sharingBookingId = null);
      }
    }
  }

  Future<void> _cancelBooking({ToursBooking? booking}) async {
    final ToursBooking? selected =
        booking ??
        await _pickBooking(
          'Cancelar agendamento',
          canSelect: _isBookingEditable,
          emptyMessage: 'Nao ha agendamentos ativos para cancelar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final String? notes = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _CancelDialog(),
    );
    if (notes == null) return;
    await _persist(
      () => widget.toursAppService.cancelBooking(
        selected.id,
        CancelToursBookingModel(cancellationNotes: notes),
      ),
      'Falha ao cancelar agendamento',
    );
  }

  Future<void> _openCalendarDayActions(DateTime date) async {
    await _setSelectedDate(date);
    final ToursBooking? booking = await _pickBooking(
      'Agendamentos do dia',
      emptyMessage: 'Nao ha tours ou viagens registrados para este dia.',
    );
    if (booking == null || !mounted) {
      return;
    }
    await _openBookingActionDialog(booking);
  }

  Future<void> _openBookingActionDialog(ToursBooking booking) async {
    final _ToursBookingAction? action = await showDialog<_ToursBookingAction>(
      context: context,
      builder: (BuildContext context) => _ToursBookingActionDialog(
        booking: booking,
        sharing: _sharingBookingId == booking.id,
        canEdit: _isBookingEditable(booking),
        canRegisterPayment: _canRegisterPayment(booking),
      ),
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _ToursBookingAction.edit:
        await _editBooking(booking: booking);
        return;
      case _ToursBookingAction.payment:
        await _markPayment(booking: booking);
        return;
      case _ToursBookingAction.share:
        await _shareBooking(booking: booking);
        return;
      case _ToursBookingAction.cancel:
        await _cancelBooking(booking: booking);
        return;
      case _ToursBookingAction.history:
        await _openBookingHistory(booking);
        return;
    }
  }

  Future<void> _openBookingHistory(ToursBooking booking) async {
    setState(() {
      _loadingHistoryBookingId = booking.id;
      _error = null;
    });
    try {
      final List<AuditEventModel> history = await widget.toursAppService
          .history(booking.id);
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${booking.clientName}',
        events: history,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Historico do agendamento',
        message: _describeError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingHistoryBookingId = null);
      }
    }
  }

  Future<void> _manageProvider() async {
    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }
    final _ProviderDraft? draft = await showDialog<_ProviderDraft>(
      context: context,
      builder: (BuildContext context) => _ProviderDialog(
        providers: _providers,
        toursAppService: widget.toursAppService,
      ),
    );
    if (draft == null) return;
    if (draft.id == null) {
      await _persist(
        () => widget.toursAppService.createProvider(
          CreateToursProviderModel(
            name: draft.name,
            contact: draft.contact,
            defaultCommissionPercent: draft.defaultCommission,
            offerings: draft.offerings
                .map(
                  (_ProviderOfferingDraft item) =>
                      ToursProviderOfferingInputModel(
                        serviceType: item.serviceType,
                        name: item.name,
                        amount: item.amount,
                        description: item.description,
                        active: item.active,
                      ),
                )
                .toList(),
          ),
        ),
        'Falha ao salvar fornecedor',
      );
    } else {
      await _persist(
        () => widget.toursAppService.updateProvider(
          draft.id!,
          UpdateToursProviderModel(
            name: draft.name,
            contact: draft.contact,
            defaultCommissionPercent: draft.defaultCommission,
            offerings: draft.offerings
                .map(
                  (_ProviderOfferingDraft item) =>
                      ToursProviderOfferingInputModel(
                        serviceType: item.serviceType,
                        name: item.name,
                        amount: item.amount,
                        description: item.description,
                        active: item.active,
                      ),
                )
                .toList(),
            active: draft.active,
          ),
        ),
        'Falha ao salvar fornecedor',
      );
    }
    await _ensureProvidersLoaded(force: true);
  }

  Future<void> _persist(Future<Object?> Function() action, String title) async {
    setState(() => _saving = true);
    try {
      await action();
      await _load(showLoading: false);
      if (_hasAgendaForSelectedMonth) {
        await _loadAgenda(force: true);
      }
      if (_hasSummaryForSelectedRange) {
        await _reloadSummary(force: true);
      }
    } catch (error) {
      if (mounted) {
        await AppAlerts.error(
          context,
          title: title,
          message: _describeError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<ToursBooking?> _pickBooking(
    String title, {
    bool Function(ToursBooking booking)? canSelect,
    String? emptyMessage,
  }) async {
    final List<ToursBooking> items = canSelect == null
        ? _dayBookings
        : _dayBookings.where(canSelect).toList();
    if (items.isEmpty) {
      if (!mounted || emptyMessage == null) {
        return null;
      }
      await AppAlerts.info(context, title: title, message: emptyMessage);
      return null;
    }
    return showDialog<ToursBooking>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(title),
        children: items
            .map(
              (ToursBooking b) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(b),
                child: Text(
                  '${_time(b.startAt)} - ${_time(b.endAt)} · ${b.clientName} · ${b.providerName}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  bool _isBookingEditable(ToursBooking booking) {
    return booking.status == ToursBookingStatus.scheduled;
  }

  bool _canRegisterPayment(ToursBooking booking) {
    return booking.status == ToursBookingStatus.scheduled && !booking.paid;
  }

  String _buildBookingShareMessage(ToursBooking booking) {
    ToursProvider? provider;
    for (final ToursProvider item in _providers) {
      if (item.id == booking.providerId) {
        provider = item;
        break;
      }
    }
    final String paymentLine = booking.status == ToursBookingStatus.cancelled
        ? 'Estado: cancelado'
        : booking.paid
        ? 'Pago em ${_short(booking.paymentDate ?? _today())} via ${booking.paymentMethod?.label ?? 'meio nao informado'}'
        : 'Pagamento pendente';
    final StringBuffer buffer = StringBuffer()
      ..writeln('Agendamento Hotel Costa Norte')
      ..writeln('${booking.serviceType.label}: ${booking.clientName}')
      ..writeln(
        'Horario: ${_fullDate(_dateOnly(booking.startAt))} | ${_time(booking.startAt)} - ${_time(booking.endAt)}',
      )
      ..writeln('Prestador: ${booking.providerName}')
      ..writeln(
        'Contato: ${provider != null && provider.contact.isNotEmpty ? provider.contact : 'nao informado'}',
      )
      ..writeln('Valor: ${_money(booking.amount)}')
      ..writeln('Comissao: ${_money(booking.commissionAmount)}')
      ..writeln(paymentLine);
    if ((booking.guestReference).trim().isNotEmpty) {
      buffer.writeln('Referencia: ${booking.guestReference}');
    }
    if ((booking.description ?? '').trim().isNotEmpty) {
      buffer.writeln('Observacoes: ${booking.description!.trim()}');
    }
    return buffer.toString().trim();
  }

  Future<void> _pickSelectedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1, 1, 1),
      lastDate: DateTime(_selectedDate.year + 1, 12, 31),
    );
    if (picked != null) {
      await _setSelectedDate(picked);
    }
  }

  Future<void> _pickReportStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportStart,
      firstDate: DateTime(_selectedDate.year - 2, 1, 1),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _reportStart = DateTime(picked.year, picked.month, picked.day);
        if (_reportStart.isAfter(_reportEnd)) _reportEnd = _reportStart;
        _loadedSummaryKey = null;
        _summaryReport = null;
        _summaryError = null;
      });
    }
  }

  Future<void> _pickReportEnd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportEnd,
      firstDate: DateTime(_selectedDate.year - 2, 1, 1),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _reportEnd = DateTime(picked.year, picked.month, picked.day);
        if (_reportEnd.isBefore(_reportStart)) _reportStart = _reportEnd;
        _loadedSummaryKey = null;
        _summaryReport = null;
        _summaryError = null;
      });
    }
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: CostaNorteBrand.mist,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CostaNorteBrand.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: CostaNorteBrand.royalBlueDeep),
        const SizedBox(width: 10),
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

  Widget _emptyBox(BuildContext context, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: CostaNorteBrand.mist,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: CostaNorteBrand.line),
    ),
    child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
  );

  Widget _bookingTile(
    BuildContext context,
    ToursBooking b, {
    VoidCallback? onEdit,
    VoidCallback? onPayment,
    VoidCallback? onShare,
    VoidCallback? onCancel,
    VoidCallback? onHistory,
    VoidCallback? onDoubleTap,
    bool sharing = false,
    bool loadingHistory = false,
  }) {
    final Color color = b.status == ToursBookingStatus.cancelled
        ? CostaNorteBrand.error
        : b.paid
        ? CostaNorteBrand.success
        : CostaNorteBrand.goldDeep;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onDoubleTap: onDoubleTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CostaNorteBrand.line),
          color: CostaNorteBrand.mint,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: b.serviceType == ToursServiceType.tour
                        ? const Color(0xFFE8F0FF)
                        : const Color(0xFFFFF3DB),
                  ),
                  child: Text(
                    b.serviceType.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CostaNorteBrand.royalBlueDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: color.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    b.status == ToursBookingStatus.cancelled
                        ? 'Cancelado'
                        : b.paid
                        ? 'Pago'
                        : 'Pendente',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_time(b.startAt)} - ${_time(b.endAt)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(b.clientName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Prestador: ${b.providerName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Hospede / unidade: ${b.guestReference}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CostaNorteBrand.mutedInk),
            ),
            if (b.providerOfferingName != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                b.providerOfferingName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CostaNorteBrand.royalBlueDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (b.description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                b.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _pill(context, 'Valor', _money(b.amount)),
                _pill(
                  context,
                  'Comissao',
                  '${b.commissionPercent.toStringAsFixed(1)}% · ${_money(b.commissionAmount)}',
                ),
                _pill(
                  context,
                  'Pagamento',
                  b.status == ToursBookingStatus.cancelled
                      ? 'Cancelado'
                      : b.paid
                      ? '${_short(b.paymentDate ?? _today())} · ${b.paymentMethod?.label ?? 'Meio nao informado'}'
                      : 'Pendente',
                ),
              ],
            ),
            if (onEdit != null ||
                onPayment != null ||
                onShare != null ||
                onCancel != null ||
                onHistory != null) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar'),
                    ),
                  if (onPayment != null)
                    OutlinedButton.icon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.payments_rounded),
                      label: const Text('Informar pago'),
                    ),
                  if (onShare != null)
                    OutlinedButton.icon(
                      onPressed: sharing ? null : onShare,
                      icon: Icon(
                        sharing
                            ? Icons.hourglass_top_rounded
                            : Icons.send_rounded,
                      ),
                      label: Text(
                        sharing ? 'Compartilhando...' : 'Compartilhar',
                      ),
                    ),
                  if (onHistory != null)
                    OutlinedButton.icon(
                      onPressed: loadingHistory ? null : onHistory,
                      icon: Icon(
                        loadingHistory
                            ? Icons.hourglass_top_rounded
                            : Icons.history_rounded,
                      ),
                      label: Text(
                        loadingHistory ? 'Carregando...' : 'Historico',
                      ),
                    ),
                  if (onCancel != null)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_schedule_send_rounded),
                      label: const Text('Cancelar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: CostaNorteBrand.foam,
    ),
    child: Text(
      '$label: $value',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

enum _ToursBookingAction { edit, payment, share, cancel, history }

class _ToursBookingActionDialog extends StatelessWidget {
  const _ToursBookingActionDialog({
    required this.booking,
    required this.sharing,
    required this.canEdit,
    required this.canRegisterPayment,
  });

  final ToursBooking booking;
  final bool sharing;
  final bool canEdit;
  final bool canRegisterPayment;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agendamento do dia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            booking.clientName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${booking.serviceType.label} · ${_time(booking.startAt)} - ${_time(booking.endAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () => Navigator.of(context).pop(_ToursBookingAction.edit)
                    : null,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: canRegisterPayment
                    ? () =>
                          Navigator.of(context).pop(_ToursBookingAction.payment)
                    : null,
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Informar pago'),
              ),
              OutlinedButton.icon(
                onPressed: sharing
                    ? null
                    : () =>
                          Navigator.of(context).pop(_ToursBookingAction.share),
                icon: Icon(
                  sharing ? Icons.hourglass_top_rounded : Icons.send_rounded,
                ),
                label: Text(sharing ? 'Compartilhando...' : 'Compartilhar'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_ToursBookingAction.history),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Historico'),
              ),
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () =>
                          Navigator.of(context).pop(_ToursBookingAction.cancel)
                    : null,
                icon: const Icon(Icons.cancel_schedule_send_rounded),
                label: const Text('Cancelar'),
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

class _DayCell {
  const _DayCell(this.date, this.bookings, this.inMonth);
  final DateTime date;
  final List<ToursBooking> bookings;
  final bool inMonth;
}

class _ToursAgendaDayCard extends StatelessWidget {
  const _ToursAgendaDayCard({
    required this.date,
    required this.bookings,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime date;
  final List<ToursBooking> bookings;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final bool hasBookings = bookings.isNotEmpty;
    final int toursCount = bookings
        .where(
          (ToursBooking booking) =>
              booking.serviceType == ToursServiceType.tour &&
              booking.status == ToursBookingStatus.scheduled,
        )
        .length;
    final int travelCount = bookings
        .where(
          (ToursBooking booking) =>
              booking.serviceType == ToursServiceType.travel &&
              booking.status == ToursBookingStatus.scheduled,
        )
        .length;
    final bool hasCancelled = bookings.any(
      (ToursBooking booking) => booking.status == ToursBookingStatus.cancelled,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? CostaNorteBrand.goldDeep
                : hasBookings
                ? CostaNorteBrand.royalBlueDeep
                : CostaNorteBrand.line,
            width: selected ? 1.4 : 1,
          ),
          color: selected
              ? const Color(0xFFFFF8E7)
              : hasBookings
              ? const Color(0xFFF2F7FF)
              : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: CostaNorteBrand.mutedInk,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${date.day}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: hasBookings ? CostaNorteBrand.royalBlueDeep : null,
                      fontWeight: hasBookings ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (hasCancelled)
                  Text(
                    'C',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: CostaNorteBrand.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _AgendaCountLine(
              icon: Icons.explore_rounded,
              count: toursCount,
              active: toursCount > 0,
            ),
            const SizedBox(height: 4),
            _AgendaCountLine(
              icon: Icons.route_rounded,
              count: travelCount,
              active: travelCount > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaCountLine extends StatelessWidget {
  const _AgendaCountLine({
    required this.icon,
    required this.count,
    required this.active,
  });

  final IconData icon;
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? CostaNorteBrand.ink : CostaNorteBrand.mutedInk;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({
    required this.providers,
    required this.initialDate,
    this.booking,
    this.proposedStart,
    this.proposedEnd,
  });
  final List<ToursProvider> providers;
  final DateTime initialDate;
  final ToursBooking? booking;
  final DateTime? proposedStart;
  final DateTime? proposedEnd;
  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _client;
  late final TextEditingController _reference;
  late final TextEditingController _amount;
  late final TextEditingController _commission;
  late final TextEditingController _description;
  late DateTime _startAt;
  late DateTime _endAt;
  late ToursServiceType _serviceType;
  late int _providerId;
  int? _providerOfferingId;
  bool _paid = false;
  ToursPaymentMethod? _paymentMethod;

  ToursProvider get _selectedProvider =>
      widget.providers.firstWhere((ToursProvider p) => p.id == _providerId);

  List<ToursProviderOffering> get _availableOfferings {
    final ToursBooking? booking = widget.booking;
    return _selectedProvider.offerings.where((ToursProviderOffering item) {
      if (item.active) {
        return true;
      }
      return booking != null && booking.providerOfferingId == item.id;
    }).toList()..sort(
      (ToursProviderOffering a, ToursProviderOffering b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  @override
  void initState() {
    super.initState();
    final ToursBooking? booking = widget.booking;
    final ToursProvider provider = widget.providers.firstWhere(
      (ToursProvider p) => p.id == booking?.providerId,
      orElse: () => widget.providers.first,
    );
    _startAt =
        widget.proposedStart ??
        booking?.startAt ??
        DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          9,
          0,
        );
    _endAt =
        widget.proposedEnd ??
        booking?.endAt ??
        _startAt.add(const Duration(hours: 2));
    _serviceType = booking?.serviceType ?? ToursServiceType.tour;
    _providerId = provider.id;
    _providerOfferingId = booking?.providerOfferingId;
    _client = TextEditingController(text: booking?.clientName ?? '');
    _reference = TextEditingController(text: booking?.guestReference ?? '');
    _amount = TextEditingController(
      text: (booking?.amount ?? 0).toStringAsFixed(0),
    );
    _commission = TextEditingController(
      text: (booking?.commissionPercent ?? provider.defaultCommissionPercent)
          .toStringAsFixed(1),
    );
    _description = TextEditingController(text: booking?.description ?? '');
    _paid = booking?.paid ?? false;
    _paymentMethod = booking?.paymentMethod;
  }

  @override
  void dispose() {
    _client.dispose();
    _reference.dispose();
    _amount.dispose();
    _commission.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ToursProviderOffering> offerings = _availableOfferings;
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
      maxHeight: 760,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.booking == null
                  ? 'Novo agendamento'
                  : 'Editar agendamento',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Inicio em ${_fullDate(_dateOnly(_startAt))} as ${_time(_startAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<ToursServiceType>(
                      initialValue: _serviceType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: ToursServiceType.values
                          .map(
                            (ToursServiceType item) =>
                                DropdownMenuItem<ToursServiceType>(
                                  value: item,
                                  child: Text(item.label),
                                ),
                          )
                          .toList(),
                      onChanged: (ToursServiceType? value) {
                        if (value != null) setState(() => _serviceType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _providerId,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      items: widget.providers
                          .map(
                            (ToursProvider item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) {
                        if (value == null) return;
                        final ToursProvider provider = widget.providers
                            .firstWhere(
                              (ToursProvider item) => item.id == value,
                            );
                        setState(() {
                          _providerId = value;
                          _providerOfferingId = null;
                          _commission.text = provider.defaultCommissionPercent
                              .toStringAsFixed(1);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _providerOfferingId,
                      decoration: const InputDecoration(
                        labelText: 'Servico do fornecedor',
                        prefixIcon: Icon(Icons.place_rounded),
                        helperText:
                            'Escolha um servico cadastrado ou siga sem servico predefinido.',
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sem servico predefinido'),
                        ),
                        ...offerings.map(
                          (
                            ToursProviderOffering item,
                          ) => DropdownMenuItem<int?>(
                            value: item.id,
                            child: Text(
                              '${item.name} · ${item.serviceType.label} · ${_money(item.amount)}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (int? value) {
                        setState(() {
                          _providerOfferingId = value;
                        });
                        _applyOffering(value);
                      },
                    ),
                    if (_providerOfferingId != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (BuildContext context) {
                          ToursProviderOffering? selected;
                          for (final ToursProviderOffering item in offerings) {
                            if (item.id == _providerOfferingId) {
                              selected = item;
                              break;
                            }
                          }
                          if (selected == null) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selected.description ??
                                  'Sem detalhes cadastrados.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _client,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o cliente'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(
                        labelText: 'Hospede / unidade',
                        prefixIcon: Icon(Icons.badge_rounded),
                        helperText:
                            'Informe apartamento, quarto, nome do hospede ou outra referencia operacional.',
                      ),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o hospede ou a unidade'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        'Inicio: ${_fullDate(_dateOnly(_startAt))}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _time(_startAt),
                      decoration: const InputDecoration(
                        labelText: 'Horario de inicio',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                      items: _timeOptionsFor(_startAt)
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          _updateStartTime(value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(
                        'Fim: ${_fullDate(_dateOnly(_endAt))}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _time(_endAt),
                      decoration: const InputDecoration(
                        labelText: 'Horario de termino',
                        prefixIcon: Icon(Icons.timelapse_rounded),
                      ),
                      items: _timeOptionsFor(_endAt)
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          _updateEndTime(value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Periodo: ${_dateTime(_startAt)} - ${_dateTime(_endAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Valor',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                            validator: (String? value) =>
                                (_number(value) ?? -1) < 0
                                ? 'Valor invalido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _commission,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Comissao %',
                              prefixIcon: Icon(Icons.percent_rounded),
                            ),
                            validator: (String? value) =>
                                (_number(value) ?? -1) < 0
                                ? 'Percentual invalido'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Descricao',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        const Expanded(child: Text('Registrar como pago')),
                        _InlineStatusSwitch(
                          value: _paid,
                          activeLabel: 'Si',
                          inactiveLabel: 'No',
                          activeColor: CostaNorteBrand.success,
                          inactiveColor: CostaNorteBrand.error,
                          onChanged: _setPaidValue,
                        ),
                      ],
                    ),
                    if (_paid) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ToursPaymentMethod>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                        ),
                        items: ToursPaymentMethod.values
                            .map(
                              (ToursPaymentMethod item) =>
                                  DropdownMenuItem<ToursPaymentMethod>(
                                    value: item,
                                    child: Text(item.label),
                                  ),
                            )
                            .toList(),
                        validator: (ToursPaymentMethod? value) => value == null
                            ? 'Informe a forma de pagamento'
                            : null,
                        onChanged: (ToursPaymentMethod? value) =>
                            setState(() => _paymentMethod = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(_startAt.year - 1, 1, 1),
      lastDate: DateTime(_startAt.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startAt.hour,
        _startAt.minute,
      );
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: DateTime(_startAt.year - 1, 1, 1),
      lastDate: DateTime(_startAt.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(
      () => _endAt = DateTime(
        date.year,
        date.month,
        date.day,
        _endAt.hour,
        _endAt.minute,
      ),
    );
  }

  void _updateStartTime(String value) {
    setState(() {
      _startAt = _dateWithTime(_startAt, value);
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 2));
      }
    });
  }

  void _updateEndTime(String value) {
    setState(() {
      _endAt = _dateWithTime(_endAt, value);
    });
  }

  void _setPaidValue(bool value) {
    setState(() {
      _paid = value;
      if (!_paid) {
        _paymentMethod = null;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_endAt.isAfter(_startAt)) {
      AppAlerts.warning(
        context,
        title: 'Periodo invalido',
        message: 'A data e hora final devem ser posteriores ao inicio.',
      );
      return;
    }
    Navigator.of(context).pop(
      _BookingDraft(
        serviceType: _serviceType,
        startAt: _startAt,
        endAt: _endAt,
        clientName: _client.text.trim(),
        guestReference: _reference.text.trim(),
        providerId: _providerId,
        providerOfferingId: _providerOfferingId,
        amount: _number(_amount.text) ?? 0,
        commissionPercent: _number(_commission.text) ?? 0,
        description: _description.text.trim(),
        paid: _paid,
        paymentMethod: _paymentMethod,
      ),
    );
  }

  void _applyOffering(int? offeringId) {
    if (offeringId == null) {
      return;
    }
    ToursProviderOffering? selected;
    for (final ToursProviderOffering item in _availableOfferings) {
      if (item.id == offeringId) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      return;
    }
    setState(() {
      _serviceType = selected!.serviceType;
      _amount.text = selected.amount.toStringAsFixed(0);
      _description.text = selected.description ?? '';
    });
  }
}

class _InlineStatusSwitch extends StatelessWidget {
  const _InlineStatusSwitch({
    required this.value,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
  });

  final bool value;
  final String activeLabel;
  final String inactiveLabel;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final String label = value ? activeLabel : inactiveLabel;
    final Color backgroundColor = value ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      toggled: value,
      label: 'Registrar como pago',
      value: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 82,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Align(
                alignment: value ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({
    required this.providers,
    required this.toursAppService,
  });
  final List<ToursProvider> providers;
  final ToursAppService toursAppService;
  @override
  State<_ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<_ProviderDialog> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _contact = TextEditingController();
  late final TextEditingController _commission = TextEditingController(
    text: '10',
  );
  late final TextEditingController _offeringName = TextEditingController();
  late final TextEditingController _offeringAmount = TextEditingController();
  late final TextEditingController _offeringDescription =
      TextEditingController();
  int? _selectedId;
  bool _showEditor = false;
  bool _active = true;
  ToursServiceType _offeringServiceType = ToursServiceType.tour;
  bool _offeringActive = true;
  int? _editingOfferingIndex;
  List<_ProviderOfferingDraft> _offerings = <_ProviderOfferingDraft>[];
  String? _historyError;
  String? _historyLoadingKey;

  ToursProvider? get _selectedProvider {
    for (final ToursProvider provider in widget.providers) {
      if (provider.id == _selectedId) {
        return provider;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _commission.dispose();
    _offeringName.dispose();
    _offeringAmount.dispose();
    _offeringDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fornecedores'),
      content: SizedBox(
        width: 560,
        child: _showEditor
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_historyError != null) ...<Widget>[
                      Text(
                        _historyError!,
                        style: const TextStyle(color: CostaNorteBrand.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _selectedId == null
                          ? 'Adicionar fornecedor'
                          : 'Editar fornecedor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedId == null
                          ? 'Cadastre o fornecedor e os serviços oferecidos.'
                          : 'Atualize os dados de ${_selectedProvider!.name}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contact,
                      decoration: const InputDecoration(
                        labelText: 'Contato',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commission,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Comissao padrao %',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      onChanged: _selectedId == null
                          ? null
                          : (bool value) => setState(() => _active = value),
                      title: const Text('Fornecedor ativo'),
                    ),
                    if (_selectedProvider != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed:
                              _historyLoadingKey ==
                                  'provider:${_selectedProvider!.id}'
                              ? null
                              : () => _openProviderHistory(_selectedProvider!),
                          icon: Icon(
                            _historyLoadingKey ==
                                    'provider:${_selectedProvider!.id}'
                                ? Icons.hourglass_top_rounded
                                : Icons.history_rounded,
                          ),
                          label: Text(
                            _historyLoadingKey ==
                                    'provider:${_selectedProvider!.id}'
                                ? 'Carregando...'
                                : 'Historico do fornecedor',
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Destinos e viagens do fornecedor',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (_offerings.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CostaNorteBrand.mist,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Text(
                          'Cadastre pelo menos um destino, passeio ou traslado para este fornecedor.',
                        ),
                      )
                    else
                      ...List<Widget>.generate(_offerings.length, (int index) {
                        final _ProviderOfferingDraft item = _offerings[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CostaNorteBrand.foam,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: CostaNorteBrand.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _editOffering(index),
                                      child: const Text('Editar'),
                                    ),
                                    if (_selectedProvider != null)
                                      TextButton(
                                        onPressed:
                                            _historyLoadingKey ==
                                                'offering:${_selectedProvider!.id}:$index'
                                            ? null
                                            : () => _openOfferingHistory(
                                                _selectedProvider!,
                                                index,
                                              ),
                                        child: Text(
                                          _historyLoadingKey ==
                                                  'offering:${_selectedProvider!.id}:$index'
                                              ? 'Carregando...'
                                              : 'Historico',
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () => _removeOffering(index),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${item.serviceType.label} · ${_money(item.amount)}${item.active ? '' : ' · Inativo'}',
                                ),
                                if (item.description.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(item.description),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ToursServiceType>(
                      initialValue: _offeringServiceType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo do item',
                        prefixIcon: Icon(Icons.map_rounded),
                      ),
                      items: ToursServiceType.values
                          .map(
                            (ToursServiceType item) =>
                                DropdownMenuItem<ToursServiceType>(
                                  value: item,
                                  child: Text(item.label),
                                ),
                          )
                          .toList(),
                      onChanged: (ToursServiceType? value) {
                        if (value != null) {
                          setState(() => _offeringServiceType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _offeringName,
                      decoration: const InputDecoration(
                        labelText: 'Nome do destino ou traslado',
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _offeringAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor base',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _offeringDescription,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detalhes',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _offeringActive,
                      onChanged: (bool value) =>
                          setState(() => _offeringActive = value),
                      title: const Text('Item ativo'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: _upsertOffering,
                        icon: Icon(
                          _editingOfferingIndex == null
                              ? Icons.add_rounded
                              : Icons.check_rounded,
                        ),
                        label: Text(
                          _editingOfferingIndex == null
                              ? 'Adicionar item'
                              : 'Atualizar item',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _buildProviderList(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _showEditor
              ? () => setState(() => _showEditor = false)
              : () => Navigator.of(context).pop(),
          child: Text(_showEditor ? 'Cancelar' : 'Fechar'),
        ),
        if (_showEditor)
          FilledButton(
            onPressed: () {
              final double? commission = _number(_commission.text);
              if (_name.text.trim().isEmpty ||
                  _contact.text.trim().isEmpty ||
                  commission == null ||
                  commission < 0 ||
                  _offerings.isEmpty) {
                AppAlerts.warning(
                  context,
                  title: 'Campos obrigatorios',
                  message:
                      'Informe nome, contato, comissao valida e ao menos um destino ou traslado.',
                );
                return;
              }
              Navigator.of(context).pop(
                _ProviderDraft(
                  id: _selectedId,
                  name: _name.text.trim(),
                  contact: _contact.text.trim(),
                  defaultCommission: commission,
                  active: _selectedId == null ? true : _active,
                  offerings: List<_ProviderOfferingDraft>.from(_offerings),
                ),
              );
            },
            child: const Text('Salvar'),
          ),
      ],
    );
  }

  Widget _buildProviderList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Fornecedores cadastrados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.providers.length} fornecedores',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Adicionar fornecedor',
              onPressed: () => _loadProvider(null),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.providers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum fornecedor cadastrado.'),
          )
        else
          ...widget.providers.map(
            (ToursProvider provider) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment_rounded),
              title: Text(provider.name),
              subtitle: Text(
                '${provider.offerings.length} serviços · ${provider.active ? 'Ativo' : 'Inativo'}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _loadProvider(provider.id),
            ),
          ),
      ],
    );
  }

  void _loadProvider(int? value) {
    setState(() {
      _showEditor = true;
      _selectedId = value;
      final ToursProvider? provider = _selectedProvider;
      if (provider == null) {
        _name.clear();
        _contact.clear();
        _commission.text = '10';
        _active = true;
        _offerings = <_ProviderOfferingDraft>[];
      } else {
        _name.text = provider.name;
        _contact.text = provider.contact;
        _commission.text = provider.defaultCommissionPercent.toStringAsFixed(1);
        _active = provider.active;
        _offerings = provider.offerings
            .map(
              (ToursProviderOffering item) => _ProviderOfferingDraft(
                serviceType: item.serviceType,
                name: item.name,
                amount: item.amount,
                description: item.description ?? '',
                active: item.active,
              ),
            )
            .toList();
      }
      _clearOfferingEditor();
    });
  }

  void _upsertOffering() {
    final double? amount = _number(_offeringAmount.text);
    if (_offeringName.text.trim().isEmpty || amount == null || amount < 0) {
      AppAlerts.warning(
        context,
        title: 'Item invalido',
        message: 'Informe nome e valor valido para o destino ou traslado.',
      );
      return;
    }
    final _ProviderOfferingDraft draft = _ProviderOfferingDraft(
      serviceType: _offeringServiceType,
      name: _offeringName.text.trim(),
      amount: amount,
      description: _offeringDescription.text.trim(),
      active: _offeringActive,
    );
    final Iterable<_ProviderOfferingDraft> duplicates = _offerings
        .asMap()
        .entries
        .where(
          (MapEntry<int, _ProviderOfferingDraft> entry) =>
              entry.key != _editingOfferingIndex &&
              entry.value.name.trim().toLowerCase() ==
                  draft.name.trim().toLowerCase(),
        )
        .map((MapEntry<int, _ProviderOfferingDraft> entry) => entry.value);
    if (duplicates.isNotEmpty) {
      AppAlerts.warning(
        context,
        title: 'Nome duplicado',
        message: 'Cada fornecedor deve ter nomes de destino/servico unicos.',
      );
      return;
    }
    setState(() {
      if (_editingOfferingIndex == null) {
        _offerings = <_ProviderOfferingDraft>[..._offerings, draft];
      } else {
        _offerings[_editingOfferingIndex!] = draft;
      }
      _offerings.sort(
        (_ProviderOfferingDraft a, _ProviderOfferingDraft b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      _clearOfferingEditor();
    });
  }

  void _editOffering(int index) {
    final _ProviderOfferingDraft item = _offerings[index];
    setState(() {
      _editingOfferingIndex = index;
      _offeringServiceType = item.serviceType;
      _offeringName.text = item.name;
      _offeringAmount.text = item.amount.toStringAsFixed(0);
      _offeringDescription.text = item.description;
      _offeringActive = item.active;
    });
  }

  void _removeOffering(int index) {
    setState(() {
      _offerings.removeAt(index);
      if (_editingOfferingIndex == index) {
        _clearOfferingEditor();
      } else if (_editingOfferingIndex != null &&
          _editingOfferingIndex! > index) {
        _editingOfferingIndex = _editingOfferingIndex! - 1;
      }
    });
  }

  void _clearOfferingEditor() {
    _editingOfferingIndex = null;
    _offeringServiceType = ToursServiceType.tour;
    _offeringName.clear();
    _offeringAmount.clear();
    _offeringDescription.clear();
    _offeringActive = true;
  }

  Future<void> _openProviderHistory(ToursProvider provider) async {
    setState(() {
      _historyLoadingKey = 'provider:${provider.id}';
      _historyError = null;
    });
    try {
      final List<AuditEventModel> events = await widget.toursAppService
          .providerHistory(provider.id);
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${provider.name}',
        events: events,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _historyError = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _historyLoadingKey = null);
      }
    }
  }

  Future<void> _openOfferingHistory(ToursProvider provider, int index) async {
    if (index < 0 || index >= provider.offerings.length) {
      return;
    }
    final ToursProviderOffering offering = provider.offerings[index];
    setState(() {
      _historyLoadingKey = 'offering:${provider.id}:$index';
      _historyError = null;
    });
    try {
      final List<AuditEventModel> events = await widget.toursAppService
          .offeringHistory(provider.id, offering.id);
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${offering.name}',
        events: events,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _historyError = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _historyLoadingKey = null);
      }
    }
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog();
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  ToursPaymentMethod _method = ToursPaymentMethod.pix;
  DateTime _date = _today();
  final TextEditingController _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pagamento'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<ToursPaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              items: ToursPaymentMethod.values
                  .map(
                    (ToursPaymentMethod item) =>
                        DropdownMenuItem<ToursPaymentMethod>(
                          value: item,
                          child: Text(item.label),
                        ),
                  )
                  .toList(),
              onChanged: (ToursPaymentMethod? value) {
                if (value != null) setState(() => _method = value);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text('Data: ${_short(_date)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observacoes',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_PaymentDraft(_method, _date, _notes.text.trim())),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1, 1, 1),
      lastDate: DateTime(_date.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _notes = TextEditingController();
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar agendamento'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Motivo do cancelamento',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () {
            final String value = _notes.text.trim();
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
    );
  }
}

class _BookingDraft {
  const _BookingDraft({
    required this.serviceType,
    required this.startAt,
    required this.endAt,
    required this.clientName,
    required this.guestReference,
    required this.providerId,
    required this.providerOfferingId,
    required this.amount,
    required this.commissionPercent,
    required this.description,
    required this.paid,
    required this.paymentMethod,
  });
  final ToursServiceType serviceType;
  final DateTime startAt;
  final DateTime endAt;
  final String clientName;
  final String guestReference;
  final int providerId;
  final int? providerOfferingId;
  final double amount;
  final double commissionPercent;
  final String description;
  final bool paid;
  final ToursPaymentMethod? paymentMethod;
  CreateToursBookingModel toCreateModel() => CreateToursBookingModel(
    serviceType: serviceType,
    startAt: startAt.toIso8601String(),
    endAt: endAt.toIso8601String(),
    clientName: clientName,
    guestReference: guestReference,
    providerId: providerId,
    providerOfferingId: providerOfferingId,
    amount: amount,
    commissionPercent: commissionPercent,
    description: description,
    paid: paid,
    paymentMethod: paymentMethod,
    paymentDate: paid ? _formatDate(_today()) : null,
    paymentNotes: null,
  );
  UpdateToursBookingModel toUpdateModel() => UpdateToursBookingModel(
    serviceType: serviceType,
    startAt: startAt.toIso8601String(),
    endAt: endAt.toIso8601String(),
    clientName: clientName,
    guestReference: guestReference,
    providerId: providerId,
    providerOfferingId: providerOfferingId,
    amount: amount,
    commissionPercent: commissionPercent,
    description: description,
    paid: paid,
    paymentMethod: paymentMethod,
    paymentDate: paid ? _formatDate(_today()) : null,
    paymentNotes: null,
  );
}

class _ProviderDraft {
  const _ProviderDraft({
    required this.id,
    required this.name,
    required this.contact,
    required this.defaultCommission,
    required this.active,
    required this.offerings,
  });
  final int? id;
  final String name;
  final String contact;
  final double defaultCommission;
  final bool active;
  final List<_ProviderOfferingDraft> offerings;
}

class _ProviderOfferingDraft {
  const _ProviderOfferingDraft({
    required this.serviceType,
    required this.name,
    required this.amount,
    required this.description,
    required this.active,
  });

  final ToursServiceType serviceType;
  final String name;
  final double amount;
  final String description;
  final bool active;
}

class _PaymentDraft {
  const _PaymentDraft(this.method, this.date, this.notes);
  final ToursPaymentMethod method;
  final DateTime date;
  final String notes;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _dateWithTime(DateTime date, String time) {
  final List<String> parts = time.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

List<String> _timeOptionsFor(DateTime selected) {
  final Set<String> options = <String>{..._tourTimeSlots, _time(selected)};
  final List<String> sorted = options.toList()
    ..sort((String left, String right) {
      final List<String> leftParts = left.split(':');
      final List<String> rightParts = right.split(':');
      final int leftMinutes =
          (int.parse(leftParts[0]) * 60) + int.parse(leftParts[1]);
      final int rightMinutes =
          (int.parse(rightParts[0]) * 60) + int.parse(rightParts[1]);
      return leftMinutes.compareTo(rightMinutes);
    });
  return sorted;
}

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _short(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _dateTime(DateTime value) => '${_short(value)} ${_time(value)}';
String _fullDate(DateTime date) =>
    '${_week[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]} de ${date.year}';
String _money(double amount) => 'R\$ ${amount.toStringAsFixed(0)}';
String _hours(double value) => '${value.toStringAsFixed(2)}h';
String _describeError(Object error) => switch (error) {
  ApiException(:final message) => message,
  _ => error.toString().replaceFirst('Bad state: ', ''),
};

double? _number(String? rawValue) {
  if (rawValue == null) return null;
  final String normalized = rawValue
      .replaceAll('R\$', '')
      .replaceAll('%', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(normalized);
}

final List<String> _tourTimeSlots = List<String>.unmodifiable(
  List<String>.generate(29, (int index) {
    final int totalMinutes = (9 * 60) + (index * 30);
    final int hour = totalMinutes ~/ 60;
    final int minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }),
);
