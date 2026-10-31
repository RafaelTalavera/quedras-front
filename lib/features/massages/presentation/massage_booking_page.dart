import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audit/audit_models.dart';
import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/files/file_save_result.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/sync/schedule_sync_service.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/whatsapp/manual_whatsapp_dialog.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../../core/widgets/horizontal_scrollable_container.dart';
import '../../../core/widgets/operational_timeline.dart';
import '../application/massage_app_service.dart';
import '../application/massage_provider_report_pdf_exporter.dart';
import '../domain/massage_models.dart';

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

const List<String> _weekDayLabels = <String>[
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sab',
  'Dom',
];

const List<String> _treatmentTypes = <String>[
  'Relaxante',
  'Drenagem corporal',
  'Pedras quentes',
  'Terapeutica',
  'Banho',
  'Experiencia dupla',
];

const List<String> _attendanceTypes = <String>['Hospede', 'Externo', 'VIP'];

enum MassageBookingSection { selectedDay, monthlyAgenda, monthlySummary }

enum _MassageAgendaView { day, week, month }

enum _MassageTimelineFilter { paid, pending, cancelled }

class MassageBookingPageController {
  _MassageBookingPageState? _state;

  Future<void> scrollToSection(MassageBookingSection section) async {
    await _state?._scrollToSection(section);
  }

  void _attach(_MassageBookingPageState state) {
    _state = state;
  }

