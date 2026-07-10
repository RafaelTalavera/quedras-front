import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/audit/audit_models.dart';
import '../../../core/audit/audit_timeline_dialog.dart';
import '../../../core/files/file_save_result.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/feedback/app_share.dart';
import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/sync/schedule_sync_service.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../courts/application/court_app_service.dart';
import '../../courts/application/partner_coach_report_pdf_exporter.dart';
import '../../courts/domain/court_models.dart';

const List<String> _courtWeekLabels = <String>[
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sab',
  'Dom',
];

const List<String> _courtWeekFullLabels = <String>[
  'Segunda-feira',
  'Terca-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sabado',
  'Domingo',
];

const List<String> _courtMonthLabels = <String>[
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

const List<String> _courtTimeSlots = <String>[
  '07:00',
  '07:30',
  '08:00',
  '08:30',
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
  '21:30',
  '22:00',
];

enum TennisRentalSection { selectedDay, monthlyAgenda, summary }

class TennisRentalPageController {
  _TennisRentalPageState? _state;

  Future<void> scrollToSection(TennisRentalSection section) async {
    await _state?._scrollToSection(section);
  }

  void _attach(_TennisRentalPageState state) {
    _state = state;
  }

  void _detach(_TennisRentalPageState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

class TennisRentalPage extends StatefulWidget {
  const TennisRentalPage({
    required this.courtAppService,
    required this.scheduleSyncService,
    this.partnerCoachReportPdfExporter,
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final CourtAppService courtAppService;
  final ScheduleSyncService scheduleSyncService;
  final PartnerCoachReportPdfExporter? partnerCoachReportPdfExporter;
  final TennisRentalPageController? controller;
  final ValueChanged<TennisRentalSection>? onSectionChanged;

  @override
  State<TennisRentalPage> createState() => _TennisRentalPageState();
}

class _TennisRentalPageState extends State<TennisRentalPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;
  ModalRoute<dynamic>? _route;
  late final PartnerCoachReportPdfExporter _partnerCoachReportPdfExporter;
  late DateTime _selectedDate;
  late DateTime _reportStartDate;
  late DateTime _reportEndDate;
  bool _loading = true;
  bool _refreshingData = false;
  bool _loadingAgenda = false;
  bool _loadingSummary = false;
  bool _saving = false;
  int? _sharingBookingId;
  int? _loadingHistoryBookingId;
  String? _errorMessage;
  String? _summaryErrorMessage;
  String? _selectedSummaryDetailKey;
  List<CourtBooking> _bookings = <CourtBooking>[];
  List<CourtBooking> _summaryBookings = <CourtBooking>[];
  CourtSummaryReport? _summary;
  TennisRentalSection _currentSection = TennisRentalSection.selectedDay;
  String? _agendaErrorMessage;
  String? _loadedAgendaKey;
  String? _loadedSummaryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _selectedDate = DateTime.now();
    _reportStartDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _reportEndDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    _partnerCoachReportPdfExporter =
        widget.partnerCoachReportPdfExporter ??
        DefaultPartnerCoachReportPdfExporter();
    _syncSubscription = widget.scheduleSyncService.events.listen(
      _handleSyncEvent,
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant TennisRentalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
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

  List<CourtBooking> get _dayBookings =>
      _bookings.where((CourtBooking item) {
        return _sameDay(item.bookingDate, _selectedDate);
      }).toList()..sort(
        (CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime),
      );

  List<CourtBooking> get _monthBookings =>
      _bookings.where((CourtBooking item) {
        return item.bookingDate.year == _selectedDate.year &&
            item.bookingDate.month == _selectedDate.month;
      }).toList()..sort(
        (CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            eyebrow: 'Operacao ativa',
            title: 'Quadras de tenis',
            description:
                'Reserva operacional de quadras com controle de horas, pagamento, materiais e regras por tipo de usuario.',
            icon: Icons.sports_tennis_rounded,
            photoAlignment: Alignment.centerRight,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saving ? null : _openCreateDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Lancar reserva'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSection(TennisRentalSection.monthlyAgenda),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Agenda mensal'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSection(TennisRentalSection.summary),
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Periodo'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _openSettingsDialog,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Tarifas e materiais'),
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
            _buildSelectedDayCard(context),
        ],
      ),
    );
  }

  Future<void> _scrollToSection(TennisRentalSection section) async {
    await _showSection(section);
  }

  void _setCurrentSection(TennisRentalSection section) {
    if (_currentSection == section) {
      return;
    }
    _currentSection = section;
    widget.onSectionChanged?.call(section);
  }

  Future<void> _showSection(TennisRentalSection section) async {
    if (section == TennisRentalSection.monthlyAgenda) {
      await _openAgendaDialog();
      return;
    }
    if (section == TennisRentalSection.summary) {
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
      final Future<List<CourtBooking>> bookingsFuture = widget.courtAppService
          .listBookings(bookingDate: _formatDate(_selectedDate));
      final List<CourtBooking> bookings = await bookingsFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceCachedBookings(
          startDate: _selectedDate,
          endDate: _selectedDate,
          bookings: bookings,
        );
        _selectedSummaryDetailKey = null;
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
    return mounted &&
        !_loading &&
        !_refreshingData &&
        !_loadingAgenda &&
        !_loadingSummary &&
        !_saving &&
        (_route?.isCurrent ?? true);
  }

  Future<void> _refreshActiveData({bool showLoading = false}) async {
    await _load(showLoading: showLoading);
    if (_currentSection == TennisRentalSection.monthlyAgenda) {
      await _loadAgenda(force: true);
    }
    if (_currentSection == TennisRentalSection.summary) {
      await _reloadSummary(force: true);
    }
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain != ScheduleSyncDomain.courts || !_canAutoRefresh()) {
      return;
    }
    if (!_isRelevantSyncEvent(event)) {
      return;
    }
    unawaited(_refreshActiveData(showLoading: false));
  }

  bool _isRelevantSyncEvent(ScheduleSyncEvent event) {
    switch (_currentSection) {
      case TennisRentalSection.selectedDay:
        return event.affectsDay(_selectedDate);
      case TennisRentalSection.monthlyAgenda:
        return event.affectsRange(
          DateTime(_selectedDate.year, _selectedDate.month, 1),
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
        );
      case TennisRentalSection.summary:
        return event.affectsRange(_reportStartDate, _reportEndDate);
    }
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);

  String _monthKeyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _summaryKeyFor(DateTime startDate, DateTime endDate) =>
      '${_formatDate(startDate)}|${_formatDate(endDate)}';

  bool get _hasAgendaForSelectedMonth =>
      _loadedAgendaKey == _monthKeyFor(_selectedDate);

  bool get _hasSummaryForSelectedRange =>
      _loadedSummaryKey == _summaryKeyFor(_reportStartDate, _reportEndDate);

  Future<void> _loadAgenda({bool force = false}) async {
    if (!force && _hasAgendaForSelectedMonth) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingAgenda = true;
      _agendaErrorMessage = null;
    });
    try {
      final List<CourtBooking> bookings = await widget.courtAppService
          .listBookings(
            dateFrom: _formatDate(_monthStart(_selectedDate)),
            dateTo: _formatDate(_monthEnd(_selectedDate)),
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

  void _replaceCachedBookings({
    required DateTime startDate,
    required DateTime endDate,
    required List<CourtBooking> bookings,
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
    final List<CourtBooking> nextBookings = _bookings.where((
      CourtBooking item,
    ) {
      return item.bookingDate.isBefore(normalizedStart) ||
          item.bookingDate.isAfter(normalizedEnd);
    }).toList()..addAll(bookings);
    nextBookings.sort(
      (CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime),
    );
    _bookings = nextBookings;
  }

  Future<void> _shareBookingReceipt(CourtBooking booking) async {
    if (_sharingBookingId != null) {
      return;
    }

    setState(() {
      _sharingBookingId = booking.id;
    });

    try {
      await AppShare.shareText(
        context,
        text: _buildBookingShareMessage(booking),
        subject: 'Reserva de quadra ${booking.customerName}',
        failureTitle: 'Falha ao compartilhar reserva',
        failureMessagePrefix: 'Nao foi possivel preparar os dados da reserva',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharingBookingId = null;
        });
      }
    }
  }

  String _buildBookingShareMessage(CourtBooking booking) {
    final String paymentLine = booking.status == CourtBookingStatus.cancelled
        ? booking.cancellationNotes == null
              ? 'Estado: cancelada'
              : 'Estado: cancelada (${booking.cancellationNotes})'
        : booking.paid
        ? 'Pago em ${_formatShortDate(booking.paymentDate ?? booking.bookingDate)} via ${booking.paymentMethod?.label ?? 'meio nao informado'}'
        : 'Pagamento pendente';
    final StringBuffer buffer = StringBuffer()
      ..writeln('Reserva de quadra Hotel Costa Norte')
      ..writeln('Cliente: ${booking.customerName}')
      ..writeln('Data: ${_formatShortDate(booking.bookingDate)}')
      ..writeln(
        'Horario: ${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)}',
      )
      ..writeln('Tipo: ${booking.customerType.label}')
      ..writeln('Recorrencia: ${booking.isRecurring ? 'Semanal' : 'Nao'}')
      ..writeln('Referencia: ${booking.customerReference}')
      ..writeln('Quadra: ${_formatCurrency(booking.courtAmount)}')
      ..writeln('Materiais: ${_formatCurrency(booking.materialsAmount)}')
      ..writeln('Total: ${_formatCurrency(booking.totalAmount)}')
      ..writeln(paymentLine);
    if (booking.materials.isNotEmpty) {
      buffer.writeln(
        'Itens: ${booking.materials.map<String>((CourtBookingMaterial item) => '${item.materialLabel} x${item.quantity}').join(' | ')}',
      );
    }
    return buffer.toString().trim();
  }

  Future<void> _reloadSummary({bool force = false}) async {
    if (!force && _hasSummaryForSelectedRange) {
      return;
    }
    setState(() {
      _loadingSummary = true;
      _summaryErrorMessage = null;
    });
    try {
      final Future<List<CourtBooking>> bookingsFuture = widget.courtAppService
          .listBookings(
            dateFrom: _formatDate(_reportStartDate),
            dateTo: _formatDate(_reportEndDate),
          );
      final CourtSummaryReport summary = await widget.courtAppService
          .getSummaryReport(
            dateFrom: _formatDate(_reportStartDate),
            dateTo: _formatDate(_reportEndDate),
          );
      final List<CourtBooking> bookings = await bookingsFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _summaryBookings = bookings;
        _summary = summary;
        _loadedSummaryKey = _summaryKeyFor(_reportStartDate, _reportEndDate);
        _selectedSummaryDetailKey = null;
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
      if (_currentSection == TennisRentalSection.monthlyAgenda) {
        await _loadAgenda(force: monthChanged);
      }
    }
  }

  Future<void> _pickReportStartDate() async {
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
      _reportStartDate = DateTime(picked.year, picked.month, picked.day);
      if (_reportStartDate.isAfter(_reportEndDate)) {
        _reportEndDate = _reportStartDate;
      }
      _loadedSummaryKey = null;
      _summary = null;
      _summaryBookings = <CourtBooking>[];
      _summaryErrorMessage = null;
    });
  }

  Future<void> _pickReportEndDate() async {
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
      _reportEndDate = DateTime(picked.year, picked.month, picked.day);
      if (_reportEndDate.isBefore(_reportStartDate)) {
        _reportStartDate = _reportEndDate;
      }
      _loadedSummaryKey = null;
      _summary = null;
      _summaryBookings = <CourtBooking>[];
      _summaryErrorMessage = null;
    });
  }

  Future<void> _openAgendaDialog() async {
    _setCurrentSection(TennisRentalSection.monthlyAgenda);
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
                        'Visualizacao mensal de reservas com acesso rapido por dia.',
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildCalendarCard(
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
      _setCurrentSection(TennisRentalSection.selectedDay);
    }
  }

  Future<void> _openSummaryDialog() async {
    _setCurrentSection(TennisRentalSection.summary);
    if (!mounted) {
      return;
    }
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
                        'Resumo operacional do intervalo consultado com detalhes por perfil e parceiro.',
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
      _setCurrentSection(TennisRentalSection.selectedDay);
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

  Widget _buildSelectedDayCard(BuildContext context) {
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
                        'Dia selecionado',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fullDateLabel(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
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
                _DetailChip(
                  label: 'Reservas',
                  value: '${_dayBookings.length}',
                  icon: Icons.event_available_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_dayBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CostaNorteBrand.mist,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CostaNorteBrand.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Agenda livre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nao ha reservas para este dia. Use o calendario abaixo para navegar ou lance uma nova reserva.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ..._dayBookings.map(
                (CourtBooking booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CourtBookingTile(
                    booking: booking,
                    onDoubleTap: () => _openBookingActionDialog(booking),
                    onEdit: _isBookingEditable(booking)
                        ? () => _openEditDialog(booking: booking)
                        : null,
                    onPayment: _canRegisterPayment(booking)
                        ? () => _openPaymentDialog(booking: booking)
                        : null,
                    onCancel: _isBookingEditable(booking)
                        ? () => _openCancelDialog(booking: booking)
                        : null,
                    onHistory: () => _openBookingHistory(booking),
                    loadingHistory: _loadingHistoryBookingId == booking.id,
                    sharing: _sharingBookingId == booking.id,
                    onShare: () => _shareBookingReceipt(booking),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
    VoidCallback? onDaySelected,
  }) {
    final List<_CalendarCell> cells = _buildCalendarCells();
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (asCard)
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
                  value: _selectedDate.month - 1,
                  decoration: const InputDecoration(
                    labelText: 'Mes da agenda',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  items: List<DropdownMenuItem<int>>.generate(
                    _courtMonthLabels.length,
                    (int index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text(_courtMonthLabels[index]),
                    ),
                  ),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
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
                value: _selectedDate.month - 1,
                decoration: const InputDecoration(
                  labelText: 'Mes da agenda',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  _courtMonthLabels.length,
                  (int index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(_courtMonthLabels[index]),
                  ),
                ),
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
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
                children: _courtWeekLabels.map((String label) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: CostaNorteBrand.mutedInk,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: _agendaCellHeight(),
                ),
                itemBuilder: (BuildContext context, int index) {
                  final _CalendarCell cell = cells[index];
                  if (cell.date == null) {
                    return const SizedBox.shrink();
                  }
                  return _CourtAgendaDayCard(
                    date: cell.date!,
                    bookings: _bookingsForDate(cell.date!),
                    selected: _sameDay(cell.date!, _selectedDate),
                    onTap: () => unawaited(
                      _setSelectedDate(cell.date!).then((_) {
                        if (onDaySelected != null) {
                          onDaySelected();
                        } else {
                          onDialogRefresh?.call();
                        }
                      }),
                    ),
                    onDoubleTap: () => _openCalendarDayActions(cell.date!),
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

  Widget _buildSummaryCard(
    BuildContext context, {
    bool asCard = true,
    VoidCallback? onDialogRefresh,
  }) {
    final CourtSummaryReport? summary = _summary;
    final List<_PartnerCoachSummaryRow> partnerCoachRows =
        _buildPartnerCoachSummaryRows();
    final List<CourtBooking> reportBookings = _reportBookings;
    final List<CourtBooking> activeReportBookings = _activeReportBookings;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (asCard) ...<Widget>[
          Text(
            'Resumo do periodo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _loadingSummary
                  ? null
                  : () async {
                      await _pickReportStartDate();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.date_range_rounded),
              label: Text('Inicio: ${_formatShortDate(_reportStartDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loadingSummary
                  ? null
                  : () async {
                      await _pickReportEndDate();
                      onDialogRefresh?.call();
                    },
              icon: const Icon(Icons.event_rounded),
              label: Text('Fim: ${_formatShortDate(_reportEndDate)}'),
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
        const SizedBox(height: 18),
        if (_summaryErrorMessage != null) ...<Widget>[
          Text(
            _summaryErrorMessage!,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 12),
        ],
        if (_loadingSummary && !_hasSummaryForSelectedRange)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (summary == null)
          const Text('Resumo indisponivel.')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: <Widget>[
                  _MetricCard(
                    selected: _selectedSummaryDetailKey == 'metric:overview',
                    title: _formatReportRangeLabel(
                      _reportStartDate,
                      _reportEndDate,
                    ),
                    value: '${summary.scheduledCount} reservas ativas',
                    caption: summary.cancelledCount == 0
                        ? 'Sem cancelamentos no periodo'
                        : '${summary.cancelledCount} canceladas no historico',
                    icon: Icons.calendar_view_month_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'metric:overview',
                      title: 'Reservas ativas do periodo',
                      description:
                          'Lista de reservas ativas dentro do periodo consultado.',
                      bookings: activeReportBookings,
                    ),
                  ),
                  _MetricCard(
                    selected: _selectedSummaryDetailKey == 'metric:materials',
                    title: _formatCurrency(summary.materialsAmount),
                    value: _formatCurrency(summary.courtAmount),
                    caption: 'Materiais vendidos e receita base de quadra',
                    icon: Icons.inventory_2_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'metric:materials',
                      title: 'Materiais e receita base',
                      description:
                          'Reservas ativas com materiais ou cobranca de quadra no periodo.',
                      bookings: activeReportBookings.where((
                        CourtBooking booking,
                      ) {
                        return booking.materialsAmount > 0 ||
                            booking.courtAmount > 0;
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:guest',
                    label: 'Hospedes',
                    value: '${summary.guestHours.toStringAsFixed(1)} h',
                    icon: Icons.king_bed_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:guest',
                      title: 'Detalhe de hospedes',
                      description:
                          'Reservas ativas de hospedes dentro do periodo consultado.',
                      bookings: _filterReportBookingsByCustomerType(
                        CourtCustomerType.guest,
                      ),
                    ),
                  ),
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:vip',
                    label: 'VIP',
                    value: '${summary.vipHours.toStringAsFixed(1)} h',
                    icon: Icons.workspace_premium_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:vip',
                      title: 'Detalhe de clientes VIP',
                      description:
                          'Reservas ativas de clientes VIP dentro do periodo consultado.',
                      bookings: _filterReportBookingsByCustomerType(
                        CourtCustomerType.vip,
                      ),
                    ),
                  ),
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:external',
                    label: 'Externos',
                    value: '${summary.externalHours.toStringAsFixed(1)} h',
                    icon: Icons.public_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:external',
                      title: 'Detalhe de clientes externos',
                      description:
                          'Reservas ativas de clientes externos dentro do periodo consultado.',
                      bookings: _filterReportBookingsByCustomerType(
                        CourtCustomerType.external,
                      ),
                    ),
                  ),
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:partner-coach',
                    label: 'Prof. parceiro',
                    value: '${summary.partnerCoachHours.toStringAsFixed(1)} h',
                    icon: Icons.sports_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:partner-coach',
                      title: 'Detalhe de professores parceiros',
                      description:
                          'Reservas ativas de professores parceiros dentro do periodo consultado.',
                      bookings: _filterReportBookingsByCustomerType(
                        CourtCustomerType.partnerCoach,
                      ),
                    ),
                  ),
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:materials',
                    label: 'Materiais',
                    value: _formatCurrency(summary.materialsAmount),
                    icon: Icons.inventory_2_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:materials',
                      title: 'Detalhe de materiais',
                      description:
                          'Reservas ativas com venda de materiais no periodo consultado.',
                      bookings: activeReportBookings.where((
                        CourtBooking booking,
                      ) {
                        return booking.materialsAmount > 0;
                      }).toList(),
                    ),
                  ),
                  _DetailChip(
                    selected: _selectedSummaryDetailKey == 'chip:pending',
                    label: 'Pendente',
                    value: _formatCurrency(summary.pendingAmount),
                    icon: Icons.warning_amber_rounded,
                    onTap: () => _openSummaryDetail(
                      key: 'chip:pending',
                      title: 'Detalhe de pendencias',
                      description:
                          'Reservas ativas com pagamento pendente no periodo consultado.',
                      bookings: activeReportBookings.where((
                        CourtBooking booking,
                      ) {
                        return !booking.paid;
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPartnerCoachBreakdownSection(context, partnerCoachRows),
              const SizedBox(height: 18),
              _buildSummaryBreakdownSection(
                context,
                selectionPrefix: 'customer-type',
                title: 'Resumo por tipo de cliente',
                description:
                    'Distribuicao de reservas, horas e receita conforme o perfil operacional da quadra.',
                items: summary.customerTypeBreakdown,
                detailTitleBuilder: (CourtSummaryBreakdown item) =>
                    'Detalhe de ${item.label}',
                detailDescriptionBuilder: (CourtSummaryBreakdown item) =>
                    'Reservas ativas do tipo ${item.label.toLowerCase()} no periodo consultado.',
                bookingsBuilder: (CourtSummaryBreakdown item) =>
                    _filterReportBookingsByCustomerType(
                      _customerTypeFromBreakdownGroupKey(item.groupKey),
                    ),
              ),
              const SizedBox(height: 18),
              _buildSummaryBreakdownSection(
                context,
                selectionPrefix: 'pricing-period',
                title: 'Resumo por periodo tarifario',
                description:
                    'Comparativo entre operacao diurna e noturna para apoiar regras de preco e ocupacao.',
                items: summary.pricingPeriodBreakdown,
                detailTitleBuilder: (CourtSummaryBreakdown item) =>
                    'Detalhe de ${item.label}',
                detailDescriptionBuilder: (CourtSummaryBreakdown item) =>
                    'Reservas ativas do periodo tarifario ${item.label.toLowerCase()} no periodo consultado.',
                bookingsBuilder: (CourtSummaryBreakdown item) =>
                    _activeReportBookings.where((CourtBooking booking) {
                      return booking.pricingPeriod ==
                          _pricingPeriodFromBreakdownGroupKey(item.groupKey);
                    }).toList(),
              ),
              const SizedBox(height: 18),
              _buildSummaryBreakdownSection(
                context,
                selectionPrefix: 'payment-method',
                title: 'Cobrado por meio de pagamento',
                description:
                    'Valores efetivamente pagos por canal de recebimento no periodo consultado.',
                items: summary.paymentMethodBreakdown,
                hidePendingColumn: true,
                detailTitleBuilder: (CourtSummaryBreakdown item) =>
                    'Detalhe de ${item.label}',
                detailDescriptionBuilder: (CourtSummaryBreakdown item) =>
                    'Reservas pagas por ${item.label.toLowerCase()} no periodo consultado.',
                bookingsBuilder: (CourtSummaryBreakdown item) =>
                    reportBookings.where((CourtBooking booking) {
                      return booking.status == CourtBookingStatus.scheduled &&
                          booking.paid &&
                          booking.paymentMethod ==
                              _paymentMethodFromBreakdownGroupKey(
                                item.groupKey,
                              );
                    }).toList(),
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

  Widget _buildSummaryBreakdownSection(
    BuildContext context, {
    required String selectionPrefix,
    required String title,
    required String description,
    required List<CourtSummaryBreakdown> items,
    required String Function(CourtSummaryBreakdown item) detailTitleBuilder,
    required String Function(CourtSummaryBreakdown item)
    detailDescriptionBuilder,
    required List<CourtBooking> Function(CourtSummaryBreakdown item)
    bookingsBuilder,
    bool hidePendingColumn = false,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: <DataColumn>[
                const DataColumn(label: Text('Segmento')),
                const DataColumn(label: Text('Reservas')),
                const DataColumn(label: Text('Pagas')),
                if (!hidePendingColumn)
                  const DataColumn(label: Text('Pendentes')),
                const DataColumn(label: Text('Horas')),
                const DataColumn(label: Text('Quadra')),
                const DataColumn(label: Text('Materiais')),
                const DataColumn(label: Text('Total')),
              ],
              rows: items.map((CourtSummaryBreakdown item) {
                final String selectionKey = '$selectionPrefix:${item.groupKey}';
                return DataRow(
                  selected: _selectedSummaryDetailKey == selectionKey,
                  onSelectChanged: (_) => _openSummaryDetail(
                    key: selectionKey,
                    title: detailTitleBuilder(item),
                    description: detailDescriptionBuilder(item),
                    bookings: bookingsBuilder(item),
                  ),
                  cells: <DataCell>[
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150),
                        child: Text(item.label),
                      ),
                    ),
                    DataCell(Text('${item.scheduledCount}')),
                    DataCell(Text('${item.paidCount}')),
                    if (!hidePendingColumn)
                      DataCell(Text('${item.pendingCount}')),
                    DataCell(Text('${item.totalHours.toStringAsFixed(1)} h')),
                    DataCell(Text(_formatCurrency(item.courtAmount))),
                    DataCell(Text(_formatCurrency(item.materialsAmount))),
                    DataCell(Text(_formatCurrency(item.totalAmount))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCoachBreakdownSection(
    BuildContext context,
    List<_PartnerCoachSummaryRow> items,
  ) {
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
            'Professores parceiros por nome',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Separacao de uso de quadra, horas e valores por professor parceiro no periodo consultado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Nenhum professor parceiro possui reservas ativas no periodo informado.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                columns: const <DataColumn>[
                  DataColumn(label: Text('Professor')),
                  DataColumn(label: Text('Reservas')),
                  DataColumn(label: Text('Pagas')),
                  DataColumn(label: Text('Pendentes')),
                  DataColumn(label: Text('Horas')),
                  DataColumn(label: Text('Quadra')),
                  DataColumn(label: Text('Materiais')),
                  DataColumn(label: Text('Total')),
                ],
                rows: items.map((_PartnerCoachSummaryRow item) {
                  final String selectionKey = 'partner-coach:${item.name}';
                  final List<CourtBooking> coachBookings = _activeReportBookings
                      .where((CourtBooking booking) {
                        return booking.customerType ==
                                CourtCustomerType.partnerCoach &&
                            booking.customerName.trim().toLowerCase() ==
                                item.name.trim().toLowerCase();
                      })
                      .toList();
                  return DataRow(
                    selected: _selectedSummaryDetailKey == selectionKey,
                    onSelectChanged: (_) => _openSummaryDetail(
                      key: selectionKey,
                      title: 'Detalhe de ${item.name}',
                      description:
                          'Reservas ativas do professor parceiro ${item.name} no periodo consultado.',
                      bookings: coachBookings,
                      partnerCoachReportDetail: _buildPartnerCoachReportDetail(
                        summary: item,
                        bookings: coachBookings,
                      ),
                    ),
                    cells: <DataCell>[
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 180),
                          child: Text(item.name),
                        ),
                      ),
                      DataCell(Text('${item.scheduledCount}')),
                      DataCell(Text('${item.paidCount}')),
                      DataCell(Text('${item.pendingCount}')),
                      DataCell(Text('${item.totalHours.toStringAsFixed(1)} h')),
                      DataCell(Text(_formatCurrency(item.courtAmount))),
                      DataCell(Text(_formatCurrency(item.materialsAmount))),
                      DataCell(Text(_formatCurrency(item.totalAmount))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<_PartnerCoachSummaryRow> _buildPartnerCoachSummaryRows() {
    final Map<String, _PartnerCoachSummaryAccumulator> rowsByName =
        <String, _PartnerCoachSummaryAccumulator>{};
    for (final CourtBooking booking in _summaryBookings) {
      if (booking.customerType != CourtCustomerType.partnerCoach ||
          booking.status != CourtBookingStatus.scheduled ||
          !_isWithinReportPeriod(booking.bookingDate)) {
        continue;
      }
      final String key = booking.customerName.trim().isEmpty
          ? 'Professor sem nome'
          : booking.customerName.trim();
      final _PartnerCoachSummaryAccumulator accumulator = rowsByName
          .putIfAbsent(key, () => _PartnerCoachSummaryAccumulator(name: key));
      accumulator
        ..scheduledCount += 1
        ..paidCount += booking.paid ? 1 : 0
        ..pendingCount += booking.paid ? 0 : 1
        ..totalHours += booking.durationHours
        ..courtAmount += booking.courtAmount
        ..materialsAmount += booking.materialsAmount
        ..totalAmount += booking.totalAmount;
    }
    final List<_PartnerCoachSummaryRow> rows =
        rowsByName.values
            .map((_PartnerCoachSummaryAccumulator item) => item.build())
            .toList()
          ..sort(
            (_PartnerCoachSummaryRow a, _PartnerCoachSummaryRow b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return rows;
  }

  bool _isWithinReportPeriod(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(_reportStartDate) &&
        !normalized.isAfter(_reportEndDate);
  }

  List<CourtBooking> get _reportBookings {
    final List<CourtBooking> items = _summaryBookings.where((
      CourtBooking booking,
    ) {
      return _isWithinReportPeriod(booking.bookingDate);
    }).toList()..sort(_compareBookingsByDateTime);
    return items;
  }

  List<CourtBooking> get _activeReportBookings {
    return _reportBookings.where((CourtBooking booking) {
      return booking.status == CourtBookingStatus.scheduled;
    }).toList();
  }

  List<CourtBooking> _filterReportBookingsByCustomerType(
    CourtCustomerType type,
  ) {
    return _activeReportBookings.where((CourtBooking booking) {
      return booking.customerType == type;
    }).toList();
  }

  PartnerCoachReportDetail _buildPartnerCoachReportDetail({
    required _PartnerCoachSummaryRow summary,
    required List<CourtBooking> bookings,
  }) {
    return PartnerCoachReportDetail(
      coachName: summary.name,
      summary: PartnerCoachReportSummary(
        scheduledCount: summary.scheduledCount,
        paidCount: summary.paidCount,
        pendingCount: summary.pendingCount,
        totalHours: summary.totalHours,
        courtAmount: summary.courtAmount,
        materialsAmount: summary.materialsAmount,
        totalAmount: summary.totalAmount,
      ),
      bookings: bookings,
    );
  }

  Future<void> _openSummaryDetail({
    required String key,
    required String title,
    required String description,
    required List<CourtBooking> bookings,
    PartnerCoachReportDetail? partnerCoachReportDetail,
  }) async {
    final List<CourtBooking> normalized = <CourtBooking>[...bookings]
      ..sort(_compareBookingsByDateTime);
    setState(() {
      _selectedSummaryDetailKey = key;
    });
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        bool exporting = false;
        String? exportingAction;
        final double totalHours = normalized.fold<double>(
          0,
          (double total, CourtBooking booking) => total + booking.durationHours,
        );
        final double totalAmount = normalized.fold<double>(
          0,
          (double total, CourtBooking booking) => total + booking.totalAmount,
        );

        Future<void> runExport(
          String action,
          Future<void> Function() task,
          StateSetter setDialogState,
        ) async {
          setDialogState(() {
            exporting = true;
            exportingAction = action;
          });
          try {
            await task();
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
                            label: 'Reservas',
                            value: '${normalized.length}',
                            icon: Icons.event_note_rounded,
                          ),
                          _DetailChip(
                            label: 'Horas',
                            value: '${totalHours.toStringAsFixed(1)} h',
                            icon: Icons.query_builder_rounded,
                          ),
                          _DetailChip(
                            label: 'Total',
                            value: _formatCurrency(totalAmount),
                            icon: Icons.payments_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (normalized.isEmpty)
                        const Text(
                          'Nenhuma reserva encontrada para este detalhe.',
                        )
                      else
                        ...normalized.map(
                          (CourtBooking booking) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CourtBookingTile(
                              booking: booking,
                              sharing: _sharingBookingId == booking.id,
                              onHistory: () => _openBookingHistory(booking),
                              loadingHistory:
                                  _loadingHistoryBookingId == booking.id,
                              onShare: () => _shareBookingReceipt(booking),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                if (partnerCoachReportDetail != null)
                  OutlinedButton.icon(
                    onPressed: exporting
                        ? null
                        : () => runExport(
                            'download',
                            () => _downloadPartnerCoachReportPdf(
                              partnerCoachReportDetail,
                            ),
                            setDialogState,
                          ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      exportingAction == 'download'
                          ? 'Gerando PDF...'
                          : 'Baixar PDF',
                    ),
                  ),
                if (partnerCoachReportDetail != null)
                  FilledButton.icon(
                    onPressed: exporting
                        ? null
                        : () => runExport(
                            'share',
                            () => _sharePartnerCoachReportPdf(
                              partnerCoachReportDetail,
                            ),
                            setDialogState,
                          ),
                    icon: const Icon(Icons.share_rounded),
                    label: Text(
                      exportingAction == 'share'
                          ? 'Preparando...'
                          : 'Compartilhar PDF',
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
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSummaryDetailKey = null;
    });
  }

  Future<void> _downloadPartnerCoachReportPdf(
    PartnerCoachReportDetail detail,
  ) async {
    try {
      final FileSaveResult? result = await _partnerCoachReportPdfExporter
          .savePdf(
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
        message:
            'Nao foi possivel salvar o resumo do professor parceiro: $error',
      );
    }
  }

  Future<void> _sharePartnerCoachReportPdf(
    PartnerCoachReportDetail detail,
  ) async {
    try {
      final File file = await _partnerCoachReportPdfExporter.createTemporaryPdf(
        detail: detail,
        startDate: _reportStartDate,
        endDate: _reportEndDate,
      );
      if (!mounted) {
        return;
      }
      await AppShare.shareFiles(
        context,
        filePaths: <String>[file.path],
        subject: 'Resumo de quadras - ${detail.coachName}',
        text: _partnerCoachReportShareText(detail),
        failureTitle: 'Falha ao compartilhar PDF',
        failureMessagePrefix:
            'Nao foi possivel compartilhar o resumo do professor parceiro',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao gerar PDF',
        message:
            'Nao foi possivel preparar o resumo do professor parceiro: $error',
      );
    }
  }

  String _partnerCoachReportShareText(PartnerCoachReportDetail detail) {
    return 'Resumo de reservas de ${detail.coachName}\n'
        'Periodo: ${_formatShortDate(_reportStartDate)} a ${_formatShortDate(_reportEndDate)}\n'
        'Reservas: ${detail.summary.scheduledCount}\n'
        'Pagas: ${detail.summary.paidCount}\n'
        'Pendentes: ${detail.summary.pendingCount}\n'
        'Total: ${_formatCurrency(detail.summary.totalAmount)}';
  }

  List<_CalendarCell> _buildCalendarCells() {
    final DateTime firstDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final DateTime lastDay = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    );
    final int leadingEmpty = firstDay.weekday - 1;
    final List<_CalendarCell> cells = <_CalendarCell>[
      for (int i = 0; i < leadingEmpty; i++) const _CalendarCell.empty(),
    ];
    for (int day = 1; day <= lastDay.day; day++) {
      cells.add(
        _CalendarCell(
          date: DateTime(_selectedDate.year, _selectedDate.month, day),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const _CalendarCell.empty());
    }
    return cells;
  }

  List<CourtBooking> _bookingsForDate(DateTime date) {
    return _monthBookings
        .where((CourtBooking item) => _sameDay(item.bookingDate, date))
        .toList()
      ..sort(
        (CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime),
      );
  }

  double _agendaCellHeight() {
    return 69;
  }

  Future<void> _openCreateDialog() async {
    final _CourtBookingFormResult? result =
        await showDialog<_CourtBookingFormResult>(
          context: context,
          builder: (BuildContext context) =>
              _CourtBookingDialog(service: widget.courtAppService),
        );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (_isBeforeToday(result.bookingDate)) {
      await AppAlerts.warning(
        context,
        title: 'Data invalida',
        message: 'Nao e permitido lancar reservas em datas anteriores a hoje.',
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.createBooking(result.toCreateModel());
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Reserva salva',
        message: result.occurrenceCount > 1
            ? 'Foram registradas ${result.occurrenceCount} reservas recorrentes com sucesso.'
            : 'A reserva da quadra foi registrada com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.toString().replaceFirst('Bad state: ', '');
      if (_isCourtBookingOverlapMessage(message)) {
        await AppAlerts.warning(
          context,
          title: 'Horario ocupado',
          message: 'Ja existe uma reserva ativa para esse horario da quadra.',
        );
      } else {
        await AppAlerts.error(
          context,
          title: 'Falha ao salvar reserva',
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openEditDialog({CourtBooking? booking}) async {
    final CourtBooking? selected =
        booking ??
        await _pickBooking(
          'Selecione a reserva para editar',
          canSelect: _isBookingEditable,
          emptyMessage: 'Nao ha reservas ativas para editar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final _CourtBookingFormResult? result =
        await showDialog<_CourtBookingFormResult>(
          context: context,
          builder: (BuildContext context) => _CourtBookingDialog(
            service: widget.courtAppService,
            initialBooking: selected,
          ),
        );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.updateBooking(
        selected.id,
        result.toUpdateModel(),
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Reserva atualizada',
        message: 'A reserva da quadra foi atualizada com sucesso.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.toString().replaceFirst('Bad state: ', '');
      if (_isCourtBookingOverlapMessage(message)) {
        await AppAlerts.warning(
          context,
          title: 'Horario ocupado',
          message:
              'Ja existe uma reserva ativa para esse horario. Ajuste o horario para continuar.',
        );
      } else {
        await AppAlerts.error(
          context,
          title: 'Falha ao editar reserva',
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openPaymentDialog({CourtBooking? booking}) async {
    final CourtBooking? selected =
        booking ??
        await _pickBooking(
          'Selecione a reserva para informar o pagamento',
          canSelect: _canRegisterPayment,
          emptyMessage:
              'Todas as reservas deste dia ja estao pagas ou canceladas.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final _PaymentResult? result = await showDialog<_PaymentResult>(
      context: context,
      builder: (BuildContext context) => _PaymentDialog(booking: selected),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.updatePayment(
        selected.id,
        UpdateCourtPaymentModel(
          paymentMethod: result.method,
          paymentDate: _formatDate(result.date),
          paymentNotes: result.notes,
        ),
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Pago informado',
        message: 'El pago fue registrado correctamente.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao registrar pago',
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

  Future<void> _openShareDialog({CourtBooking? booking}) async {
    final CourtBooking? selected =
        booking ??
        await _pickBooking(
          'Selecione a reserva para compartilhar',
          emptyMessage: 'Nao ha reservas para compartilhar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    await _shareBookingReceipt(selected);
  }

  Future<void> _openCalendarDayActions(DateTime date) async {
    await _setSelectedDate(date);
    if (!mounted || _dayBookings.isEmpty) {
      return;
    }
    final CourtBooking? booking = await _pickBooking(
      'Reservas do dia',
      emptyMessage: 'Nao ha reservas para este dia.',
    );
    if (booking == null || !mounted) {
      return;
    }
    await _openBookingActionDialog(booking);
  }

  Future<void> _openBookingActionDialog(CourtBooking booking) async {
    final _CourtBookingAction? action = await showDialog<_CourtBookingAction>(
      context: context,
      builder: (BuildContext context) {
        return _CourtBookingActionDialog(
          booking: booking,
          sharing: _sharingBookingId == booking.id,
          canEdit: _isBookingEditable(booking),
          canRegisterPayment: _canRegisterPayment(booking),
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _CourtBookingAction.edit:
        await _openEditDialog(booking: booking);
        return;
      case _CourtBookingAction.payment:
        await _openPaymentDialog(booking: booking);
        return;
      case _CourtBookingAction.share:
        await _openShareDialog(booking: booking);
        return;
      case _CourtBookingAction.cancel:
        await _openCancelDialog(booking: booking);
        return;
      case _CourtBookingAction.history:
        await _openBookingHistory(booking);
        return;
    }
  }

  Future<void> _openBookingHistory(CourtBooking booking) async {
    setState(() {
      _loadingHistoryBookingId = booking.id;
      _errorMessage = null;
    });
    try {
      final List<AuditEventModel> history = await widget.courtAppService
          .history(booking.id);
      if (!mounted) {
        return;
      }
      await showAuditTimelineDialog(
        context: context,
        title: 'Historico de ${booking.customerName}',
        events: history,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Historico da reserva',
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

  Future<void> _openCancelDialog({CourtBooking? booking}) async {
    final CourtBooking? selected =
        booking ??
        await _pickBooking(
          'Selecione a reserva para cancelar',
          canSelect: _isBookingEditable,
          emptyMessage: 'Nao ha reservas ativas para cancelar neste dia.',
        );
    if (selected == null || !mounted) {
      return;
    }
    final _CourtBookingCancellationResult? cancellation =
        await showDialog<_CourtBookingCancellationResult>(
          context: context,
          builder: (BuildContext context) =>
              _CancelCourtBookingDialog(booking: selected),
        );
    if (cancellation == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.cancelBooking(
        selected.id,
        CancelCourtBookingModel(
          cancellationNotes: cancellation.notes,
          cancellationScope: cancellation.scope,
        ),
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      await AppAlerts.success(
        context,
        title: 'Reserva cancelada',
        message: cancellation.scope == CourtBookingCancellationScope.series
            ? 'Toda a recorrencia foi cancelada e mantida no historico.'
            : 'A reserva foi cancelada e mantida no historico.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Falha ao cancelar',
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

  Future<void> _openSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _CourtSettingsDialog(service: widget.courtAppService),
    );
    if (mounted) {
      _load();
    }
  }

  Future<CourtBooking?> _pickBooking(
    String title, {
    bool Function(CourtBooking booking)? canSelect,
    String? emptyMessage,
  }) async {
    final List<CourtBooking> items = canSelect == null
        ? _dayBookings
        : _dayBookings.where(canSelect).toList();
    if (items.isEmpty) {
      if (!mounted || emptyMessage == null) {
        return null;
      }
      await AppAlerts.info(context, title: title, message: emptyMessage);
      return null;
    }
    return showDialog<CourtBooking>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: items.isEmpty
                ? const Text('No hay reservas activas para este dia.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final CourtBooking booking = items[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: const Color(0xFFFCFCFB),
                        title: Text(booking.customerName),
                        subtitle: Text(
                          '${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)} · ${booking.customerType.label}',
                        ),
                        onTap: () => Navigator.of(context).pop(booking),
                      );
                    },
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
  }

  bool _isBookingEditable(CourtBooking booking) {
    return booking.status == CourtBookingStatus.scheduled;
  }

  bool _canRegisterPayment(CourtBooking booking) {
    return booking.status == CourtBookingStatus.scheduled && !booking.paid;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Colors.white, Color(0xFFF7FAFF)],
            ),
            border: Border.all(
              color: selected
                  ? CostaNorteBrand.royalBlueDeep
                  : CostaNorteBrand.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: CostaNorteBrand.foam,
                ),
                child: Icon(icon, color: CostaNorteBrand.royalBlueDeep),
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(caption, style: Theme.of(context).textTheme.bodySmall),
              if (onTap != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  selected ? 'Ocultar detalhe' : 'Ver detalhe',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: CostaNorteBrand.royalBlueDeep,
                  ),
                ),
              ],
            ],
          ),
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
              Icon(icon, size: 16, color: CostaNorteBrand.royalBlueDeep),
              const SizedBox(width: 8),
              Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CostaNorteBrand.mist,
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _CourtBookingTile extends StatelessWidget {
  const _CourtBookingTile({
    required this.booking,
    this.onDoubleTap,
    this.onEdit,
    this.onPayment,
    this.onShare,
    this.onCancel,
    this.onHistory,
    this.loadingHistory = false,
    this.sharing = false,
  });

  final CourtBooking booking;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEdit;
  final VoidCallback? onPayment;
  final VoidCallback? onShare;
  final VoidCallback? onCancel;
  final VoidCallback? onHistory;
  final bool loadingHistory;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _statusColor(booking);
    final String detailText = _statusDescription(booking);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onDoubleTap: onDoubleTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CostaNorteBrand.mint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CostaNorteBrand.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.sports_tennis_rounded, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        booking.customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)} | ${booking.customerType.label} | ${booking.durationHours.toStringAsFixed(1)} h${booking.isRecurring ? ' | Recorrente' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
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
                    borderRadius: BorderRadius.circular(999),
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    _statusLabel(booking),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _InfoPill(
                  label: 'Quadra',
                  value: _formatCurrency(booking.courtAmount),
                ),
                _InfoPill(
                  label: 'Materiais',
                  value: _formatCurrency(booking.materialsAmount),
                ),
                _InfoPill(
                  label: 'Total',
                  value: _formatCurrency(booking.totalAmount),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Referencia: ${booking.customerReference}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (booking.materials.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                booking.materials
                    .map<String>(
                      (CourtBookingMaterial item) =>
                          '${item.materialLabel} x${item.quantity}',
                    )
                    .join(' | '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (detailText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(detailText, style: Theme.of(context).textTheme.bodySmall),
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
}

enum _CourtBookingAction { edit, payment, share, cancel, history }

class _CourtBookingActionDialog extends StatelessWidget {
  const _CourtBookingActionDialog({
    required this.booking,
    required this.sharing,
    required this.canEdit,
    required this.canRegisterPayment,
  });

  final CourtBooking booking;
  final bool sharing;
  final bool canEdit;
  final bool canRegisterPayment;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reserva do dia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            booking.customerName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)} · ${booking.customerType.label}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () => Navigator.of(context).pop(_CourtBookingAction.edit)
                    : null,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: canRegisterPayment
                    ? () =>
                          Navigator.of(context).pop(_CourtBookingAction.payment)
                    : null,
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Informar pago'),
              ),
              OutlinedButton.icon(
                onPressed: sharing
                    ? null
                    : () =>
                          Navigator.of(context).pop(_CourtBookingAction.share),
                icon: Icon(
                  sharing ? Icons.hourglass_top_rounded : Icons.send_rounded,
                ),
                label: Text(
                  sharing ? 'Compartilhando...' : 'Compartilhar',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_CourtBookingAction.history),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Historico'),
              ),
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () =>
                          Navigator.of(context).pop(_CourtBookingAction.cancel)
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

class _CourtAgendaDayCard extends StatelessWidget {
  const _CourtAgendaDayCard({
    required this.date,
    required this.bookings,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime date;
  final List<CourtBooking> bookings;
  final bool selected;
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
                  Icons.sports_tennis_rounded,
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
                if (bookings.any(
                  (CourtBooking booking) =>
                      booking.status == CourtBookingStatus.cancelled,
                ))
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
          ],
        ),
      ),
    );
  }
}

class _CalendarCell {
  const _CalendarCell({this.date});

  const _CalendarCell.empty() : date = null;

  final DateTime? date;
}

class _PartnerCoachSummaryRow {
  const _PartnerCoachSummaryRow({
    required this.name,
    required this.scheduledCount,
    required this.paidCount,
    required this.pendingCount,
    required this.totalHours,
    required this.courtAmount,
    required this.materialsAmount,
    required this.totalAmount,
  });

  final String name;
  final int scheduledCount;
  final int paidCount;
  final int pendingCount;
  final double totalHours;
  final double courtAmount;
  final double materialsAmount;
  final double totalAmount;
}

class _PartnerCoachSummaryAccumulator {
  _PartnerCoachSummaryAccumulator({required this.name});

  final String name;
  int scheduledCount = 0;
  int paidCount = 0;
  int pendingCount = 0;
  double totalHours = 0;
  double courtAmount = 0;
  double materialsAmount = 0;
  double totalAmount = 0;

  _PartnerCoachSummaryRow build() {
    return _PartnerCoachSummaryRow(
      name: name,
      scheduledCount: scheduledCount,
      paidCount: paidCount,
      pendingCount: pendingCount,
      totalHours: totalHours,
      courtAmount: courtAmount,
      materialsAmount: materialsAmount,
      totalAmount: totalAmount,
    );
  }
}

class _CourtBookingDialog extends StatefulWidget {
  const _CourtBookingDialog({required this.service, this.initialBooking});

  final CourtAppService service;
  final CourtBooking? initialBooking;

  @override
  State<_CourtBookingDialog> createState() => _CourtBookingDialogState();
}

class _CourtBookingDialogState extends State<_CourtBookingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _referenceController;
  late final TextEditingController _racketsController;
  late final TextEditingController _ballsController;
  CourtCustomerType _customerType = CourtCustomerType.guest;
  List<CourtPartnerCoach> _partnerCoaches = const <CourtPartnerCoach>[];
  bool _loadingPartnerCoaches = true;
  String? _partnerCoachLoadError;
  String? _selectedPartnerCoachName;
  String _manualCustomerName = '';
  bool _paid = false;
  CourtPaymentMethod _paymentMethod = CourtPaymentMethod.pix;
  bool _recurring = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _bookingDate = DateTime.now();
  DateTime? _recurrenceEndDate;

  @override
  void initState() {
    super.initState();
    final CourtBooking? booking = widget.initialBooking;
    _customerType = booking?.customerType ?? CourtCustomerType.guest;
    _manualCustomerName = booking?.customerName ?? '';
    _selectedPartnerCoachName = _customerType == CourtCustomerType.partnerCoach
        ? booking?.customerName
        : null;
    _paid = booking?.paid ?? false;
    _paymentMethod = booking?.paymentMethod ?? CourtPaymentMethod.pix;
    _recurring = false;
    _startTime = booking == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : _parseTimeOfDay(booking.startTime.substring(0, 5));
    _endTime = booking == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : _parseTimeOfDay(booking.endTime.substring(0, 5));
    _bookingDate = booking?.bookingDate ?? DateTime.now();
    _recurrenceEndDate = booking?.recurrenceEndDate;
    final int rackets = booking == null
        ? 0
        : booking.materials
              .firstWhere(
                (CourtBookingMaterial item) =>
                    item.materialCode == CourtMaterialCode.racket,
                orElse: () => const CourtBookingMaterial(
                  materialCode: CourtMaterialCode.racket,
                  materialLabel: '',
                  quantity: 0,
                  unitPrice: 0,
                  totalPrice: 0,
                ),
              )
              .quantity;
    final int balls = booking == null
        ? 0
        : booking.materials
              .firstWhere(
                (CourtBookingMaterial item) =>
                    item.materialCode == CourtMaterialCode.ball,
                orElse: () => const CourtBookingMaterial(
                  materialCode: CourtMaterialCode.ball,
                  materialLabel: '',
                  quantity: 0,
                  unitPrice: 0,
                  totalPrice: 0,
                ),
              )
              .quantity;
    _nameController = TextEditingController(text: booking?.customerName ?? '');
    _referenceController = TextEditingController(
      text: booking?.customerReference ?? '',
    );
    _racketsController = TextEditingController(text: '$rackets');
    _ballsController = TextEditingController(text: '$balls');
    if (booking == null) {
      _syncEndTimeWithStart();
    }
    _loadPartnerCoaches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    _racketsController.dispose();
    _ballsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialBooking == null
            ? 'Nova reserva de quadra'
            : 'Editar reserva de quadra',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<CourtCustomerType>(
                  value: _customerType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de usuario',
                  ),
                  items: CourtCustomerType.values.map((CourtCustomerType item) {
                    return DropdownMenuItem<CourtCustomerType>(
                      value: item,
                      child: Text(item.label),
                    );
                  }).toList(),
                  onChanged: (CourtCustomerType? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _handleCustomerTypeChanged(value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_customerType == CourtCustomerType.partnerCoach)
                  _buildPartnerCoachField()
                else
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    onChanged: (String value) {
                      _manualCustomerName = value;
                    },
                    validator: (String? value) =>
                        value == null || value.trim().isEmpty
                        ? 'Informe o nome'
                        : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Hospede / unidade',
                    helperText:
                        'Use apartamento, quarto, nome do hospede ou outra referencia operacional.',
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                      ? 'Informe el hospede o la unidad'
                      : null,
                ),
                const SizedBox(height: 12),
                if (widget.initialBooking == null &&
                    _customerType ==
                        CourtCustomerType.partnerCoach) ...<Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _recurring,
                    onChanged: (bool value) {
                      setState(() {
                        _recurring = value;
                        _recurrenceEndDate ??= _bookingDate;
                      });
                    },
                    title: const Text('Reserva recorrente semanal'),
                    subtitle: const Text(
                      'Repete a reserva toda semana no mesmo dia e horario.',
                    ),
                  ),
                  if (_recurring) ...<Widget>[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickRecurrenceEndDate,
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: Text(
                        'Repetir ate ${_formatShortDate(_recurrenceEndDate ?? _bookingDate)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(
                          'Fecha: ${_formatBookingDateWithWeekday(_bookingDate)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _formatTimeOfDay(_startTime),
                        decoration: const InputDecoration(
                          labelText: 'Inicio',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        items: _availableStartSlots
                            .map(
                              (String slot) => DropdownMenuItem<String>(
                                value: slot,
                                child: Text(slot),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _startTime = _parseTimeOfDay(value);
                            _syncEndTimeWithStart();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedEndSlotValue,
                  decoration: const InputDecoration(
                    labelText: 'Fin',
                    prefixIcon: Icon(Icons.east_rounded),
                  ),
                  items: _availableEndSlots
                      .map(
                        (String slot) => DropdownMenuItem<String>(
                          value: slot,
                          child: Text(slot),
                        ),
                      )
                      .toList(),
                  onChanged: _availableEndSlots.isEmpty
                      ? null
                      : (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _endTime = _parseTimeOfDay(value);
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _availableEndSlots.isEmpty
                      ? 'La ultima franja disponible no admite una hora final posterior. Selecciona un inicio anterior.'
                      : 'Por defecto la reserva dura 1 hora, pero puedes extender el horario final.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _racketsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Raquetas',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ballsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pelotas'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('Pagado')),
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
                if (_paid)
                  DropdownButtonFormField<CourtPaymentMethod>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Modalidad de pago',
                    ),
                    items: CourtPaymentMethod.values.map((
                      CourtPaymentMethod item,
                    ) {
                      return DropdownMenuItem<CourtPaymentMethod>(
                        value: item,
                        child: Text(item.label),
                      );
                    }).toList(),
                    onChanged: (CourtPaymentMethod? value) {
                      if (value != null) {
                        setState(() {
                          _paymentMethod = value;
                        });
                      }
                    },
                  ),
              ],
            ),
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
            if (_availableEndSlots.isEmpty) {
              AppAlerts.error(
                context,
                title: 'Horario invalido',
                message:
                    'Selecione um horario de inicio que tenha pelo menos um horario de termino disponivel.',
              );
              return;
            }
            if (_customerType == CourtCustomerType.partnerCoach &&
                _nameController.text.trim().isEmpty) {
              AppAlerts.error(
                context,
                title: 'Professor parceiro',
                message:
                    'Nao foi possivel carregar a lista de professores parceiros ativos.',
              );
              return;
            }
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _CourtBookingFormResult(
                bookingDate: _bookingDate,
                startTime: _startTime,
                endTime: _endTime,
                customerName: _nameController.text.trim(),
                customerReference: _referenceController.text.trim(),
                customerType: _customerType,
                paid: _paid,
                paymentMethod: _paid ? _paymentMethod : null,
                recurrenceEndDate: _recurring
                    ? _formatDate(_recurrenceEndDate ?? _bookingDate)
                    : null,
                rackets: int.tryParse(_racketsController.text) ?? 0,
                balls: int.tryParse(_ballsController.text) ?? 0,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime today = _todayDate();
    final bool editing = widget.initialBooking != null;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: editing ? DateTime(today.year - 1, 1, 1) : today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      selectableDayPredicate: editing
          ? null
          : (DateTime day) => !_isBeforeToday(day),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _bookingDate = picked;
      if (_recurrenceEndDate != null &&
          _recurrenceEndDate!.isBefore(_bookingDate)) {
        _recurrenceEndDate = _bookingDate;
      }
    });
  }

  void _setPaidValue(bool value) {
    setState(() {
      _paid = value;
    });
  }

  Future<void> _pickRecurrenceEndDate() async {
    final DateTime initialDate = _recurrenceEndDate ?? _bookingDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(_bookingDate)
          ? _bookingDate
          : initialDate,
      firstDate: _bookingDate,
      lastDate: DateTime(_bookingDate.year + 1, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _recurrenceEndDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  List<String> get _availableEndSlots {
    final int startMinutes = _timeOfDayToMinutes(_startTime);
    return _courtTimeSlots.where((String slot) {
      return _timeOfDayToMinutes(_parseTimeOfDay(slot)) > startMinutes;
    }).toList();
  }

  List<String> get _availableStartSlots {
    final String selectedStartLabel = _formatTimeOfDay(_startTime);
    final List<String> slots = <String>[];
    for (int index = 0; index < _courtTimeSlots.length; index += 1) {
      final String slot = _courtTimeSlots[index];
      final bool hasLaterSlot = index < _courtTimeSlots.length - 1;
      if (hasLaterSlot || slot == selectedStartLabel) {
        slots.add(slot);
      }
    }
    return slots;
  }

  String? get _selectedEndSlotValue {
    final String endLabel = _formatTimeOfDay(_endTime);
    return _availableEndSlots.contains(endLabel) ? endLabel : null;
  }

  Widget _buildPartnerCoachField() {
    if (_loadingPartnerCoaches) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Nome'),
        child: SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_partnerCoachLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            enabled: false,
            decoration: const InputDecoration(labelText: 'Nome'),
            initialValue: '',
          ),
          const SizedBox(height: 8),
          Text(
            _partnerCoachLoadError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CostaNorteBrand.error),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loadPartnerCoaches,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedPartnerCoachName,
      decoration: const InputDecoration(labelText: 'Nome'),
      items: _partnerCoaches
          .map(
            (CourtPartnerCoach coach) => DropdownMenuItem<String>(
              value: coach.name,
              child: Text(coach.name),
            ),
          )
          .toList(),
      validator: (String? value) => value == null || value.trim().isEmpty
          ? 'Selecione um professor parceiro'
          : null,
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        setState(() {
          _selectedPartnerCoachName = value;
          _nameController.text = value;
        });
      },
    );
  }

  Future<void> _loadPartnerCoaches() async {
    setState(() {
      _loadingPartnerCoaches = true;
      _partnerCoachLoadError = null;
    });
    try {
      final List<CourtPartnerCoach> coaches = await widget.service
          .listPartnerCoaches();
      if (!mounted) {
        return;
      }
      setState(() {
        _partnerCoaches = coaches;
        if (_partnerCoaches.isEmpty) {
          _selectedPartnerCoachName = null;
          if (_customerType == CourtCustomerType.partnerCoach) {
            _nameController.clear();
          }
        } else {
          final bool hasSelectedCoach = _partnerCoaches.any(
            (CourtPartnerCoach coach) =>
                coach.name == _selectedPartnerCoachName,
          );
          if (!hasSelectedCoach) {
            _selectedPartnerCoachName = _partnerCoaches.first.name;
          }
          _selectedPartnerCoachName ??= _partnerCoaches.first.name;
          if (_customerType == CourtCustomerType.partnerCoach) {
            _nameController.text = _selectedPartnerCoachName!;
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _partnerCoachLoadError = error.toString().replaceFirst(
          'Bad state: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPartnerCoaches = false;
        });
      }
    }
  }

  void _handleCustomerTypeChanged(CourtCustomerType value) {
    if (_customerType == value) {
      return;
    }
    if (_customerType != CourtCustomerType.partnerCoach) {
      _manualCustomerName = _nameController.text;
    }
    _customerType = value;
    if (value == CourtCustomerType.partnerCoach) {
      if (_partnerCoaches.isNotEmpty) {
        _selectedPartnerCoachName ??= _partnerCoaches.first.name;
        _nameController.text = _selectedPartnerCoachName!;
      } else {
        _selectedPartnerCoachName = null;
        _nameController.clear();
      }
      _recurrenceEndDate ??= _bookingDate;
      return;
    }
    _recurring = false;
    _recurrenceEndDate = null;
    _nameController.text = _manualCustomerName;
  }

  void _syncEndTimeWithStart() {
    final TimeOfDay defaultEndTime = _addMinutes(_startTime, 60);
    final List<String> availableEndSlots = _availableEndSlots;
    if (availableEndSlots.isEmpty) {
      return;
    }
    final String defaultEndLabel = _formatTimeOfDay(defaultEndTime);
    if (availableEndSlots.contains(defaultEndLabel)) {
      _endTime = defaultEndTime;
      return;
    }
    _endTime = _parseTimeOfDay(availableEndSlots.first);
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
      label: 'Pagado',
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

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.booking});

  final CourtBooking booking;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late CourtPaymentMethod _method;
  late DateTime _date;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _method = widget.booking.paymentMethod ?? CourtPaymentMethod.pix;
    _date = widget.booking.paymentDate ?? DateTime.now();
    _notesController = TextEditingController(
      text: widget.booking.paymentNotes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pago de ${widget.booking.customerName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<CourtPaymentMethod>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Modalidad'),
              items: CourtPaymentMethod.values.map((CourtPaymentMethod item) {
                return DropdownMenuItem<CourtPaymentMethod>(
                  value: item,
                  child: Text(item.label),
                );
              }).toList(),
              onChanged: (CourtPaymentMethod? value) {
                if (value != null) {
                  setState(() {
                    _method = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text('Fecha de pago: ${_formatShortDate(_date)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Observaciones'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _PaymentResult(
                method: _method,
                date: _date,
                notes: _notesController.text.trim(),
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }
}

class _CourtSettingsDialog extends StatefulWidget {
  const _CourtSettingsDialog({required this.service});

  final CourtAppService service;

  @override
  State<_CourtSettingsDialog> createState() => _CourtSettingsDialogState();
}

class _CourtSettingsDialogState extends State<_CourtSettingsDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _historyError;
  String? _historyLoadingKey;
  List<CourtRateSetting> _rates = <CourtRateSetting>[];
  List<CourtMaterialSetting> _materials = <CourtMaterialSetting>[];
  List<CourtPartnerCoach> _partnerCoaches = <CourtPartnerCoach>[];
  final TextEditingController _partnerCoachSearchController =
      TextEditingController();
  String _partnerCoachSearch = '';

  @override
  void dispose() {
    _partnerCoachSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tarifas, materiais e parceiros'),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_historyError != null) ...<Widget>[
                      Text(
                        _historyError!,
                        style: const TextStyle(color: CostaNorteBrand.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Tarifas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ..._rates.map((CourtRateSetting rate) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${rate.customerType.label} · ${rate.pricingPeriod.label}',
                        ),
                        subtitle: Text(_formatCurrency(rate.amount)),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              onPressed: _historyLoadingKey == 'rate:${rate.id}'
                                  ? null
                                  : () => _openRateHistory(rate),
                              icon: Icon(
                                _historyLoadingKey == 'rate:${rate.id}'
                                    ? Icons.hourglass_top_rounded
                                    : Icons.history_rounded,
                              ),
                            ),
                            IconButton(
                              onPressed: _saving ? null : () => _editRate(rate),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Text(
                      'Materiales',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ..._materials.map((CourtMaterialSetting material) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(material.label),
                        subtitle: Text(_formatCurrency(material.unitPrice)),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              onPressed:
                                  _historyLoadingKey ==
                                      'material:${material.id}'
                                  ? null
                                  : () => _openMaterialHistory(material),
                              icon: Icon(
                                _historyLoadingKey == 'material:${material.id}'
                                    ? Icons.hourglass_top_rounded
                                    : Icons.history_rounded,
                              ),
                            ),
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => _editMaterial(material),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Professores parceiros',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _createPartnerCoach,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Novo parceiro'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _partnerCoachSearchController,
                      onChanged: (String value) {
                        setState(() {
                          _partnerCoachSearch = value.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Buscar professor',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_filteredPartnerCoaches.isEmpty)
                      Text(
                        _partnerCoaches.isEmpty
                            ? 'Nenhum professor parceiro cadastrado.'
                            : 'Nenhum professor parceiro encontrado para a busca.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ..._filteredPartnerCoaches.map((CourtPartnerCoach coach) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(coach.name),
                          subtitle: Text(
                            coach.active ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              color: coach.active
                                  ? CostaNorteBrand.success
                                  : CostaNorteBrand.mutedInk,
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: <Widget>[
                              IconButton(
                                onPressed:
                                    _historyLoadingKey == 'coach:${coach.id}'
                                    ? null
                                    : () => _openPartnerCoachHistory(coach),
                                icon: Icon(
                                  _historyLoadingKey == 'coach:${coach.id}'
                                      ? Icons.hourglass_top_rounded
                                      : Icons.history_rounded,
                                ),
                              ),
                              IconButton(
                                onPressed: _saving
                                    ? null
                                    : () => _editPartnerCoach(coach),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                            ],
                          ),
                        );
                      }),
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
  }

  Future<void> _load() async {
    final List<CourtRateSetting> rates = await widget.service.listRates();
    final List<CourtMaterialSetting> materials = await widget.service
        .listMaterials();
    final List<CourtPartnerCoach> partnerCoaches = await widget.service
        .listPartnerCoaches(activeOnly: false);
    if (!mounted) {
      return;
    }
    setState(() {
      _rates = rates;
      _materials = materials;
      _partnerCoaches = partnerCoaches;
      _loading = false;
    });
  }

  List<CourtPartnerCoach> get _filteredPartnerCoaches {
    if (_partnerCoachSearch.isEmpty) {
      return _partnerCoaches;
    }
    return _partnerCoaches.where((CourtPartnerCoach coach) {
      return coach.name.toLowerCase().contains(_partnerCoachSearch);
    }).toList();
  }

  Future<void> _openRateHistory(CourtRateSetting rate) async {
    await _openSettingsHistory(
      loadingKey: 'rate:${rate.id}',
      title: 'Historico de tarifa',
      loader: () => widget.service.rateHistory(rate.id),
    );
  }

  Future<void> _openMaterialHistory(CourtMaterialSetting material) async {
    await _openSettingsHistory(
      loadingKey: 'material:${material.id}',
      title: 'Historico de material',
      loader: () => widget.service.materialHistory(material.id),
    );
  }

  Future<void> _openPartnerCoachHistory(CourtPartnerCoach coach) async {
    await _openSettingsHistory(
      loadingKey: 'coach:${coach.id}',
      title: 'Historico de ${coach.name}',
      loader: () => widget.service.partnerCoachHistory(coach.id),
    );
  }

  Future<void> _openSettingsHistory({
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

  Future<void> _editRate(CourtRateSetting rate) async {
    final TextEditingController controller = TextEditingController(
      text: rate.amount.toStringAsFixed(0),
    );
    bool active = rate.active;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: Text(
                '${rate.customerType.label} · ${rate.pricingPeriod.label}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: active,
                    onChanged: (bool value) {
                      setStateDialog(() {
                        active = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativa'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirm != true) {
      controller.dispose();
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.service.updateRate(
        rate.id,
        UpdateCourtRateSettingModel(
          amount: double.tryParse(controller.text.replaceAll(',', '.')) ?? 0,
          active: active,
        ),
      );
      await _load();
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editMaterial(CourtMaterialSetting material) async {
    final TextEditingController labelController = TextEditingController(
      text: material.label,
    );
    final TextEditingController priceController = TextEditingController(
      text: material.unitPrice.toStringAsFixed(0),
    );
    bool active = material.active;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: Text(material.code.label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: active,
                    onChanged: (bool value) {
                      setStateDialog(() {
                        active = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativo'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirm != true) {
      labelController.dispose();
      priceController.dispose();
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.service.updateMaterial(
        material.id,
        UpdateCourtMaterialSettingModel(
          label: labelController.text.trim(),
          unitPrice:
              double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
          chargeGuest: material.chargeGuest,
          chargeVip: material.chargeVip,
          chargeExternal: material.chargeExternal,
          chargePartnerCoach: material.chargePartnerCoach,
          active: active,
        ),
      );
      await _load();
    } finally {
      labelController.dispose();
      priceController.dispose();
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _createPartnerCoach() async {
    final _PartnerCoachDraft? draft = await showDialog<_PartnerCoachDraft>(
      context: context,
      builder: (BuildContext context) =>
          const _PartnerCoachEditorDialog(title: 'Novo professor parceiro'),
    );
    if (draft == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.service.createPartnerCoach(
        CreateCourtPartnerCoachModel(name: draft.name),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Professor parceiro',
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

  Future<void> _editPartnerCoach(CourtPartnerCoach coach) async {
    final _PartnerCoachDraft? draft = await showDialog<_PartnerCoachDraft>(
      context: context,
      builder: (BuildContext context) => _PartnerCoachEditorDialog(
        title: 'Editar professor parceiro',
        initialName: coach.name,
        initialActive: coach.active,
        showActiveToggle: true,
      ),
    );
    if (draft == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.service.updatePartnerCoach(
        coach.id,
        UpdateCourtPartnerCoachModel(name: draft.name, active: draft.active),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppAlerts.error(
        context,
        title: 'Professor parceiro',
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
}

class _PartnerCoachDraft {
  const _PartnerCoachDraft({required this.name, required this.active});

  final String name;
  final bool active;
}

class _PartnerCoachEditorDialog extends StatefulWidget {
  const _PartnerCoachEditorDialog({
    required this.title,
    this.initialName = '',
    this.initialActive = true,
    this.showActiveToggle = false,
  });

  final String title;
  final String initialName;
  final bool initialActive;
  final bool showActiveToggle;

  @override
  State<_PartnerCoachEditorDialog> createState() =>
      _PartnerCoachEditorDialogState();
}

class _PartnerCoachEditorDialogState extends State<_PartnerCoachEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _active = widget.initialActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do professor',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome';
                  }
                  return null;
                },
              ),
              if (widget.showActiveToggle) ...<Widget>[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (bool value) {
                    setState(() {
                      _active = value;
                    });
                  },
                  title: const Text('Ativo'),
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _PartnerCoachDraft(
                name: _nameController.text.trim(),
                active: _active,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _CourtBookingFormResult {
  const _CourtBookingFormResult({
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.customerName,
    required this.customerReference,
    required this.customerType,
    required this.paid,
    required this.paymentMethod,
    required this.recurrenceEndDate,
    required this.rackets,
    required this.balls,
  });

  final DateTime bookingDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String customerName;
  final String customerReference;
  final CourtCustomerType customerType;
  final bool paid;
  final CourtPaymentMethod? paymentMethod;
  final String? recurrenceEndDate;
  final int rackets;
  final int balls;

  CreateCourtBookingModel toCreateModel() {
    return CreateCourtBookingModel(
      bookingDate: _formatDate(bookingDate),
      startTime: _formatTimeOfDay(startTime),
      endTime: _formatTimeOfDay(endTime),
      customerName: customerName,
      customerReference: customerReference,
      customerType: customerType,
      paid: paid,
      paymentMethod: paymentMethod,
      paymentDate: paid ? _formatDate(DateTime.now()) : null,
      paymentNotes: null,
      recurrenceEndDate: recurrenceEndDate,
      materials: _materials,
    );
  }

  UpdateCourtBookingModel toUpdateModel() {
    return UpdateCourtBookingModel(
      bookingDate: _formatDate(bookingDate),
      startTime: _formatTimeOfDay(startTime),
      endTime: _formatTimeOfDay(endTime),
      customerName: customerName,
      customerReference: customerReference,
      customerType: customerType,
      paid: paid,
      paymentMethod: paymentMethod,
      paymentDate: paid ? _formatDate(DateTime.now()) : null,
      paymentNotes: null,
      recurrenceEndDate: null,
      materials: _materials,
    );
  }

  List<CreateCourtBookingMaterialModel> get _materials =>
      <CreateCourtBookingMaterialModel>[
        if (rackets > 0)
          CreateCourtBookingMaterialModel(
            materialCode: CourtMaterialCode.racket,
            quantity: rackets,
          ),
        if (balls > 0)
          CreateCourtBookingMaterialModel(
            materialCode: CourtMaterialCode.ball,
            quantity: balls,
          ),
      ];

  int get occurrenceCount {
    if (recurrenceEndDate == null) {
      return 1;
    }
    final DateTime endDate = DateTime.parse(recurrenceEndDate!);
    int count = 0;
    DateTime current = DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
    );
    final DateTime normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    while (!current.isAfter(normalizedEnd)) {
      count += 1;
      current = current.add(const Duration(days: 7));
    }
    return count;
  }
}

class _CourtBookingCancellationResult {
  const _CourtBookingCancellationResult({
    required this.notes,
    required this.scope,
  });

  final String notes;
  final CourtBookingCancellationScope scope;
}

class _CancelCourtBookingDialog extends StatefulWidget {
  const _CancelCourtBookingDialog({required this.booking});

  final CourtBooking booking;

  @override
  State<_CancelCourtBookingDialog> createState() =>
      _CancelCourtBookingDialogState();
}

class _CancelCourtBookingDialogState extends State<_CancelCourtBookingDialog> {
  late final TextEditingController _notesController;
  CourtBookingCancellationScope _scope = CourtBookingCancellationScope.single;

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
    return AlertDialog(
      title: const Text('Cancelar reserva'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.booking.isRecurring) ...<Widget>[
              RadioListTile<CourtBookingCancellationScope>(
                contentPadding: EdgeInsets.zero,
                value: CourtBookingCancellationScope.single,
                groupValue: _scope,
                onChanged: (CourtBookingCancellationScope? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _scope = value;
                  });
                },
                title: const Text('Cancelar somente este dia'),
              ),
              RadioListTile<CourtBookingCancellationScope>(
                contentPadding: EdgeInsets.zero,
                value: CourtBookingCancellationScope.series,
                groupValue: _scope,
                onChanged: (CourtBookingCancellationScope? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _scope = value;
                  });
                },
                title: const Text('Cancelar toda a recorrencia'),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Motivo'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CourtBookingCancellationResult(
                notes: _notesController.text.trim(),
                scope: widget.booking.isRecurring
                    ? _scope
                    : CourtBookingCancellationScope.single,
              ),
            );
          },
          child: const Text('Cancelar reserva'),
        ),
      ],
    );
  }
}

class _PaymentResult {
  const _PaymentResult({
    required this.method,
    required this.date,
    required this.notes,
  });

  final CourtPaymentMethod method;
  final DateTime date;
  final String notes;
}

String _statusLabel(CourtBooking booking) {
  if (booking.status == CourtBookingStatus.cancelled) {
    return 'Cancelada';
  }
  return booking.paid ? 'Pago' : 'Pendente';
}

String _statusDescription(CourtBooking booking) {
  if (booking.status == CourtBookingStatus.cancelled) {
    return booking.cancellationNotes == null
        ? 'Reserva cancelada.'
        : 'Cancelada: ${booking.cancellationNotes}';
  }
  if (!booking.paid) {
    if (booking.isRecurring) {
      final String endLabel = booking.recurrenceEndDate == null
          ? ''
          : ' Ate ${_formatShortDate(booking.recurrenceEndDate!)}.';
      return 'Reserva recorrente semanal.$endLabel Pagamento pendente.';
    }
    return 'Pagamento pendente.';
  }
  final String methodLabel =
      booking.paymentMethod?.label ?? 'meio nao informado';
  final String dateLabel = booking.paymentDate == null
      ? 'data nao informada'
      : _formatShortDate(booking.paymentDate!);
  if (booking.isRecurring) {
    final String endLabel = booking.recurrenceEndDate == null
        ? ''
        : ' Ate ${_formatShortDate(booking.recurrenceEndDate!)}.';
    return 'Reserva recorrente semanal.$endLabel Pago em $dateLabel via $methodLabel.';
  }
  return 'Pago em $dateLabel via $methodLabel.';
}

Color _statusColor(CourtBooking booking) {
  if (booking.status == CourtBookingStatus.cancelled) {
    return CostaNorteBrand.error;
  }
  return booking.paid ? CostaNorteBrand.success : CostaNorteBrand.goldDeep;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatCurrency(double amount) {
  return 'R\$ ${amount.toStringAsFixed(0)}';
}

int _compareBookingsByDateTime(CourtBooking a, CourtBooking b) {
  final int dateComparison = a.bookingDate.compareTo(b.bookingDate);
  if (dateComparison != 0) {
    return dateComparison;
  }
  return a.startTime.compareTo(b.startTime);
}

CourtCustomerType _customerTypeFromBreakdownGroupKey(String groupKey) {
  return CourtCustomerType.tryParse(groupKey);
}

CourtPricingPeriod _pricingPeriodFromBreakdownGroupKey(String groupKey) {
  return CourtPricingPeriod.tryParse(groupKey);
}

CourtPaymentMethod? _paymentMethodFromBreakdownGroupKey(String groupKey) {
  return CourtPaymentMethod.tryParse(groupKey);
}

String _formatDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatShortDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatBookingDateWithWeekday(DateTime value) {
  return '${_courtWeekFullLabels[value.weekday - 1]} · ${_formatShortDate(value)}';
}

String _formatReportRangeLabel(DateTime start, DateTime end) {
  if (_sameDay(start, end)) {
    return _formatShortDate(start);
  }
  return '${_formatShortDate(start)} a ${_formatShortDate(end)}';
}

DateTime _todayDate() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isBeforeToday(DateTime value) {
  final DateTime normalized = DateTime(value.year, value.month, value.day);
  return normalized.isBefore(_todayDate());
}

bool _isCourtBookingOverlapMessage(String message) {
  return message ==
          'Ja existe uma reserva ativa para esse horario da quadra.' ||
      message == 'Court booking overlaps with an existing active booking.' ||
      message == 'Ja existe uma reserva ativa para esse horario.';
}

String _formatTimeOfDay(TimeOfDay value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay _parseTimeOfDay(String value) {
  final List<String> parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

TimeOfDay _addMinutes(TimeOfDay value, int minutesToAdd) {
  final int totalMinutes = value.hour * 60 + value.minute + minutesToAdd;
  final int normalizedMinutes = totalMinutes % (24 * 60);
  return TimeOfDay(
    hour: normalizedMinutes ~/ 60,
    minute: normalizedMinutes % 60,
  );
}

int _timeOfDayToMinutes(TimeOfDay value) {
  return value.hour * 60 + value.minute;
}

String _fullDateLabel(DateTime date) {
  return '${_courtWeekLabels[date.weekday - 1]}, ${date.day} de ${_courtMonthLabels[date.month - 1]} de ${date.year}';
}