  void _detach(_MassageBookingPageState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

class MassageBookingPage extends StatefulWidget {
  const MassageBookingPage({
    required this.massageAppService,
    required this.scheduleSyncService,
    this.providerReportPdfExporter,
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final MassageAppService massageAppService;
  final ScheduleSyncService scheduleSyncService;
  final MassageProviderReportPdfExporter? providerReportPdfExporter;
  final MassageBookingPageController? controller;
  final ValueChanged<MassageBookingSection>? onSectionChanged;

  @override
  State<MassageBookingPage> createState() => _MassageBookingPageState();
}

class _MassageBookingPageState extends State<MassageBookingPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _summaryKey = GlobalKey();

  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;
  late final MassageProviderReportPdfExporter _providerReportPdfExporter;
  List<MassageProvider> _providers = <MassageProvider>[];
  List<MassageBooking> _bookings = <MassageBooking>[];
  List<MassageProviderSummary> _providerSummaries = <MassageProviderSummary>[];
  late int _selectedMonth;
  late DateTime _selectedDate;
  late String _selectedTime;
  late DateTime _reportStartDate;
  late DateTime _reportEndDate;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingAgenda = false;
  bool _loadingProviders = false;
  bool _loadingReport = false;
  bool _savingBooking = false;
  bool _savingProviders = false;
  int? _processingBookingId;
  int? _sharingBookingId;
  int? _loadingHistoryBookingId;
  String? _errorMessage;
  String? _agendaErrorMessage;
  String? _reportErrorMessage;
  String? _selectedSummaryDetailKey;
  int? _selectedSummaryProviderId;
  MassageBookingSection _currentSection = MassageBookingSection.selectedDay;
  String? _loadedAgendaKey;
  String? _loadedReportKey;
  _MassageAgendaView _agendaView = _MassageAgendaView.week;
  _MassageTimelineFilter? _timelineFilter;

  String _selectedTreatment = _treatmentTypes.first;
  int? _selectedProviderId;
  int? _selectedTherapistId;
  String _draftAmount = '200';
  bool _paid = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _selectedDate = DateTime.now();
    _selectedMonth = _selectedDate.month - 1;
    _reportStartDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _reportEndDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    _selectedProviderId = null;
    _selectedTherapistId = null;
    _selectedTime = _recommendedTimeFor(_selectedDate, null);
    _providerReportPdfExporter =
        widget.providerReportPdfExporter ??
        DefaultMassageProviderReportPdfExporter();
    _syncSubscription = widget.scheduleSyncService.events.listen(
      _handleSyncEvent,
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant MassageBookingPage oldWidget) {
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

  List<MassageProvider> get _activeProviders =>
      _providers.where((MassageProvider provider) => provider.active).toList()
        ..sort(
          (MassageProvider a, MassageProvider b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

  List<MassageTherapist> _activeTherapistsForProvider(
    int? providerId, {
    int? includeTherapistId,
  }) {
    if (providerId == null) {
      return const <MassageTherapist>[];
    }
    final MassageProvider? provider = _providerById(providerId);
    if (provider == null) {
      return const <MassageTherapist>[];
    }
    final List<MassageTherapist> therapists =
        provider.therapists
            .where(
              (MassageTherapist therapist) =>
                  therapist.active || therapist.id == includeTherapistId,
            )
            .toList()
          ..sort(
            (MassageTherapist a, MassageTherapist b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return therapists;
  }

  List<MassageBooking> get _dayBookings =>
      _bookings.where((MassageBooking booking) {
        return _sameDay(booking.startAt, _selectedDate);
      }).toList()..sort(
        (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
      );

  List<MassageBooking> get _reportBookings =>
      _bookings.where((MassageBooking booking) {
        final DateTime bookingDate = DateTime(
          booking.startAt.year,
          booking.startAt.month,
          booking.startAt.day,
        );
        return !bookingDate.isBefore(_reportStartDate) &&
            !bookingDate.isAfter(_reportEndDate);
      }).toList()..sort(
        (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
      );

  List<MassageBooking> get _scheduledReportBookings =>
      _reportBookings.where((MassageBooking booking) {
        return booking.status == MassageBookingStatus.scheduled;
      }).toList()..sort(
        (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            title: 'Agendamento de massagens',
            icon: Icons.spa_rounded,
            photoAlignment: Alignment.centerLeft,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _savingBooking ? null : _openCreateBookingDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    _savingBooking ? 'Salvando...' : 'Lancar atendimento',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSection(MassageBookingSection.monthlyAgenda),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Agenda'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () =>
                            _showSection(MassageBookingSection.monthlySummary),
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Periodo'),
                ),
                OutlinedButton.icon(
                  onPressed: _savingProviders || _loadingProviders
                      ? null
                      : _openProviderDialog,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: Text(
                    _loadingProviders
                        ? 'Carregando...'
                        : _savingProviders
                        ? 'Salvando...'
                        : 'Prestadores',
                  ),
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
            _buildOperationalAgenda(context),
            const SizedBox(height: 18),
            _buildDetailPanel(context),
          ],
        ],
      ),
    );
  }

  void _setCurrentSection(MassageBookingSection section) {
    if (_currentSection == section) {
      return;
    }
    _currentSection = section;
    widget.onSectionChanged?.call(section);
  }

  Future<void> _scrollToSection(MassageBookingSection section) async {
    await _showSection(section);
  }

  Future<void> _showSection(MassageBookingSection section) async {
    if (section == MassageBookingSection.monthlyAgenda) {
      await _openAgendaDialog();
      return;
    }
    if (section == MassageBookingSection.monthlySummary) {
      await _openSummaryDialog();
      return;
    }
    _setCurrentSection(section);
    if (section == MassageBookingSection.selectedDay) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
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
      final Future<List<MassageBooking>> bookingsFuture = widget
          .massageAppService
          .listBookings(
            dateFrom: _formatDateApi(
              _agendaView == _MassageAgendaView.week
                  ? _weekStart(_selectedDate)
                  : _agendaView == _MassageAgendaView.month
                  ? _monthStart(_selectedDate)
                  : _selectedDate,
            ),
            dateTo: _formatDateApi(
              _agendaView == _MassageAgendaView.week
                  ? _weekStart(_selectedDate).add(const Duration(days: 6))
                  : _agendaView == _MassageAgendaView.month
                  ? _monthEnd(_selectedDate)
                  : _selectedDate,
            ),
          );
      final List<MassageBooking> bookings = await bookingsFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceCachedBookings(
          startDate: _agendaView == _MassageAgendaView.week
              ? _weekStart(_selectedDate)
              : _agendaView == _MassageAgendaView.month
              ? _monthStart(_selectedDate)
              : _selectedDate,
          endDate: _agendaView == _MassageAgendaView.week
              ? _weekStart(_selectedDate).add(const Duration(days: 6))
              : _agendaView == _MassageAgendaView.month
              ? _monthEnd(_selectedDate)
              : _selectedDate,
          bookings: bookings,
        );
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
        _loading = false;
        _refreshingData = false;
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

  bool _canAutoRefresh() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return mounted &&
        !_loading &&
        !_refreshingData &&
        !_loadingAgenda &&
        !_loadingProviders &&
        !_savingBooking &&
        !_savingProviders &&
        !_loadingReport &&
        (route?.isCurrent ?? true);
  }

  Future<void> _refreshActiveData({bool showLoading = false}) async {
    await _load(showLoading: showLoading);
    if (_currentSection == MassageBookingSection.monthlyAgenda) {
      await _loadAgenda(force: true);
    }
    if (_currentSection == MassageBookingSection.monthlySummary) {
      await _reloadProviderReport(force: true);
    }
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain != ScheduleSyncDomain.massages || !_canAutoRefresh()) {
      return;
    }
    if (!_isRelevantSyncEvent(event)) {
      return;
    }
    unawaited(_refreshActiveData(showLoading: false));
  }

  bool _isRelevantSyncEvent(ScheduleSyncEvent event) {
    switch (_currentSection) {
      case MassageBookingSection.selectedDay:
        return event.affectsDay(_selectedDate);
      case MassageBookingSection.monthlyAgenda:
        return event.affectsRange(
          DateTime(_selectedDate.year, _selectedDate.month, 1),
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
        );
      case MassageBookingSection.monthlySummary:
        return event.affectsRange(_reportStartDate, _reportEndDate);
    }
  }

  Future<void> _setSelectedDate(DateTime date, {int? monthOverride}) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final bool dateChanged = !_sameDay(normalizedDate, _selectedDate);
    final bool monthChanged =
        normalizedDate.year != _selectedDate.year ||
        normalizedDate.month != _selectedDate.month;
    setState(() {
      _selectedDate = normalizedDate;
      _selectedMonth = monthOverride ?? (normalizedDate.month - 1);
      _selectedTime = _recommendedTimeFor(normalizedDate, _selectedTherapistId);
    });
    if (dateChanged || monthChanged) {
      await _load(showLoading: false);
      if (_currentSection == MassageBookingSection.monthlyAgenda) {
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

  String _reportKeyFor(DateTime startDate, DateTime endDate) =>
      '${_formatDateApi(startDate)}|${_formatDateApi(endDate)}';

  bool get _hasAgendaForSelectedMonth =>
      _loadedAgendaKey == _monthKeyFor(_selectedDate);

  bool get _hasReportForSelectedRange =>
      _loadedReportKey == _reportKeyFor(_reportStartDate, _reportEndDate);

  Future<void> _loadAgenda({bool force = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingAgenda = true;
      _agendaErrorMessage = null;
    });
    try {
      final List<MassageBooking> bookings = await widget.massageAppService
          .listBookings(
            dateFrom: _formatDateApi(_monthStart(_selectedDate)),
            dateTo: _formatDateApi(_monthEnd(_selectedDate)),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceCachedBookings(
          startDate: _monthStart(_selectedDate),
          endDate: _monthEnd(_selectedDate),
          bookings: bookings,
        );
        _loadedAgendaKey = _monthKeyFor(_selectedDate);
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
        _loadingAgenda = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAgenda = false;
        _agendaErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<bool> _ensureProvidersLoaded({bool force = false}) async {
    if (!mounted) {
      return false;
    }
    setState(() {
      _loadingProviders = true;
      _errorMessage = null;
    });
    try {
      final List<MassageProvider> providers = await widget.massageAppService
          .listProviders();
      if (!mounted) {
        return false;
      }
      setState(() {
        _providers = providers;
        _syncSelectedProviderAndTherapist();
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
        _loadingProviders = false;
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _loadingProviders = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      return false;
    }
  }

  void _replaceCachedBookings({
    required DateTime startDate,
    required DateTime endDate,
    required List<MassageBooking> bookings,
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
    final List<MassageBooking> nextBookings = _bookings.where((
      MassageBooking booking,
    ) {
      final DateTime bookingDate = DateTime(
        booking.startAt.year,
        booking.startAt.month,
        booking.startAt.day,
      );
      return bookingDate.isBefore(normalizedStart) ||
          bookingDate.isAfter(normalizedEnd);
    }).toList()..addAll(bookings);
    nextBookings.sort(
      (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
    );
    _bookings = nextBookings;
  }

  Future<void> _refreshLoadedViewsAfterMutation() async {
    await _load(showLoading: false);
    if (_hasAgendaForSelectedMonth) {
      await _loadAgenda(force: true);
    }
    if (_hasReportForSelectedRange) {
      await _reloadProviderReport(force: true);
    }
  }

  Future<void> _openAgendaDialog() async {
    _setCurrentSection(MassageBookingSection.monthlyAgenda);
    await _loadAgenda();
    if (!mounted) {
      return;
    }
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
                        'Visualizacao mensal de atendimentos com acesso rapido por dia.',
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildAgendaPanel(
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
      _setCurrentSection(MassageBookingSection.selectedDay);
    }
  }

  Future<void> _openSummaryDialog() async {
    _setCurrentSection(MassageBookingSection.monthlySummary);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialogShell(
          maxWidth: 1400,
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
                        'Consolidado de atendimentos, cobranca e prestadores para o intervalo consultado.',
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildSummarySection(
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
      _setCurrentSection(MassageBookingSection.selectedDay);
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

  Widget _buildSummarySection(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
  }) {
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
            'Consolidado de atendimentos e cobranca para o intervalo consultado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _loadingReport
                  ? null
                  : () async {
                      await _pickReportStartDate();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.date_range_rounded),
              label: Text('Inicio: ${_formatShortDateLabel(_reportStartDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loadingReport
                  ? null
                  : () async {
                      await _pickReportEndDate();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.event_rounded),
              label: Text('Fim: ${_formatShortDateLabel(_reportEndDate)}'),
            ),
            FilledButton.icon(
              onPressed: _loadingReport
                  ? null
                  : () async {
                      await _reloadProviderReport(force: true);
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_loadingReport ? 'Buscando...' : 'Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_reportErrorMessage != null) ...<Widget>[
          Text(
            _reportErrorMessage!,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 12),
        ],
        if (_loadingReport && !_hasReportForSelectedRange)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_hasReportForSelectedRange)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CostaNorteBrand.line),
              color: Colors.white,
            ),
            child: const Text(
              'Use Buscar para carregar o resumo do periodo selecionado.',
            ),
          )
        else ...<Widget>[
          _buildSummaryChips(context),
          const SizedBox(height: 20),
          _buildProviderReportSection(context),
        ],
      ],
    );

    if (!asCard) {
      return content;
    }

    return Container(
      key: _summaryKey,
      child: Card(
        child: Padding(padding: const EdgeInsets.all(20), child: content),
      ),
    );
  }

  Widget _buildSummaryChips(BuildContext context) {
    final List<MassageBooking> reportBookings = _reportBookings;
    final List<MassageBooking> scheduledBookings = _scheduledReportBookings;
    final List<MassageBooking> paidBookings = scheduledBookings
        .where((MassageBooking booking) => booking.paid)
        .toList();
    final List<MassageBooking> pendingBookings = scheduledBookings
        .where((MassageBooking booking) => !booking.paid)
        .toList();
    final List<MassageBooking> cancelledBookings = reportBookings.where((
      MassageBooking booking,
    ) {
      return booking.status == MassageBookingStatus.cancelled;
    }).toList();
    // final Set<int> providerIds = scheduledBookings
    //     .map((MassageBooking booking) => booking.providerId)
    //     .toSet();
    // final Set<int> therapistIds = scheduledBookings
    //     .map((MassageBooking booking) => booking.therapistId)
    //     .toSet();
    // final double averageTicket = paidBookings.isEmpty
    //     ? 0
    //     : paidBookings.fold<double>(
    //             0,
    //             (double total, MassageBooking booking) =>
    //                 total + booking.amount,
    //           ) /
    //           paidBookings.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _DetailChip(
          label: 'Pagas',
          value: '${paidBookings.length}',
          icon: Icons.check_circle_outline_rounded,
          selected: _selectedSummaryDetailKey == 'chip:paid',
          onTap: () => _openSummaryDetail(
            key: 'chip:paid',
            title: 'Atendimentos pagos',
            description:
                'Atendimentos agendados com pagamento confirmado no periodo consultado.',
            bookings: paidBookings,
          ),
        ),
        _DetailChip(
          label: 'Pendentes',
          value: '${pendingBookings.length}',
          icon: Icons.warning_amber_rounded,
          selected: _selectedSummaryDetailKey == 'chip:pending',
          onTap: () => _openSummaryDetail(
            key: 'chip:pending',
            title: 'Atendimentos pendentes',
            description:
                'Atendimentos agendados com cobranca em aberto no periodo consultado.',
            bookings: pendingBookings,
          ),
        ),
        _DetailChip(
          label: 'Cancelados',
          value: '${cancelledBookings.length}',
          icon: Icons.cancel_schedule_send_rounded,
          selected: _selectedSummaryDetailKey == 'chip:cancelled',
          onTap: () => _openSummaryDetail(
            key: 'chip:cancelled',
            title: 'Atendimentos cancelados',
            description:
                'Historico de cancelamentos dentro do periodo consultado.',
            bookings: cancelledBookings,
          ),
        ),
        // _DetailChip(
        //   label: 'Prestadores',
        //   value: '${providerIds.length}',
        //   icon: Icons.groups_2_rounded,
        // ),
        // _DetailChip(
        //   label: 'Masajistas',
        //   value: '${therapistIds.length}',
        //   icon: Icons.person_outline_rounded,
        // ),
        // _DetailChip(
        //   label: 'Ticket medio',
        //   value: _formatCurrencyLabel(averageTicket),
        //   icon: Icons.receipt_long_rounded,
        // ),
      ],
    );
  }

  Widget _buildProviderReportSection(BuildContext context) {
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
          Text(
            'Resumo por prestador',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Comparativo de atencoes, cobranca e pendencias por prestador no periodo consultado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          _buildProviderReportTable(context),
        ],
      ),
    );
  }

  Widget _buildProviderReportTable(BuildContext context) {
    if (_loadingReport && _providerSummaries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_providerSummaries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CostaNorteBrand.line),
          color: Colors.white,
        ),
        child: const Text(
          'Nenhum prestador possui atendimentos no periodo informado.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CostaNorteBrand.line),
          ),
          child: HorizontalScrollableContainer(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                headingRowHeight: 56,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 72,
                columns: <DataColumn>[
                  DataColumn(label: _buildReportColumnLabel('Prestador')),
                  DataColumn(label: _buildReportColumnLabel('Atencoes')),
                  DataColumn(label: _buildReportColumnLabel('Canceladas')),
                  DataColumn(label: _buildReportColumnLabel('Pagas')),
                  DataColumn(label: _buildReportColumnLabel('Pendentes')),
                  DataColumn(label: _buildReportColumnLabel('Cobrado')),
                  DataColumn(label: _buildReportColumnLabel('Pendente R\$')),
                  DataColumn(label: _buildReportColumnLabel('Ultimo')),
                  DataColumn(label: _buildReportColumnLabel('Acoes')),
                ],
                rows: _providerSummaries.map((MassageProviderSummary summary) {
                  final bool selected =
                      summary.providerId == _selectedSummaryProviderId;
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (_) =>
                        _selectProviderSummary(summary.providerId),
                    cells: <DataCell>[
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 140),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(summary.providerName),
                              Text(
                                summary.providerActive ? 'Ativo' : 'Inativo',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text('${summary.attendedCount}')),
                      DataCell(Text('${summary.cancelledCount}')),
                      DataCell(Text('${summary.paidCount}')),
                      DataCell(Text('${summary.pendingCount}')),
                      DataCell(Text(_formatCurrencyLabel(summary.paidAmount))),
                      DataCell(
                        Text(_formatCurrencyLabel(summary.pendingAmount)),
                      ),
                      DataCell(
                        Text(
                          summary.lastBookingAt == null
                              ? '-'
                              : _formatShortDateLabel(summary.lastBookingAt!),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: _loadingReport
                              ? null
                              : () =>
                                    _selectProviderSummary(summary.providerId),
                          child: const Text('Ver detalhe'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportColumnLabel(String label) {
    return SizedBox(
      width: 88,
      child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildProviderReportDialogContent(
    BuildContext context,
    MassageProviderDetailReport detail,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CostaNorteBrand.line),
        color: const Color(0xFFFCFCFB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_formatShortDateLabel(_reportStartDate)} a ${_formatShortDateLabel(_reportEndDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildDetailChip(
                'Atencoes',
                '${detail.summary.attendedCount}',
                icon: Icons.spa_outlined,
              ),
              _buildDetailChip(
                'Pagas',
                '${detail.summary.paidCount}',
                icon: Icons.check_circle_outline_rounded,
              ),
              _buildDetailChip(
                'Cobrado',
                _formatCurrencyLabel(detail.summary.paidAmount),
                icon: Icons.payments_rounded,
              ),
              _buildDetailChip(
                'Pendente',
                _formatCurrencyLabel(detail.summary.pendingAmount),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (detail.items.isEmpty)
            const Text('Este prestador nao possui itens no periodo informado.')
          else
            ...detail.items.map(
              (MassageProviderReportItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    border: Border.all(color: CostaNorteBrand.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.clientName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(_statusLabelForReportItem(item)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatShortDateLabel(item.bookingDate)} as ${item.startTime.substring(0, 5)} - ${item.treatment}',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.guestReference} - ${item.therapistName} - ${_formatCurrencyLabel(item.amount)}',
                      ),
                      const SizedBox(height: 2),
                      Text(_statusDescriptionForReportItem(item)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(
    String label,
    String value, {
    required IconData icon,
  }) {
    return _DetailChip(label: label, value: value, icon: icon);
  }

  Widget _buildAgendaPanel(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
    VoidCallback? onDaySelected,
  }) {
    final List<DateTime?> cells = _monthCells(
      _selectedDate.year,
      _selectedMonth + 1,
    );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (asCard) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'Agenda mensal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
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
                    final DateTime nextDate = DateTime(
                      _selectedDate.year,
                      value + 1,
                      1,
                    );
                    unawaited(
                      _setSelectedDate(nextDate, monthOverride: value).then((
                        _,
                      ) {
                        onDialogRefresh?.call();
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
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
                  final DateTime nextDate = DateTime(
                    _selectedDate.year,
                    value + 1,
                    1,
                  );
                  unawaited(
                    _setSelectedDate(nextDate, monthOverride: value).then((_) {
                      onDialogRefresh?.call();
                    }),
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
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_agendaErrorMessage != null) ...<Widget>[
                Text(
                  _agendaErrorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: _weekDayLabels
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: _agendaCellHeight(),
                ),
                itemCount: cells.length,
                itemBuilder: (BuildContext context, int index) {
                  final DateTime? date = cells[index];
                  if (date == null) {
                    return const SizedBox.shrink();
                  }
                  return _AgendaDayCard(
                    date: date,
                    selected: _sameDay(date, _selectedDate),
                    bookings: _bookingsFor(date),
                    onTap: () => unawaited(
                      _setSelectedDate(
                        date,
                        monthOverride: date.month - 1,
                      ).then((_) {
                        if (onDaySelected != null) {
                          onDaySelected();
                        } else {
                          onDialogRefresh?.call();
                        }
                      }),
                    ),
                    onDoubleTap: () => _openCalendarDayActions(date),
                  );
                },
              ),
            ],
          ),
      ],
    );

    if (!asCard) {
      return content;
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
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
                        _selectedDateLabel(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _savingBooking ? null : _pickSelectedDate,
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
                _DetailChip(
                  label: 'Reservas',
                  value: '${_dayBookings.length}',
                  icon: Icons.event_available_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_dayBookings.isEmpty)
              Text(
                'Nao ha atendimentos para este dia.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ..._dayBookings.map(
                (MassageBooking booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onDoubleTap: () => _openBookingActionDialog(booking),
                    child: _BookingTile(
                      booking: booking,
                      provider: _providerName(booking.providerId),
                      therapist: _therapistName(booking),
                      processing: _processingBookingId == booking.id,
                      sharing: _sharingBookingId == booking.id,
                      loadingHistory: _loadingHistoryBookingId == booking.id,
                      onEdit:
                          _processingBookingId == booking.id ||
                              !_isBookingEditable(booking)
                          ? null
                          : () => _openEditBookingDialog(booking),
                      onPayment:
                          _processingBookingId == booking.id ||
                              !_canRegisterPayment(booking)
                          ? null
                          : () => _openPaymentBookingDialog(booking),
                      onShare: _processingBookingId == booking.id
                          ? null
                          : () => _shareBooking(booking),
                      onCancel:
                          _processingBookingId == booking.id ||
                              !_isBookingEditable(booking)
                          ? null
                          : () => _openCancelBookingDialog(booking),
                      onHistory: () => _openBookingHistory(booking),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalAgenda(BuildContext context) {
    final DateTime start = _agendaView == _MassageAgendaView.week
        ? _weekStart(_selectedDate)
        : _selectedDate;
    final List<DateTime> days = List<DateTime>.generate(
      _agendaView == _MassageAgendaView.week ? 7 : 1,
      (int index) => start.add(Duration(days: index)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<_MassageAgendaView>(
              style: operationalTimelineSegmentStyle(),
              segments: const <ButtonSegment<_MassageAgendaView>>[
                ButtonSegment(
                  value: _MassageAgendaView.day,
                  label: Text('Diaria'),
                ),
                ButtonSegment(
                  value: _MassageAgendaView.week,
                  label: Text('Semanal'),
                ),
                ButtonSegment(
                  value: _MassageAgendaView.month,
                  label: Text('Mensal'),
                ),
              ],
              selected: <_MassageAgendaView>{_agendaView},
              onSelectionChanged: (Set<_MassageAgendaView> value) {
                setState(() => _agendaView = value.first);
                unawaited(_load(showLoading: false));
              },
            ),
            const SizedBox(height: 14),
            if (_agendaView == _MassageAgendaView.month)
              _buildAgendaPanel(context, asCard: false)
            else ...<Widget>[
              Row(
                children: <Widget>[
                  IconButton.outlined(
                    onPressed: () => _moveOperationalAgenda(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _setOperationalDate(DateTime.now()),
                    child: const Text('Hoje'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () => _moveOperationalAgenda(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Expanded(
                    child: Text('Horario operacional: 09:00 a 22:00'),
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
                              _timelineFilter == _MassageTimelineFilter.paid,
                          onTap: () => _toggleTimelineFilter(
                            _MassageTimelineFilter.paid,
                          ),
                        ),
                        OperationalTimelineLegend(
                          color: CostaNorteBrand.goldDeep,
                          label: 'Pendente',
                          selected:
                              _timelineFilter == _MassageTimelineFilter.pending,
                          onTap: () => _toggleTimelineFilter(
                            _MassageTimelineFilter.pending,
                          ),
                        ),
                        OperationalTimelineLegend(
                          color: CostaNorteBrand.error,
                          label: 'Cancelado',
                          selected:
                              _timelineFilter ==
                              _MassageTimelineFilter.cancelled,
                          onTap: () => _toggleTimelineFilter(
                            _MassageTimelineFilter.cancelled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OperationalTimeline<MassageBooking>(
                days: days,
                selectedDate: _selectedDate,
                openingHour: 9,
                closingHour: 22,
                events: _bookings.where(_matchesTimelineFilter).map((
                  MassageBooking booking,
                ) {
                  final int startMinutes =
                      booking.startAt.hour * 60 + booking.startAt.minute;
                  return OperationalTimelineEvent<MassageBooking>(
                    value: booking,
                    date: booking.bookingDate,
                    startMinutes: startMinutes,
                    endMinutes: startMinutes + 60,
                    label:
                        '${booking.clientName} ${booking.startTime.substring(0, 5)}',
                    color: booking.status == MassageBookingStatus.cancelled
                        ? CostaNorteBrand.error
                        : booking.paid
                        ? CostaNorteBrand.royalBlueDeep
                        : CostaNorteBrand.goldDeep,
                    draggable: _isBookingEditable(booking),
                  );
                }).toList(),
                onDayTap: _setOperationalDate,
                onEventTap: _openBookingActionDialog,
                onEventMove: _moveMassageFromTimeline,
                onEmptySlotDoubleTap: (DateTime date, int startMinutes) {
                  unawaited(
                    _openCreateBookingDialog(
                      initialDate: date,
                      initialTime:
                          '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}',
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setOperationalDate(DateTime date) async {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _selectedMonth = date.month - 1;
    });
    await _load(showLoading: false);
  }

  void _toggleTimelineFilter(_MassageTimelineFilter filter) {
    setState(() {
      _timelineFilter = _timelineFilter == filter ? null : filter;
    });
  }

  bool _matchesTimelineFilter(MassageBooking booking) {
    switch (_timelineFilter) {
      case _MassageTimelineFilter.paid:
        return booking.status != MassageBookingStatus.cancelled && booking.paid;
      case _MassageTimelineFilter.pending:
        return booking.status != MassageBookingStatus.cancelled &&
            !booking.paid;
      case _MassageTimelineFilter.cancelled:
        return booking.status == MassageBookingStatus.cancelled;
      case null:
        return true;
    }
  }

  Future<void> _moveOperationalAgenda(int direction) async {
    final int days = _agendaView == _MassageAgendaView.week ? 7 : 1;
    await _setOperationalDate(
      _selectedDate.add(Duration(days: days * direction)),
    );
  }

  Future<void> _moveMassageFromTimeline(
    MassageBooking booking,
    DateTime date,
    int startMinutes,
  ) async {
    final int proposedEnd = startMinutes + 60;
    final bool overlap = _bookings.any((MassageBooking item) {
      if (item.id == booking.id ||
          item.status == MassageBookingStatus.cancelled ||
          !_sameDay(item.bookingDate, date)) {
        return false;
      }
      final int itemStart = item.startAt.hour * 60 + item.startAt.minute;
      return startMinutes < itemStart + 60 && proposedEnd > itemStart;
    });
    if (overlap) {
      await AppAlerts.warning(
        context,
        title: 'Horario ocupado',
        message: 'Solte o atendimento em um horario livre para continuar.',
      );
      return;
    }
    await _openEditBookingDialog(
      booking,
      proposedDate: date,
      proposedTime:
          '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}',
    );
  }

  Future<void> _openCreateBookingDialog({
    DateTime? initialDate,
    String? initialTime,
  }) async {
    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }
    final _BookingDraft? bookingDraft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) {
        return _BookingDialog(
          title: 'Lancar atendimento',
          submitLabel: 'Salvar atendimento',
          initialDate: initialDate ?? _selectedDate,
          providers: _providers,
          initialTime: initialTime ?? _selectedTime,
          initialClientName: '',
          initialGuestReference: '',
          initialTreatment: _selectedTreatment,
          initialProviderId: _selectedProviderId,
          initialTherapistId: _selectedTherapistId,
          initialAmount: _draftAmount,
          initialPaid: _paid,
          initialPaymentMethod: _paid ? MassagePaymentMethod.card : null,
          initialPaymentDate: _paid ? (initialDate ?? _selectedDate) : null,
          initialPaymentNotes: '',
        );
      },
    );

    if (bookingDraft == null) {
      return;
    }

    await _createBooking(bookingDraft);
  }

  Future<void> _openEditBookingDialog(
    MassageBooking booking, {
    DateTime? proposedDate,
    String? proposedTime,
  }) async {
    if (booking.status == MassageBookingStatus.cancelled) {
      await AppAlerts.info(
        context,
        title: 'Atendimento cancelado',
        message: 'Atendimentos cancelados nao podem ser editados.',
      );
      return;
    }

    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }

    final _BookingDraft? bookingDraft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) {
        return _BookingDialog(
          title: 'Editar atendimento',
          submitLabel: 'Salvar alteracoes',
          initialDate: proposedDate ?? booking.bookingDate,
          providers: _providers,
          initialTime: proposedTime ?? _timeLabel(booking.startAt),
          initialClientName: booking.clientName,
          initialClientWhatsappNumber: booking.clientWhatsappNumber ?? '',
          initialGuestReference: booking.guestReference,
          initialTreatment: booking.treatment,
          initialProviderId: booking.providerId,
          initialTherapistId: booking.therapistId,
          initialAmount: booking.amount.toStringAsFixed(0),
          initialPaid: booking.paid,
          initialPaymentMethod: booking.paymentMethod,
          initialPaymentDate: booking.paymentDate,
          initialPaymentNotes: booking.paymentNotes ?? '',
        );
      },
    );

    if (bookingDraft == null) {
      return;
    }

    await _updateBooking(booking, bookingDraft);
  }

  Future<void> _openProviderDialog() async {
    final bool providersReady = await _ensureProvidersLoaded();
    if (!providersReady || !mounted) {
      return;
    }

    setState(() {
      _savingProviders = true;
    });
    final List<MassageProvider>? updatedProviders =
        await showDialog<List<MassageProvider>>(
          context: context,
          builder: (BuildContext context) {
            return _ProviderDialog(
              initialProviders: _providers,
              massageAppService: widget.massageAppService,
            );
          },
        );

    if (updatedProviders == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingProviders = false;
      });
      return;
    }

    final bool refreshed = await _ensureProvidersLoaded(force: true);
    if (!mounted) {
      return;
    }
    setState(() => _savingProviders = false);
    if (!refreshed) {
      return;
    }
    if (_hasReportForSelectedRange) {
      await _reloadProviderReport(force: true);
    }
  }

  Future<void> _createBooking(_BookingDraft bookingDraft) async {
    final bool duplicated = _hasBookingConflict(
      bookingDraft: bookingDraft,
      ignoredBookingId: null,
    );
    if (duplicated) {
      await AppAlerts.warning(
        context,
        title: 'Horario ocupado',
        message: 'Esse massagista já está ocupado nesse horário.',
      );
      return;
    }

    setState(() {
      _savingBooking = true;
      _errorMessage = null;
    });

    try {
      final bool monthChanged =
          bookingDraft.date.year != _selectedDate.year ||
          bookingDraft.date.month != _selectedDate.month;
      final MassageBooking created = await widget.massageAppService
          .createBooking(
            CreateMassageBookingModel(
              bookingDate: _formatDateApi(bookingDraft.date),
              startTime: _formatTimeApi(bookingDraft.time),
              clientName: bookingDraft.clientName,
              clientWhatsappNumber: bookingDraft.clientWhatsappNumber,
              guestReference: bookingDraft.guestOrExternal,
              treatment: bookingDraft.treatment,
              amount: bookingDraft.amount,
              providerId: bookingDraft.providerId,
              therapistId: bookingDraft.therapistId,
              paid: bookingDraft.paid,
              paymentMethod: bookingDraft.paymentMethod,
              paymentDate: bookingDraft.paymentDate == null
                  ? null
                  : _formatDateApi(bookingDraft.paymentDate!),
              paymentNotes: bookingDraft.paymentNotes,
            ),
          );

      if (!mounted) {
        return;
      }

      _mergeBooking(created);
      setState(() {
        _selectedDate = DateTime(
          bookingDraft.date.year,
          bookingDraft.date.month,
          bookingDraft.date.day,
        );
        _selectedMonth = bookingDraft.date.month - 1;
        _selectedTreatment = bookingDraft.treatment;
        _selectedProviderId = bookingDraft.providerId;
        _selectedTherapistId = bookingDraft.therapistId;
        _draftAmount = bookingDraft.amount.toStringAsFixed(0);
        _paid = bookingDraft.paid;
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
        _savingBooking = false;
      });

      await AppAlerts.success(
        context,
        title: 'Atendimento salvo',
        message: 'Atendimento salvo para ${bookingDraft.clientName}.',
      );
      if (mounted) {
        await _shareBooking(created);
      }
      if (monthChanged) {
        _loadedAgendaKey = null;
      }
      await _refreshLoadedViewsAfterMutation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingBooking = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao salvar atendimento',
        message: _errorMessage!,
      );
    }
  }

  Future<void> _updateBooking(
    MassageBooking original,
    _BookingDraft bookingDraft,
  ) async {
    final bool duplicated = _hasBookingConflict(
      bookingDraft: bookingDraft,
      ignoredBookingId: original.id,
    );
    if (duplicated) {
      await AppAlerts.warning(
        context,
        title: 'Horario ocupado',
        message: 'Esse massagista já está ocupado nesse horário.',
      );
      return;
    }

    setState(() {
      _savingBooking = true;
      _processingBookingId = original.id;
      _errorMessage = null;
    });

    try {
      final bool monthChanged =
          bookingDraft.date.year != _selectedDate.year ||
          bookingDraft.date.month != _selectedDate.month;
      final MassageBooking updated = await widget.massageAppService
          .updateBooking(
            original.id,
            UpdateMassageBookingModel(
              bookingDate: _formatDateApi(bookingDraft.date),
              startTime: _formatTimeApi(bookingDraft.time),
              clientName: bookingDraft.clientName,
              clientWhatsappNumber: bookingDraft.clientWhatsappNumber,
              guestReference: bookingDraft.guestOrExternal,
              treatment: bookingDraft.treatment,
              amount: bookingDraft.amount,
              providerId: bookingDraft.providerId,
              therapistId: bookingDraft.therapistId,
              paid: bookingDraft.paid,
              paymentMethod: bookingDraft.paymentMethod,
              paymentDate: bookingDraft.paymentDate == null
                  ? null
                  : _formatDateApi(bookingDraft.paymentDate!),
              paymentNotes: bookingDraft.paymentNotes,
            ),
          );

      if (!mounted) {
        return;
      }

      _mergeBooking(updated);
      setState(() {
        _selectedDate = DateTime(
          bookingDraft.date.year,
          bookingDraft.date.month,
          bookingDraft.date.day,
        );
        _selectedMonth = bookingDraft.date.month - 1;
        _selectedTreatment = bookingDraft.treatment;
        _selectedProviderId = bookingDraft.providerId;
        _selectedTherapistId = bookingDraft.therapistId;
        _draftAmount = bookingDraft.amount.toStringAsFixed(0);
        _paid = bookingDraft.paid;
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
        _savingBooking = false;
        _processingBookingId = null;
      });

      await AppAlerts.success(
        context,
        title: 'Atendimento atualizado',
        message: 'Atendimento atualizado para ${bookingDraft.clientName}.',
      );
      if (mounted) {
        await _shareBooking(updated);
      }
      if (monthChanged) {
        _loadedAgendaKey = null;
      }
      await _refreshLoadedViewsAfterMutation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingBooking = false;
        _processingBookingId = null;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao atualizar atendimento',
        message: _errorMessage!,
      );
    }
  }

  Future<void> _openBookingActionDialog(MassageBooking booking) async {
    final _BookingAction? action = await showDialog<_BookingAction>(
      context: context,
      builder: (BuildContext context) {
        return _BookingActionDialog(
          booking: booking,
          sharing: _sharingBookingId == booking.id,
        );
      },
    );

    switch (action) {
      case _BookingAction.edit:
        await _openEditBookingDialog(booking);
        return;
      case _BookingAction.payment:
        await _openPaymentBookingDialog(booking);
        return;
      case _BookingAction.share:
        await _shareBooking(booking);
        return;
      case _BookingAction.cancel:
        await _openCancelBookingDialog(booking);
        return;
      case _BookingAction.history:
        await _openBookingHistory(booking);
        return;
      case null:
        return;
    }
  }

  Future<void> _openBookingHistory(MassageBooking booking) async {
    setState(() {
      _loadingHistoryBookingId = booking.id;
      _errorMessage = null;
    });

    try {
      final List<AuditEventModel> history = await widget.massageAppService
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
        title: 'Historico do atendimento',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistoryBookingId = null;
        });
      }
    }
  }

  Future<void> _openCalendarDayActions(DateTime date) async {
    final List<MassageBooking> bookings = _bookingsFor(date);
    if (bookings.isEmpty) {
      await _openCreateBookingDialog(initialDate: date);
      return;
    }

    final MassageBooking? selected = await showDialog<MassageBooking>(
      context: context,
      builder: (BuildContext context) {
        return _BookingSelectionDialog(
          title: 'Atendimentos do dia',
          description:
              'Escolha um atendimento para editar, informar pagamento, compartilhar ou cancelar o atendimento.',
          bookings: bookings,
          emptyMessage: 'Nao ha atendimentos para o dia selecionado.',
          onSelectLabel: 'Abrir acoes',
        );
      },
    );

    if (selected == null) {
      return;
    }

    await _openBookingActionDialog(selected);
  }

  Future<void> _shareBooking(MassageBooking booking) async {
    if (_sharingBookingId != null) {
      return;
    }

    setState(() {
      _sharingBookingId = booking.id;
    });
    try {
      final MassageProvider? provider = _providerById(booking.providerId);
      final MassageTherapist? therapist = provider?.therapists
          .where((MassageTherapist item) => item.id == booking.therapistId)
          .cast<MassageTherapist?>()
          .firstOrNull;
      final bool? sendToClient = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Preparar aviso por WhatsApp'),
          content: const Text('Escolha o destinatario do atendimento.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Agora nao'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cliente'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Massagista'),
            ),
          ],
        ),
      );
      if (sendToClient == null || !mounted) return;
      await showManualWhatsappDialog(
        context,
        providerName: sendToClient
            ? booking.clientName
            : (therapist?.name ?? booking.therapistName),
        phoneNumber: sendToClient
            ? booking.clientWhatsappNumber
            : therapist?.whatsappEnabled == true
            ? therapist?.whatsappNumber
            : null,
        message: _buildBookingShareMessage(booking),
      );
    } catch (error) {
      if (mounted) {
        await AppAlerts.warning(
          context,
          title: 'Aviso não preparado',
          message:
              'O atendimento foi salvo, mas o aviso não pôde ser preparado: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharingBookingId = null;
        });
      }
    }
  }

  Future<void> _openCancelBookingDialog(MassageBooking booking) async {
    if (booking.status == MassageBookingStatus.cancelled) {
      await AppAlerts.info(
        context,
        title: 'Atendimento cancelado',
        message: 'Esse atendimento ja esta cancelado.',
      );
      return;
    }

    final String? cancellationNotes = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _CancelBookingDialog(booking: booking);
      },
    );
    if (cancellationNotes == null) {
      return;
    }

    setState(() {
      _savingBooking = true;
      _processingBookingId = booking.id;
      _errorMessage = null;
    });

    try {
      final MassageBooking cancelled = await widget.massageAppService
          .cancelBooking(
            booking.id,
            CancelMassageBookingModel(cancellationNotes: cancellationNotes),
          );
      if (!mounted) {
        return;
      }
      _mergeBooking(cancelled);
      setState(() {
        _savingBooking = false;
        _processingBookingId = null;
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
      });
      await AppAlerts.success(
        context,
        title: 'Atendimento cancelado',
        message: 'O cancelamento foi registrado sem remover o historico.',
      );
      await _refreshLoadedViewsAfterMutation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingBooking = false;
        _processingBookingId = null;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao cancelar atendimento',
        message: _errorMessage!,
      );
    }
  }

  Future<void> _openPaymentBookingDialog(MassageBooking booking) async {
    if (booking.status == MassageBookingStatus.cancelled) {
      await AppAlerts.info(
        context,
        title: 'Atendimento cancelado',
        message: 'Atendimentos cancelados nao podem receber pagamento.',
      );
      return;
    }
    if (booking.paid) {
      await AppAlerts.info(
        context,
        title: 'Pagamento ja informado',
        message: 'Esse atendimento ja esta marcado como pago.',
      );
      return;
    }

    final _PaymentDraft? paymentDraft = await showDialog<_PaymentDraft>(
      context: context,
      builder: (BuildContext context) {
        return _PaymentBookingDialog(booking: booking);
      },
    );
    if (paymentDraft == null) {
      return;
    }

    setState(() {
      _savingBooking = true;
      _processingBookingId = booking.id;
      _errorMessage = null;
    });

    try {
      final MassageBooking updated = await widget.massageAppService
          .updatePayment(
            booking.id,
            UpdateMassagePaymentModel(
              paymentMethod: paymentDraft.paymentMethod,
              paymentDate: _formatDateApi(paymentDraft.paymentDate),
              paymentNotes: paymentDraft.paymentNotes,
            ),
          );
      if (!mounted) {
        return;
      }
      _mergeBooking(updated);
      setState(() {
        _savingBooking = false;
        _processingBookingId = null;
        _selectedTime = _recommendedTimeFor(
          _selectedDate,
          _selectedTherapistId,
        );
      });
      await AppAlerts.success(
        context,
        title: 'Pagamento informado',
        message: 'O pagamento de ${booking.clientName} foi registrado.',
      );
      await _refreshLoadedViewsAfterMutation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingBooking = false;
        _processingBookingId = null;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao informar pagamento',
        message: _errorMessage!,
      );
    }
  }

  bool _hasBookingConflict({
    required _BookingDraft bookingDraft,
    required int? ignoredBookingId,
  }) {
    final DateTime startAt = _bookingStartAt(
      bookingDraft.date,
      bookingDraft.time,
    );
    return _bookingsFor(bookingDraft.date).any(
      (MassageBooking booking) =>
          booking.status == MassageBookingStatus.scheduled &&
          booking.id != ignoredBookingId &&
          booking.therapistId == bookingDraft.therapistId &&
          booking.startAt.hour == startAt.hour &&
          booking.startAt.minute == startAt.minute,
    );
  }

  void _mergeBooking(MassageBooking booking) {
    final List<MassageBooking> nextBookings = <MassageBooking>[..._bookings];
    final int index = nextBookings.indexWhere(
      (MassageBooking item) => item.id == booking.id,
    );
    if (index >= 0) {
      nextBookings[index] = booking;
    } else {
      nextBookings.insert(0, booking);
    }
    nextBookings.sort(
      (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
    );
    _bookings = nextBookings;
  }

  Future<void> _reloadProviderReport({bool force = false}) async {
    setState(() {
      _loadingReport = true;
      _reportErrorMessage = null;
      _selectedSummaryDetailKey = null;
    });

    try {
      final Future<List<MassageBooking>> bookingsFuture = widget
          .massageAppService
          .listBookings(
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      final Future<List<MassageProviderSummary>> summariesFuture = widget
          .massageAppService
          .listProviderSummaryReport(
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      final List<MassageBooking> bookings = await bookingsFuture;
      final List<MassageProviderSummary> summaries = await summariesFuture;

      int? selectedProviderId = _selectedSummaryProviderId;
      if (selectedProviderId != null &&
          summaries.any(
            (MassageProviderSummary item) =>
                item.providerId == selectedProviderId,
          )) {
        selectedProviderId = selectedProviderId;
      } else {
        selectedProviderId = null;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _replaceCachedBookings(
          startDate: _reportStartDate,
          endDate: _reportEndDate,
          bookings: bookings,
        );
        _providerSummaries = summaries;
        _loadedReportKey = _reportKeyFor(_reportStartDate, _reportEndDate);
        _selectedSummaryProviderId = selectedProviderId;
        _loadingReport = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReport = false;
        _reportErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _selectProviderSummary(int providerId) async {
    setState(() {
      _selectedSummaryProviderId = providerId;
      _loadingReport = true;
      _reportErrorMessage = null;
    });

    try {
      final MassageProviderDetailReport detail = await widget.massageAppService
          .getProviderDetailReport(
            providerId,
            dateFrom: _formatDateApi(_reportStartDate),
            dateTo: _formatDateApi(_reportEndDate),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReport = false;
      });
      await _openProviderReportDetailDialog(detail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReport = false;
        _reportErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _openProviderReportDetailDialog(
    MassageProviderDetailReport detail,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool exporting = false;
        String? exportingAction;

        Future<void> runExport(
          String action,
          Future<void> Function() operation,
          StateSetter setDialogState,
        ) async {
          setDialogState(() {
            exporting = true;
            exportingAction = action;
          });
          try {
            await operation();
          } finally {
            if (context.mounted) {
              setDialogState(() {
                exporting = false;
                exportingAction = null;
              });
            }
          }
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Detalhe de ${detail.providerName}'),
              content: SizedBox(
                width: 860,
                child: SingleChildScrollView(
                  child: _buildProviderReportDialogContent(context, detail),
                ),
              ),
              actions: <Widget>[
                OutlinedButton.icon(
                  onPressed: exporting
                      ? null
                      : () => runExport(
                          'download',
                          () => _downloadProviderReportPdf(detail),
                          setDialogState,
                        ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    exportingAction == 'download'
                        ? 'Gerando PDF...'
                        : 'Baixar PDF',
                  ),
                ),
                TextButton(
                  onPressed: exporting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadProviderReportPdf(
    MassageProviderDetailReport detail,
  ) async {
    try {
      final FileSaveResult? result = await _providerReportPdfExporter.savePdf(
        detail: detail,
        startDate: _reportStartDate,
        endDate: _reportEndDate,
      );
      if (result == null || !mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'PDF salvo',
        message: result.hasLocalPath
            ? 'Resumo salvo em:\n${result.path}'
            : 'Download do PDF iniciado no navegador:\n${result.fileName}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao gerar PDF',
        message: 'Nao foi possivel salvar o resumo do prestador: $error',
      );
    }
  }

  Future<void> _pickSelectedDate() async {
    final DateTime initialDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1, 1, 1),
      lastDate: DateTime(initialDate.year + 1, 12, 31),
    );
    if (picked == null) {
      return;
    }
    await _setSelectedDate(picked);
  }

  Future<void> _pickReportStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportStartDate,
      firstDate: DateTime(_selectedDate.year - 2),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _reportStartDate = DateTime(picked.year, picked.month, picked.day);
      if (_reportStartDate.isAfter(_reportEndDate)) {
        _reportEndDate = _reportStartDate;
      }
      _loadedReportKey = null;
      _providerSummaries = <MassageProviderSummary>[];
      _reportErrorMessage = null;
      _selectedSummaryProviderId = null;
      _selectedSummaryDetailKey = null;
    });
  }

  Future<void> _pickReportEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportEndDate,
      firstDate: DateTime(_selectedDate.year - 2),
      lastDate: DateTime(_selectedDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _reportEndDate = DateTime(picked.year, picked.month, picked.day);
      if (_reportEndDate.isBefore(_reportStartDate)) {
        _reportStartDate = _reportEndDate;
      }
      _loadedReportKey = null;
      _providerSummaries = <MassageProviderSummary>[];
      _reportErrorMessage = null;
      _selectedSummaryProviderId = null;
      _selectedSummaryDetailKey = null;
    });
  }

  Future<void> _openSummaryDetail({
    required String key,
    required String title,
    required String description,
    required List<MassageBooking> bookings,
  }) async {
    final List<MassageBooking> normalized = <MassageBooking>[...bookings]
      ..sort((MassageBooking a, MassageBooking b) {
        return a.startAt.compareTo(b.startAt);
      });
    final List<MassageBooking> scheduledBookings = normalized.where((
      MassageBooking booking,
    ) {
      return booking.status == MassageBookingStatus.scheduled;
    }).toList();
    final double totalAmount = scheduledBookings.fold<double>(
      0,
      (double total, MassageBooking booking) => total + booking.amount,
    );
    final int pendingCount = scheduledBookings.where((MassageBooking booking) {
      return !booking.paid;
    }).length;

    setState(() {
      _selectedSummaryDetailKey = key;
    });
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _DetailChip(
                        label: 'Atendimentos',
                        value: '${normalized.length}',
                        icon: Icons.spa_outlined,
                      ),
                      _DetailChip(
                        label: 'Pendentes',
                        value: '$pendingCount',
                        icon: Icons.warning_amber_rounded,
                      ),
                      _DetailChip(
                        label: 'Valor',
                        value: _formatCurrencyLabel(totalAmount),
                        icon: Icons.payments_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (normalized.isEmpty)
                    const Text(
                      'Nenhum atendimento encontrado para este detalhe.',
                    )
                  else
                    ...normalized.map(
                      (MassageBooking booking) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BookingTile(
                          booking: booking,
                          provider: booking.providerName,
                          therapist: booking.therapistName,
                          processing: false,
                          sharing: false,
                          loadingHistory:
                              _loadingHistoryBookingId == booking.id,
                          onHistory: () => _openBookingHistory(booking),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSummaryDetailKey = null;
    });
  }

  DateTime _bookingStartAt(DateTime bookingDate, String time) {
    final List<String> parts = time.split(':');
    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  List<DateTime?> _monthCells(int year, int month) {
    final DateTime firstDay = DateTime(year, month, 1);
    final DateTime lastDay = DateTime(year, month + 1, 0);
    final int leading = firstDay.weekday - 1;
    final int total = (((leading + lastDay.day) / 7).ceil()) * 7;

    return List<DateTime?>.generate(total, (int index) {
      final int day = index - leading + 1;
      if (day < 1 || day > lastDay.day) {
        return null;
      }
      return DateTime(year, month, day);
    });
  }

  List<MassageBooking> _bookingsFor(DateTime date) {
    return _bookings.where((MassageBooking booking) {
      return _sameDay(booking.startAt, date);
    }).toList()..sort(
      (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
    );
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _recommendedTimeFor(DateTime date, int? therapistId) {
    if (therapistId == null) {
      return _timeSlots.first;
    }
    final Set<String> occupiedSlots = _bookingsFor(date)
        .where(
          (MassageBooking booking) =>
              booking.status == MassageBookingStatus.scheduled &&
              booking.therapistId == therapistId,
        )
        .map((MassageBooking booking) => _timeLabel(booking.startAt))
        .toSet();

    for (final String slot in _timeSlots) {
      if (!occupiedSlots.contains(slot)) {
        return slot;
      }
    }

    return _timeSlots.first;
  }

  double _agendaCellHeight() {
    return 69;
  }

  String _selectedDateLabel(DateTime date) {
    return _fullDateLabel(date);
  }

  String _providerName(int providerId) {
    for (final MassageProvider provider in _providers) {
      if (provider.id == providerId) {
        return provider.name;
      }
    }
    return 'Prestador';
  }

  String _therapistName(MassageBooking booking) {
    if (booking.therapistName.trim().isNotEmpty) {
      return booking.therapistName;
    }
    final MassageProvider? provider = _providerById(booking.providerId);
    if (provider == null) {
      return 'Massagista';
    }
    for (final MassageTherapist therapist in provider.therapists) {
      if (therapist.id == booking.therapistId) {
        return therapist.name;
      }
    }
    return 'Massagista';
  }

  MassageProvider? _providerById(int providerId) {
    for (final MassageProvider provider in _providers) {
      if (provider.id == providerId) {
        return provider;
      }
    }
    return null;
  }

  void _syncSelectedProviderAndTherapist() {
    final List<MassageProvider> activeProviders = _activeProviders;
    if (activeProviders.isEmpty) {
      _selectedProviderId = null;
      _selectedTherapistId = null;
      return;
    }
    final List<MassageProvider> providersWithActiveTherapists = activeProviders
        .where(
          (MassageProvider provider) => provider.therapists.any(
            (MassageTherapist therapist) => therapist.active,
          ),
        )
        .toList();
    final List<MassageProvider> preferredProviders =
        providersWithActiveTherapists.isEmpty
        ? activeProviders
        : providersWithActiveTherapists;
    final bool providerStillAvailable = preferredProviders.any(
      (MassageProvider provider) => provider.id == _selectedProviderId,
    );
    _selectedProviderId = providerStillAvailable
        ? _selectedProviderId
        : preferredProviders.first.id;
    final List<MassageTherapist> therapists = _activeTherapistsForProvider(
      _selectedProviderId,
    );
    if (therapists.isEmpty) {
      _selectedTherapistId = null;
      return;
    }
    final bool therapistStillAvailable = therapists.any(
      (MassageTherapist therapist) => therapist.id == _selectedTherapistId,
    );
    _selectedTherapistId = therapistStillAvailable
        ? _selectedTherapistId
        : therapists.first.id;
  }

  bool _canRegisterPayment(MassageBooking booking) {
    return booking.status == MassageBookingStatus.scheduled && !booking.paid;
  }

  bool _isBookingEditable(MassageBooking booking) {
    return booking.status == MassageBookingStatus.scheduled;
  }

  String _buildBookingShareMessage(MassageBooking booking) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Atendimento de massagem Hotel Costa Norte')
      ..writeln('Cliente: ${booking.clientName}')
      ..writeln('Data: ${_formatShortDateLabel(booking.bookingDate)}')
      ..writeln('Horario: ${_timeLabel(booking.startAt)}')
      ..writeln('Tratamento: ${booking.treatment}')
      ..writeln('Hospede ou externo: ${booking.guestReference}')
      ..writeln('Prestador: ${booking.providerName}')
      ..writeln('Massagista: ${booking.therapistName}')
      ..writeln('Valor: ${_formatCurrencyLabel(booking.amount)}')
      ..writeln('Estado: ${_statusDescription(booking)}');
    if ((booking.paymentNotes ?? '').trim().isNotEmpty) {
      buffer.writeln(
        'Observacoes do pagamento: ${booking.paymentNotes!.trim()}',
      );
    }
    return buffer.toString().trim();
  }
}

class _AgendaDayCard extends StatelessWidget {
  const _AgendaDayCard({
    required this.date,
    required this.selected,
    required this.bookings,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime date;
  final bool selected;
  final List<MassageBooking> bookings;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final bool hasBookings = bookings.isNotEmpty;

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
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(
                  Icons.spa_outlined,
                  size: 14,
                  color: hasBookings
                      ? CostaNorteBrand.ink
                      : CostaNorteBrand.mutedInk,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${bookings.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: hasBookings
                          ? CostaNorteBrand.ink
                          : CostaNorteBrand.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.value,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? CostaNorteBrand.foam : Colors.white,
            border: Border.all(
              color: selected
                  ? CostaNorteBrand.royalBlueDeep
                  : CostaNorteBrand.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? CostaNorteBrand.royalBlueDeep
                    : CostaNorteBrand.mutedInk,
              ),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CostaNorteBrand.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.booking,
    required this.provider,
    required this.therapist,
    required this.processing,
    required this.sharing,
    this.loadingHistory = false,
    this.onEdit,
    this.onPayment,
    this.onShare,
    this.onCancel,
    this.onHistory,
  });

  final MassageBooking booking;
  final String provider;
  final String therapist;
  final bool processing;
  final bool sharing;
  final bool loadingHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onPayment;
  final VoidCallback? onShare;
  final VoidCallback? onCancel;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _providerColor(booking.providerId),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _timeLabel(booking.startAt),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (processing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text(
                _statusLabel(booking),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: _statusColor(booking)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.clientName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.guestReference} - ${booking.treatment} - $provider / $therapist - '
            'R\$ ${booking.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _statusDescription(booking),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _statusColor(booking)),
          ),
          if (booking.cancellationNotes != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Cancelamento: ${booking.cancellationNotes}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CostaNorteBrand.error),
            ),
          ],
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
                      sharing ? 'Preparando...' : 'Avisar no WhatsApp',
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
                    label: Text(loadingHistory ? 'Carregando...' : 'Historico'),
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
    );
  }
}

class _BookingDraft {
  const _BookingDraft({
    required this.date,
    required this.time,
    required this.clientName,
    required this.clientWhatsappNumber,
    required this.guestOrExternal,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.therapistId,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final DateTime date;
  final String time;
  final String clientName;
  final String? clientWhatsappNumber;
  final String guestOrExternal;
  final String treatment;
  final double amount;
  final int providerId;
  final int therapistId;
  final bool paid;
  final MassagePaymentMethod? paymentMethod;
  final DateTime? paymentDate;
  final String? paymentNotes;
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({
    required this.title,
    required this.submitLabel,
    required this.initialDate,
    required this.providers,
    required this.initialTime,
    required this.initialClientName,
    this.initialClientWhatsappNumber = '',
    required this.initialGuestReference,
    required this.initialTreatment,
    required this.initialProviderId,
    required this.initialTherapistId,
    required this.initialAmount,
    required this.initialPaid,
    required this.initialPaymentMethod,
    required this.initialPaymentDate,
    required this.initialPaymentNotes,
  });

  final String title;
  final String submitLabel;
  final DateTime initialDate;
  final List<MassageProvider> providers;
  final String initialTime;
  final String initialClientName;
  final String initialClientWhatsappNumber;
  final String initialGuestReference;
  final String initialTreatment;
  final int? initialProviderId;
  final int? initialTherapistId;
  final String initialAmount;
  final bool initialPaid;
  final MassagePaymentMethod? initialPaymentMethod;
  final DateTime? initialPaymentDate;
  final String initialPaymentNotes;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _clientController;
  late final TextEditingController _clientWhatsappController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentNotesController;

  late DateTime _selectedDate;
  late String _selectedTime;
  late String _selectedTreatment;
  String? _selectedAttendanceType;
  int? _selectedProviderId;
  int? _selectedTherapistId;
  late bool _paid;
  MassagePaymentMethod? _paymentMethod;
  DateTime? _paymentDate;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(text: widget.initialClientName);
    _clientWhatsappController = TextEditingController(
      text: widget.initialClientWhatsappNumber,
    );
    _amountController = TextEditingController(text: widget.initialAmount);
    _paymentNotesController = TextEditingController(
      text: widget.initialPaymentNotes,
    );
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _selectedTime = widget.initialTime;
    _selectedTreatment = widget.initialTreatment;
    _selectedAttendanceType = widget.initialGuestReference.trim().isEmpty
        ? null
        : widget.initialGuestReference.trim();
    _selectedProviderId = _initialProviderId();
    _selectedTherapistId = _initialTherapistId();
    _paid = widget.initialPaid;
    _paymentMethod = _paid ? widget.initialPaymentMethod : null;
    _paymentDate = _paid ? (widget.initialPaymentDate ?? _selectedDate) : null;
  }

  @override
  void dispose() {
    _clientController.dispose();
    _clientWhatsappController.dispose();
    _amountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MassageProvider> selectableProviders = _selectableProviders;
    final List<MassageTherapist> selectableTherapists = _selectableTherapists;
    final List<String> attendanceTypeOptions = _attendanceTypeOptions;
    final List<String> treatmentOptions = _treatmentOptions;
    final List<String> timeOptions = _timeOptions;
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
      maxHeight: 760,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _fullDateLabel(_selectedDate),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _pickBookingDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        'Data: ${_fullDateLabel(_selectedDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientWhatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp do cliente',
                        helperText: 'Opcional. Use codigo do pais e DDD.',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTime,
                      decoration: const InputDecoration(
                        labelText: 'Horario',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                      items: timeOptions
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedTime = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientController,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o cliente.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedAttendanceType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de atendimento',
                        prefixIcon: Icon(Icons.hotel_rounded),
                      ),
                      items: attendanceTypeOptions
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Selecione o tipo de atendimento.'
                          : null,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedAttendanceType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedTreatment,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de massagem',
                        prefixIcon: Icon(Icons.spa_outlined),
                      ),
                      items: treatmentOptions
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedTreatment = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: _selectedProviderId,
                      decoration: const InputDecoration(
                        labelText: 'Prestador',
                        prefixIcon: Icon(Icons.groups_2_outlined),
                      ),
                      items: selectableProviders
                          .map(
                            (MassageProvider provider) => DropdownMenuItem<int>(
                              value: provider.id,
                              child: Text(
                                '${provider.name} - ${provider.specialty}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (int? value) => value == null
                          ? 'Cadastre ou selecione um prestador.'
                          : null,
                      onChanged: (int? value) {
                        setState(() {
                          _selectedProviderId = value;
                          final List<MassageTherapist> therapists =
                              _therapistsForSelectedProvider(
                                includeTherapistId: widget.initialTherapistId,
                              );
                          _selectedTherapistId = therapists.isEmpty
                              ? null
                              : therapists.first.id;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: _selectedTherapistId,
                      decoration: const InputDecoration(
                        labelText: 'Massagista',
                        prefixIcon: Icon(Icons.person_pin_circle_outlined),
                      ),
                      items: selectableTherapists
                          .map(
                            (MassageTherapist therapist) =>
                                DropdownMenuItem<int>(
                                  value: therapist.id,
                                  child: Text(
                                    therapist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          )
                          .toList(),
                      validator: (int? value) =>
                          value == null ? 'Selecione um massagista.' : null,
                      onChanged: (int? value) {
                        setState(() {
                          _selectedTherapistId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (String? value) {
                        final double? amount = _parseMassageAmount(value);
                        return amount == null || amount <= 0
                            ? 'Informe um valor valido.'
                            : null;
                      },
                    ),
                    Row(
                      children: <Widget>[
                        const Expanded(child: Text('Pagamento recebido')),
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
                      DropdownButtonFormField<MassagePaymentMethod>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Meio de pagamento',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                        ),
                        items: MassagePaymentMethod.values
                            .map(
                              (MassagePaymentMethod value) =>
                                  DropdownMenuItem<MassagePaymentMethod>(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                            )
                            .toList(),
                        validator: (MassagePaymentMethod? value) {
                          if (_paid && value == null) {
                            return 'Informe o meio de pagamento.';
                          }
                          return null;
                        },
                        onChanged: (MassagePaymentMethod? value) {
                          setState(() {
                            _paymentMethod = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickPaymentDate,
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text(
                          _paymentDate == null
                              ? 'Selecionar data do pagamento'
                              : 'Pagamento: ${_fullDateLabel(_paymentDate!)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Observacoes do pagamento',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        maxLines: 2,
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
                    child: Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double? amount = _parseMassageAmount(_amountController.text);
    final String? attendanceType = _selectedAttendanceType?.trim();
    final int? providerId = _selectedProviderId;
    final int? therapistId = _selectedTherapistId;
    if (amount == null ||
        attendanceType == null ||
        attendanceType.isEmpty ||
        providerId == null ||
        therapistId == null) {
      return;
    }
    if (_paid && (_paymentMethod == null || _paymentDate == null)) {
      return;
    }

    Navigator.of(context).pop<_BookingDraft>(
      _BookingDraft(
        date: _selectedDate,
        time: _selectedTime,
        clientName: _clientController.text.trim(),
        clientWhatsappNumber: _clientWhatsappController.text.trim().isEmpty
            ? null
            : _clientWhatsappController.text.trim(),
        guestOrExternal: attendanceType,
        treatment: _selectedTreatment,
        amount: amount,
        providerId: providerId,
        therapistId: therapistId,
        paid: _paid,
        paymentMethod: _paymentMethod,
        paymentDate: _paymentDate,
        paymentNotes: _paymentNotesController.text.trim().isEmpty
            ? null
            : _paymentNotesController.text.trim(),
      ),
    );
  }

  Future<void> _pickBookingDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      if (_paid && _paymentDate == null) {
        _paymentDate = _selectedDate;
      }
    });
  }

  Future<void> _pickPaymentDate() async {
    final DateTime initialDate = _paymentDate ?? _selectedDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1),
      lastDate: DateTime(initialDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _paymentDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _setPaidValue(bool value) {
    setState(() {
      _paid = value;
      _paymentMethod = value
          ? (_paymentMethod ?? MassagePaymentMethod.card)
          : null;
      _paymentDate = value ? (_paymentDate ?? _selectedDate) : null;
    });
  }

  List<MassageProvider> get _selectableProviders {
    final List<MassageProvider> providers =
        widget.providers
            .where(
              (MassageProvider provider) =>
                  provider.active || provider.id == widget.initialProviderId,
            )
            .toList()
          ..sort(
            (MassageProvider a, MassageProvider b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return providers;
  }

  List<String> get _attendanceTypeOptions {
    final List<String> options = <String>[..._attendanceTypes];
    final String currentValue = widget.initialGuestReference.trim();
    if (currentValue.isNotEmpty && !options.contains(currentValue)) {
      options.add(currentValue);
    }
    return options;
  }

  List<String> get _treatmentOptions {
    final List<String> options = <String>[..._treatmentTypes];
    final String currentValue = widget.initialTreatment.trim();
    if (currentValue.isNotEmpty && !options.contains(currentValue)) {
      options.add(currentValue);
    }
    return options;
  }

  List<String> get _timeOptions {
    final List<String> options = <String>[..._timeSlots];
    final String currentValue = widget.initialTime.trim();
    if (currentValue.isNotEmpty && !options.contains(currentValue)) {
      options.add(currentValue);
      options.sort();
    }
    return options;
  }

  List<MassageTherapist> get _selectableTherapists =>
      _therapistsForSelectedProvider(
        includeTherapistId: widget.initialTherapistId,
      );

  int? _initialProviderId() {
    final List<MassageProvider> providers = _selectableProviders;
    if (providers.isEmpty) {
      return null;
    }
    final bool hasInitialProvider = providers.any(
      (MassageProvider provider) => provider.id == widget.initialProviderId,
    );
    return hasInitialProvider ? widget.initialProviderId : providers.first.id;
  }

  int? _initialTherapistId() {
    final List<MassageTherapist> therapists = _therapistsForSelectedProvider(
      providerId: _selectedProviderId,
      includeTherapistId: widget.initialTherapistId,
    );
    if (therapists.isEmpty) {
      return null;
    }
    final bool hasInitialTherapist = therapists.any(
      (MassageTherapist therapist) => therapist.id == widget.initialTherapistId,
    );
    return hasInitialTherapist
        ? widget.initialTherapistId
        : therapists.first.id;
  }

  List<MassageTherapist> _therapistsForSelectedProvider({
    int? providerId,
    int? includeTherapistId,
  }) {
    final int? resolvedProviderId = providerId ?? _selectedProviderId;
    if (resolvedProviderId == null) {
      return const <MassageTherapist>[];
    }
    MassageProvider? provider;
    for (final MassageProvider candidate in widget.providers) {
      if (candidate.id == resolvedProviderId) {
        provider = candidate;
        break;
      }
    }
    if (provider == null) {
      return const <MassageTherapist>[];
    }
    final List<MassageTherapist> therapists =
        provider.therapists
            .where(
              (MassageTherapist therapist) =>
                  therapist.active || therapist.id == includeTherapistId,
            )
            .toList()
          ..sort(
            (MassageTherapist a, MassageTherapist b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return therapists;
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
      label: 'Pagamento recebido',
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

enum _BookingAction { edit, payment, share, cancel, history }

class _BookingActionDialog extends StatelessWidget {
  const _BookingActionDialog({required this.booking, required this.sharing});

  final MassageBooking booking;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.alertWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Acoes do atendimento',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${booking.clientName} as ${_timeLabel(booking.startAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (booking.status == MassageBookingStatus.cancelled)
            Text(
              'Atendimento cancelado. Apenas o historico permanece visivel.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: booking.status == MassageBookingStatus.cancelled
                    ? null
                    : () => Navigator.of(context).pop(_BookingAction.edit),
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('Editar registro'),
              ),
              OutlinedButton.icon(
                onPressed:
                    booking.paid ||
                        booking.status == MassageBookingStatus.cancelled
                    ? null
                    : () => Navigator.of(context).pop(_BookingAction.payment),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Informar pago'),
              ),
              OutlinedButton.icon(
                onPressed: sharing
                    ? null
                    : () => Navigator.of(context).pop(_BookingAction.share),
                icon: Icon(
                  sharing ? Icons.hourglass_top_rounded : Icons.send_rounded,
                ),
                label: Text(sharing ? 'Preparando...' : 'Avisar no WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_BookingAction.history),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Historico'),
              ),
              FilledButton.icon(
                onPressed: booking.status == MassageBookingStatus.cancelled
                    ? null
                    : () => Navigator.of(context).pop(_BookingAction.cancel),
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancelar atendimento'),
              ),
            ],
          ),
          if (booking.status == MassageBookingStatus.cancelled) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingSelectionDialog extends StatelessWidget {
  const _BookingSelectionDialog({
    required this.title,
    required this.description,
    required this.bookings,
    required this.emptyMessage,
    required this.onSelectLabel,
  });

  final String title;
  final String description;
  final List<MassageBooking> bookings;
  final String emptyMessage;
  final String onSelectLabel;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
      maxHeight: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Expanded(
            child: bookings.isEmpty
                ? Center(child: Text(emptyMessage))
                : ListView.separated(
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final MassageBooking booking = bookings[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: CostaNorteBrand.line),
                          color: _providerColor(booking.providerId),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    booking.clientName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_timeLabel(booking.startAt)} - ${booking.treatment} - '
                                    '${booking.providerName} / ${booking.therapistName}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _statusDescription(booking),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: _statusColor(booking),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pop<MassageBooking>(booking),
                              child: Text(onSelectLabel),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({required this.booking});

  final MassageBooking booking;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final MassagePaymentMethod paymentMethod;
  final DateTime paymentDate;
  final String? paymentNotes;
}

class _PaymentBookingDialog extends StatefulWidget {
  const _PaymentBookingDialog({required this.booking});

  final MassageBooking booking;

  @override
  State<_PaymentBookingDialog> createState() => _PaymentBookingDialogState();
}

class _PaymentBookingDialogState extends State<_PaymentBookingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late MassagePaymentMethod _paymentMethod;
  late DateTime _paymentDate;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.booking.paymentNotes ?? '',
    );
    _paymentMethod = widget.booking.paymentMethod ?? MassagePaymentMethod.card;
    final DateTime baseDate =
        widget.booking.paymentDate ?? widget.booking.bookingDate;
    _paymentDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Informar pago',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.booking.clientName} as ${_timeLabel(widget.booking.startAt)}. Valor: R\$ ${widget.booking.amount.toStringAsFixed(0)}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MassagePaymentMethod>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Meio de pagamento',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              ),
              items: MassagePaymentMethod.values
                  .map(
                    (MassagePaymentMethod method) =>
                        DropdownMenuItem<MassagePaymentMethod>(
                          value: method,
                          child: Text(method.label),
                        ),
                  )
                  .toList(),
              onChanged: (MassagePaymentMethod? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _paymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickPaymentDate,
              icon: const Icon(Icons.event_rounded),
              label: Text('Data do pagamento: ${_fullDateLabel(_paymentDate)}'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observacao do pagamento',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Confirmar pagamento'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(_paymentDate.year - 1),
      lastDate: DateTime(_paymentDate.year + 2, 12, 31),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _paymentDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _PaymentDraft(
        paymentMethod: _paymentMethod,
        paymentDate: _paymentDate,
        paymentNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.standardFormWidth,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cancelar atendimento',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.booking.clientName} as ${_timeLabel(widget.booking.startAt)}. O historico sera mantido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observacao do cancelamento',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a observacao do cancelamento.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Confirmar cancelamento'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_notesController.text.trim());
  }
}

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({
    required this.initialProviders,
    required this.massageAppService,
  });

  final List<MassageProvider> initialProviders;
  final MassageAppService massageAppService;

  @override
  State<_ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<_ProviderDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _providerFilterController =
      TextEditingController();
  final TextEditingController _therapistNameController =
      TextEditingController();
  final TextEditingController _therapistWhatsappController =
      TextEditingController();
  final FocusNode _therapistNameFocusNode = FocusNode();

  late List<MassageProvider> _providers;
  int? _selectedProviderId;
  bool _creatingProvider = false;
  bool _saving = false;
  bool _whatsappEnabled = false;
  bool _therapistWhatsappEnabled = false;
  String? _historyError;
  String? _historyLoadingKey;

  @override
  void initState() {
    super.initState();
    _providers = widget.initialProviders
        .map(
          (MassageProvider provider) => MassageProvider(
            id: provider.id,
            name: provider.name,
            specialty: provider.specialty,
            contact: provider.contact,
            whatsappNumber: provider.whatsappNumber,
            whatsappEnabled: provider.whatsappEnabled,
            active: provider.active,
            therapists: provider.therapists
                .map(
                  (MassageTherapist therapist) => MassageTherapist(
                    id: therapist.id,
                    name: therapist.name,
                    active: therapist.active,
                    whatsappNumber: therapist.whatsappNumber,
                    whatsappEnabled: therapist.whatsappEnabled,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    _selectedProviderId = null;
    _clearProviderForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _providerFilterController.dispose();
    _therapistNameController.dispose();
    _therapistWhatsappController.dispose();
    _therapistNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.wideFormWidth * 1.25,
      maxHeight: 875,
      child: SizedBox(
        width: AppDialogDimensions.wideFormWidth * 1.25,
        height: 875,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Prestadores de massagens',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Cadastre fornecedores aqui para disponibiliza-los no combo da agenda.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_historyError != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _historyError!,
                style: const TextStyle(color: CostaNorteBrand.error),
              ),
            ],
            if (!_isEditingProvider) ...<Widget>[
              const SizedBox(height: 14),
              _buildProviderSummary(context),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  IconButton.filled(
                    tooltip: 'Adicionar prestador',
                    onPressed: _saving ? null : _prepareNewProvider,
                    icon: const Icon(Icons.add_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _providerFilterController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Filtrar por nome',
                        hintText: 'Digite letras do nome do prestador',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _providerFilterController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    _providerFilterController.clear();
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!_isEditingProvider)
                    Expanded(
                      flex: 5,
                      child: _filteredProviders.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                border: Border.all(color: CostaNorteBrand.line),
                              ),
                              child: Text(
                                'Nenhum prestador coincide com a busca informada.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filteredProviders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) {
                                final MassageProvider provider =
                                    _filteredProviders[index];
                                final bool selected =
                                    provider.id == _selectedProviderId;
                                final int activeTherapists = provider.therapists
                                    .where(
                                      (MassageTherapist therapist) =>
                                          therapist.active,
                                    )
                                    .length;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? CostaNorteBrand.royalBlueDeep
                                          : CostaNorteBrand.line,
                                    ),
                                    color: selected
                                        ? CostaNorteBrand.mist
                                        : Colors.white,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      setState(() {
                                        _selectProvider(provider);
                                      });
                                    },
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                provider.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                provider.specialty,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                provider.contact,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$activeTherapists massagistas ativos',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: CostaNorteBrand
                                                          .mutedInk,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            IconButton(
                                              onPressed:
                                                  _historyLoadingKey ==
                                                      'provider:${provider.id}'
                                                  ? null
                                                  : () => _openProviderHistory(
                                                      provider,
                                                    ),
                                              icon: Icon(
                                                _historyLoadingKey ==
                                                        'provider:${provider.id}'
                                                    ? Icons
                                                          .hourglass_top_rounded
                                                    : Icons.history_rounded,
                                              ),
                                            ),
                                            Text(
                                              provider.active ? 'ON' : 'OFF',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: provider.active
                                                        ? CostaNorteBrand
                                                              .royalBlueDeep
                                                        : CostaNorteBrand.error,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Switch(
                                              value: provider.active,
                                              onChanged: _saving
                                                  ? null
                                                  : (bool value) =>
                                                        _toggleProvider(
                                                          provider.id,
                                                          value,
                                                        ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  if (_isEditingProvider)
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: CostaNorteBrand.mist,
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildProviderEditor(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _closeProviderEditor,
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving
                                        ? null
                                        : () {
                                            Navigator.of(
                                              context,
                                            ).pop<List<MassageProvider>>(
                                              _providers,
                                            );
                                          },
                                    child: const Text('Aplicar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildProviderSummary(BuildContext context) {
    final int activeProviders = _providers
        .where((MassageProvider provider) => provider.active)
        .length;
    final int activeTherapists = _providers.fold<int>(
      0,
      (int total, MassageProvider provider) =>
          total +
          provider.therapists
              .where((MassageTherapist therapist) => therapist.active)
              .length,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CostaNorteBrand.mist,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resumo rapido',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Escolha primeiro o que deseja modificar. Nenhum prestador fica pre-selecionado ao abrir esta tela.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildSummaryChip(
                context,
                Icons.groups_2_rounded,
                '${_providers.length} prestadores',
              ),
              _buildSummaryChip(
                context,
                Icons.verified_user_rounded,
                '$activeProviders ativos',
              ),
              _buildSummaryChip(
                context,
                Icons.spa_outlined,
                '$activeTherapists massagistas ativos',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: CostaNorteBrand.royalBlueDeep),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildProviderEditor(BuildContext context) {
    if (!_isEditingProvider) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: CostaNorteBrand.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.touch_app_rounded,
              color: CostaNorteBrand.royalBlueDeep,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Selecione um prestador para editar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Use os cards da esquerda para editar um prestador existente ou crie um novo com o botao superior.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _creatingProvider ? 'Novo prestador' : 'Editar prestador',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _specialtyController,
          decoration: const InputDecoration(labelText: 'Especialidade'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contactController,
          decoration: const InputDecoration(labelText: 'Contato'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp',
            hintText: '5511999998888',
            helperText: 'Numero internacional, somente digitos.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _whatsappEnabled,
          onChanged: (value) => setState(() => _whatsappEnabled = value),
          title: const Text('Disponível para contato por WhatsApp'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _saveProvider,
          icon: Icon(
            _creatingProvider ? Icons.playlist_add_rounded : Icons.save_rounded,
          ),
          label: Text(
            _saving
                ? 'Salvando...'
                : _creatingProvider
                ? 'Adicionar'
                : 'Salvar mudancas',
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _creatingProvider ? 'Massagistas' : 'Massagistas do prestador',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_selectedProvider != null)
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        _therapistNameController.clear();
                        _therapistNameFocusNode.requestFocus();
                      },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo massagista'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_creatingProvider)
          Text(
            'Salve primeiro o prestador para poder registrar e ativar massagistas.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...<Widget>[
          Text(
            _selectedProvider!.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _selectedProvider!.therapists.isEmpty
                ? Center(
                    child: Text(
                      'Esse prestador ainda não possui massagistas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _selectedProvider!.therapists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final MassageTherapist therapist =
                          _selectedProvider!.therapists[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                therapist.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            Switch(
                              value: therapist.active,
                              onChanged: _saving
                                  ? null
                                  : (bool value) => _toggleTherapist(
                                      _selectedProvider!,
                                      therapist,
                                      value,
                                    ),
                            ),
                            IconButton(
                              onPressed:
                                  _historyLoadingKey ==
                                      'therapist:${therapist.id}'
                                  ? null
                                  : () => _openTherapistHistory(
                                      _selectedProvider!,
                                      therapist,
                                    ),
                              icon: Icon(
                                _historyLoadingKey ==
                                        'therapist:${therapist.id}'
                                    ? Icons.hourglass_top_rounded
                                    : Icons.history_rounded,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _therapistNameController,
            focusNode: _therapistNameFocusNode,
            decoration: const InputDecoration(labelText: 'Novo massagista'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _therapistWhatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp do massagista',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _therapistWhatsappEnabled,
            onChanged: (bool value) =>
                setState(() => _therapistWhatsappEnabled = value),
            title: const Text('Disponível para contato por WhatsApp'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _addTherapist,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(_saving ? 'Salvando...' : 'Adicionar massagista'),
          ),
        ],
      ],
    );
  }

  List<MassageProvider> get _filteredProviders {
    final String query = _providerFilterController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _providers;
    }
    return _providers.where((MassageProvider provider) {
      return provider.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _addProvider() async {
    final String name = _nameController.text.trim();
    final String specialty = _specialtyController.text.trim();
    final String contact = _contactController.text.trim();
    final String whatsapp = _whatsappController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (name.isEmpty || specialty.isEmpty || contact.isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Complete nome, especialidade e contato.',
      );
      return;
    }

    final bool exists = _providers.any(
      (MassageProvider provider) =>
          provider.name.trim().toLowerCase() == name.toLowerCase() &&
          provider.contact.trim().toLowerCase() == contact.toLowerCase(),
    );
    if (exists) {
      await AppAlerts.info(
        context,
        title: 'Prestador ja cadastrado',
        message: 'Ja existe um prestador com esse nome e contato.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final MassageProvider created = await widget.massageAppService
          .createProvider(
            CreateMassageProviderModel(
              name: name,
              specialty: specialty,
              contact: contact,
              whatsappNumber: whatsapp.isEmpty ? null : whatsapp,
              whatsappEnabled: _whatsappEnabled && whatsapp.isNotEmpty,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _providers = <MassageProvider>[..._providers, created]
          ..sort(
            (MassageProvider a, MassageProvider b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        _creatingProvider = false;
        _selectProvider(
          _providers.firstWhere(
            (MassageProvider provider) => provider.id == created.id,
          ),
        );
        _saving = false;
      });
      await AppAlerts.success(
        context,
        title: 'Prestador salvo',
        message: 'Prestador criado e disponivel para novos atendimentos.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao salvar prestador',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _saveProvider() async {
    if (_creatingProvider) {
      await _addProvider();
      return;
    }
    await _updateSelectedProvider();
  }

  Future<void> _toggleProvider(int providerId, bool active) async {
    final int index = _providers.indexWhere(
      (MassageProvider provider) => provider.id == providerId,
    );
    if (index < 0) {
      return;
    }
    final MassageProvider provider = _providers[index];
    setState(() {
      _saving = true;
      _providers[index] = provider.copyWith(active: active);
    });

    try {
      final MassageProvider updated = await widget.massageAppService
          .updateProvider(
            provider.id,
            UpdateMassageProviderModel(
              name: provider.name,
              specialty: provider.specialty,
              contact: provider.contact,
              active: active,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _providers[index] =
            updated.therapists.isEmpty && provider.therapists.isNotEmpty
            ? updated.copyWith(therapists: provider.therapists)
            : updated;
        _saving = false;
      });
      await AppAlerts.success(
        context,
        title: 'Prestador atualizado',
        message: '${updated.name} foi atualizado com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providers[index] = provider;
        _saving = false;
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao atualizar prestador',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  MassageProvider? get _selectedProvider {
    if (_selectedProviderId == null) {
      return null;
    }
    for (final MassageProvider provider in _providers) {
      if (provider.id == _selectedProviderId) {
        return provider;
      }
    }
    return null;
  }

  bool get _isEditingProvider => _creatingProvider || _selectedProvider != null;

  Future<void> _openProviderHistory(MassageProvider provider) async {
    await _openCatalogHistory(
      loadingKey: 'provider:${provider.id}',
      title: 'Historico de ${provider.name}',
      loader: () => widget.massageAppService.providerHistory(provider.id),
    );
  }

  Future<void> _openTherapistHistory(
    MassageProvider provider,
    MassageTherapist therapist,
  ) async {
    await _openCatalogHistory(
      loadingKey: 'therapist:${therapist.id}',
      title: 'Historico de ${therapist.name}',
      loader: () =>
          widget.massageAppService.therapistHistory(provider.id, therapist.id),
    );
  }

  Future<void> _openCatalogHistory({
    required String loadingKey,
    required String title,
    required Future<List<AuditEventModel>> Function() loader,
  }) async {
    setState(() {
      _historyLoadingKey = loadingKey;
      _historyError = null;
    });
    try {
      final List<AuditEventModel> events = await loader();
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: title,
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
        setState(() {
          _historyLoadingKey = null;
        });
      }
    }
  }

  void _prepareNewProvider() {
    setState(() {
      _selectedProviderId = null;
      _creatingProvider = true;
      _clearProviderForm();
    });
  }

  void _closeProviderEditor() {
    setState(() {
      _selectedProviderId = null;
      _creatingProvider = false;
      _clearProviderForm();
    });
  }

  void _selectProvider(MassageProvider provider) {
    _selectedProviderId = provider.id;
    _creatingProvider = false;
    _loadProviderForm(provider);
  }

  void _clearProviderForm() {
    _nameController.clear();
    _specialtyController.clear();
    _contactController.clear();
    _whatsappController.clear();
    _whatsappEnabled = false;
    _therapistNameController.clear();
    _therapistWhatsappController.clear();
    _therapistWhatsappEnabled = false;
  }

  void _loadProviderForm(MassageProvider provider) {
    _nameController.text = provider.name;
    _specialtyController.text = provider.specialty;
    _contactController.text = provider.contact;
    _whatsappController.text = provider.whatsappNumber ?? '';
    _whatsappEnabled = provider.whatsappEnabled;
    _therapistNameController.clear();
    _therapistWhatsappController.clear();
    _therapistWhatsappEnabled = false;
  }

  Future<void> _updateSelectedProvider() async {
    final MassageProvider? provider = _selectedProvider;
    final String name = _nameController.text.trim();
    final String specialty = _specialtyController.text.trim();
    final String contact = _contactController.text.trim();
    final String whatsapp = _whatsappController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (provider == null) {
      return;
    }
    if (name.isEmpty || specialty.isEmpty || contact.isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campos obrigatorios',
        message: 'Complete nome, especialidade e contato.',
      );
      return;
    }

    final bool exists = _providers.any(
      (MassageProvider item) =>
          item.id != provider.id &&
          item.name.trim().toLowerCase() == name.toLowerCase() &&
          item.contact.trim().toLowerCase() == contact.toLowerCase(),
    );
    if (exists) {
      await AppAlerts.info(
        context,
        title: 'Prestador duplicado',
        message: 'Ja existe outro prestador com esse nome e contato.',
      );
      return;
    }

    final int index = _providers.indexWhere(
      (MassageProvider item) => item.id == provider.id,
    );
    setState(() {
      _saving = true;
      _providers[index] = provider.copyWith(
        name: name,
        specialty: specialty,
        contact: contact,
        whatsappNumber: whatsapp.isEmpty ? null : whatsapp,
        whatsappEnabled: _whatsappEnabled && whatsapp.isNotEmpty,
      );
    });

    try {
      final MassageProvider updated = await widget.massageAppService
          .updateProvider(
            provider.id,
            UpdateMassageProviderModel(
              name: name,
              specialty: specialty,
              contact: contact,
              active: provider.active,
              whatsappNumber: whatsapp.isEmpty ? null : whatsapp,
              whatsappEnabled: _whatsappEnabled && whatsapp.isNotEmpty,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _providers[index] =
            updated.therapists.isEmpty && provider.therapists.isNotEmpty
            ? updated.copyWith(therapists: provider.therapists)
            : updated;
        _providers.sort(
          (MassageProvider a, MassageProvider b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        _creatingProvider = false;
        _saving = false;
        _selectProvider(
          _providers.firstWhere(
            (MassageProvider item) => item.id == updated.id,
          ),
        );
      });
      await AppAlerts.success(
        context,
        title: 'Prestador atualizado',
        message: '${updated.name} foi atualizado com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providers[index] = provider;
        _saving = false;
        _loadProviderForm(provider);
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao atualizar prestador',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _addTherapist() async {
    final MassageProvider? provider = _selectedProvider;
    final String name = _therapistNameController.text.trim();
    if (provider == null) {
      return;
    }
    if (name.isEmpty) {
      await AppAlerts.warning(
        context,
        title: 'Campo obrigatorio',
        message: 'Informe o nome do massagista.',
      );
      return;
    }
    final bool exists = provider.therapists.any(
      (MassageTherapist therapist) =>
          therapist.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      await AppAlerts.info(
        context,
        title: 'Massagista ja cadastrado',
        message:
            'Já existe um massagista com esse nome para o prestador selecionado.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final MassageTherapist created = await widget.massageAppService
          .createTherapist(
            provider.id,
            CreateMassageTherapistModel(
              name: name,
              whatsappNumber: _therapistWhatsappController.text.trim().isEmpty
                  ? null
                  : _therapistWhatsappController.text.trim(),
              whatsappEnabled: _therapistWhatsappEnabled,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        final int providerIndex = _providers.indexWhere(
          (MassageProvider item) => item.id == provider.id,
        );
        final List<MassageTherapist> therapists =
            <MassageTherapist>[...provider.therapists, created]..sort(
              (MassageTherapist a, MassageTherapist b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
        _providers[providerIndex] = provider.copyWith(therapists: therapists);
        _saving = false;
      });
      _therapistNameController.clear();
      _therapistWhatsappController.clear();
      _therapistWhatsappEnabled = false;
      await AppAlerts.success(
        context,
        title: 'Massagista salvo',
        message: 'Massagista criado para o prestador selecionado.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao salvar massagista',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _toggleTherapist(
    MassageProvider provider,
    MassageTherapist therapist,
    bool active,
  ) async {
    final int providerIndex = _providers.indexWhere(
      (MassageProvider item) => item.id == provider.id,
    );
    final int therapistIndex = provider.therapists.indexWhere(
      (MassageTherapist item) => item.id == therapist.id,
    );
    setState(() {
      _saving = true;
      final List<MassageTherapist> therapists = <MassageTherapist>[
        ...provider.therapists,
      ];
      therapists[therapistIndex] = therapist.copyWith(active: active);
      _providers[providerIndex] = provider.copyWith(therapists: therapists);
    });

    try {
      final MassageTherapist updated = await widget.massageAppService
          .updateTherapist(
            provider.id,
            therapist.id,
            UpdateMassageTherapistModel(name: therapist.name, active: active),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        final List<MassageTherapist> therapists = <MassageTherapist>[
          ..._providers[providerIndex].therapists,
        ];
        therapists[therapistIndex] = updated;
        _providers[providerIndex] = _providers[providerIndex].copyWith(
          therapists: therapists,
        );
        _saving = false;
      });
      await AppAlerts.success(
        context,
        title: 'Massagista atualizado',
        message: '${updated.name} foi atualizado com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final List<MassageTherapist> therapists = <MassageTherapist>[
          ...provider.therapists,
        ];
        _providers[providerIndex] = provider.copyWith(therapists: therapists);
        _saving = false;
      });
      await AppAlerts.error(
        context,
        title: 'Falha ao atualizar massagista',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }
}

String _weekdayLabel(DateTime date) {
  return const <String>[
    'Segunda',
    'Terca',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sabado',
    'Domingo',
  ][date.weekday - 1];
}

String _fullDateLabel(DateTime date) {
  return '${_weekdayLabel(date)}, ${date.day} de ${_monthLabels[date.month - 1]} de ${date.year}';
}

String _timeLabel(DateTime date) {
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateApi(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatTimeApi(String time) {
  return time.length == 5 ? '$time:00' : time;
}

String _statusLabel(MassageBooking booking) {
  if (booking.status == MassageBookingStatus.cancelled) {
    return 'Cancelado';
  }
  return booking.paid ? 'Pago' : 'Pendente';
}

String _statusDescription(MassageBooking booking) {
  if (booking.status == MassageBookingStatus.cancelled) {
    return booking.cancellationNotes == null
        ? 'Atendimento cancelado'
        : 'Cancelado: ${booking.cancellationNotes}';
  }
  if (!booking.paid) {
    return 'Pagamento pendente';
  }
  final String methodLabel =
      booking.paymentMethod?.label ?? 'Meio nao informado';
  final String dateLabel = booking.paymentDate == null
      ? 'data nao informada'
      : _formatShortDateLabel(booking.paymentDate!);
  return 'Pago em $dateLabel via $methodLabel';
}

String _statusLabelForReportItem(MassageProviderReportItem item) {
  if (item.status == MassageBookingStatus.cancelled) {
    return 'Cancelado';
  }
  return item.paid ? 'Pago' : 'Pendente';
}

String _statusDescriptionForReportItem(MassageProviderReportItem item) {
  if (item.status == MassageBookingStatus.cancelled) {
    return item.cancellationNotes == null
        ? 'Atendimento cancelado'
        : 'Cancelado: ${item.cancellationNotes}';
  }
  if (!item.paid) {
    return 'Pagamento pendente';
  }
  final String methodLabel = item.paymentMethod?.label ?? 'Meio nao informado';
  final String dateLabel = item.paymentDate == null
      ? 'data nao informada'
      : _formatShortDateLabel(item.paymentDate!);
  return 'Pago em $dateLabel via $methodLabel';
}

Color _statusColor(MassageBooking booking) {
  if (booking.status == MassageBookingStatus.cancelled) {
    return CostaNorteBrand.error;
  }
  return booking.paid ? CostaNorteBrand.success : CostaNorteBrand.goldDeep;
}

Color _providerColor(int providerId) {
  switch (providerId % 4) {
    case 0:
      return const Color(0xFFE8F0FF);
    case 1:
      return const Color(0xFFFFF0D5);
    case 2:
      return const Color(0xFFFBE7EC);
    default:
      return const Color(0xFFE8F7EE);
  }
}

String _formatShortDateLabel(DateTime date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatCurrencyLabel(double amount) {
  return 'R\$ ${amount.toStringAsFixed(0)}';
}

double? _parseMassageAmount(String? raw) {
  if (raw == null) {
    return null;
  }
  final String normalized = raw
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(normalized);
}

const List<String> _timeSlots = <String>[
  '09:00',
  '09:30',
  '10:00',
  '10:30',
  '11:00',
  '11:30',
  '12:00',
  '12:30',
  '13:00',
  '13:30',
  '14:00',
  '14:30',
  '15:00',
  '15:30',
  '16:00',
  '16:30',
  '17:00',
  '17:30',
  '18:00',
  '18:30',
  '19:00',
  '19:30',
  '20:00',
  '20:30',
  '21:00',
];
