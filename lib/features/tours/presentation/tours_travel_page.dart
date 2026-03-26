import 'package:flutter/material.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/feedback/app_alerts.dart';
import '../../../core/sync/auto_refresh_controller.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/brand_section_hero.dart';
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
    this.controller,
    this.onSectionChanged,
    super.key,
  });

  final ToursAppService toursAppService;
  final ToursTravelPageController? controller;
  final ValueChanged<ToursTravelSection>? onSectionChanged;

  @override
  State<ToursTravelPage> createState() => _ToursTravelPageState();
}

class _ToursTravelPageState extends State<ToursTravelPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dayKey = GlobalKey();
  final GlobalKey _agendaKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  late final AutoRefreshController _autoRefreshController;
  List<ToursProvider> _providers = <ToursProvider>[];
  List<ToursBooking> _bookings = <ToursBooking>[];
  List<ToursProviderSummary> _summaries = <ToursProviderSummary>[];
  late DateTime _selectedDate;
  late DateTime _reportStart;
  late DateTime _reportEnd;
  bool _loading = true;
  bool _refreshingData = false;
  bool _saving = false;
  bool _loadingSummary = false;
  String? _error;
  String? _summaryError;
  ToursTravelSection _currentSection = ToursTravelSection.selectedDay;

  List<ToursProvider> get _activeProviders =>
      _providers.where((ToursProvider p) => p.active).toList()..sort(
        (ToursProvider a, ToursProvider b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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
  List<ToursBooking> get _dayBookings => _monthBookings
      .where((ToursBooking b) => _sameDay(b.startAt, _selectedDate))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _scrollController.addListener(_handleScroll);
    _selectedDate = _today();
    _reportStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _reportEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    _autoRefreshController = AutoRefreshController(
      interval: AppRuntimeConfig.operationalRefreshInterval,
      onRefresh: () => _load(showLoading: false),
      canRefresh: _canAutoRefresh,
    );
    _autoRefreshController.start();
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
    _autoRefreshController.dispose();
    widget.controller?._detach(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoRefreshController.handleLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _load(showLoading: false);
    }
  }

  Future<void> _scrollToSection(ToursTravelSection section) async {
    final BuildContext? target = switch (section) {
      ToursTravelSection.selectedDay => _dayKey.currentContext,
      ToursTravelSection.monthlyAgenda => _agendaKey.currentContext,
      ToursTravelSection.summary => _summaryKey.currentContext,
    };
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
    _setCurrentSection(section);
  }

  void _handleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Map<ToursTravelSection, BuildContext?> contexts =
          <ToursTravelSection, BuildContext?>{
            ToursTravelSection.selectedDay: _dayKey.currentContext,
            ToursTravelSection.monthlyAgenda: _agendaKey.currentContext,
            ToursTravelSection.summary: _summaryKey.currentContext,
          };
      const double anchorY = 180;
      ToursTravelSection best = _currentSection;
      double? bestDistance;
      for (final MapEntry<ToursTravelSection, BuildContext?> entry
          in contexts.entries) {
        final RenderObject? renderObject = entry.value?.findRenderObject();
        if (renderObject is! RenderBox) continue;
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

  void _setCurrentSection(ToursTravelSection section) {
    if (_currentSection == section) return;
    _currentSection = section;
    widget.onSectionChanged?.call(section);
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
      final List<ToursProvider> providers = await widget.toursAppService
          .listProviders();
      final List<ToursBooking> bookings = await widget.toursAppService
          .listBookings();
      final List<ToursProviderSummary> summaries = await widget.toursAppService
          .listProviderSummaryReport(
            dateFrom: _formatDate(_reportStart),
            dateTo: _formatDate(_reportEnd),
          );
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _bookings = bookings;
        _summaries = summaries;
        _loading = false;
        _refreshingData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshingData = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
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
    if (!_canRefreshPage) return;
    await _load(showLoading: false);
  }

  Future<void> _reloadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final List<ToursProviderSummary> summaries = await widget.toursAppService
          .listProviderSummaryReport(
            dateFrom: _formatDate(_reportStart),
            dateTo: _formatDate(_reportEnd),
          );
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _loadingSummary = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = error.toString().replaceFirst('Bad state: ', '');
      });
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
            eyebrow: 'Experiencias externas',
            title: 'Tours e viagens',
            description:
                'Agenda operacional para documentar saídas con agências, pagamentos e comissão por fornecedor.',
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
                  onPressed: _saving || _dayBookings.isEmpty
                      ? null
                      : _editBooking,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _dayBookings.isEmpty
                      ? null
                      : _markPayment,
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Informar pago'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _dayBookings.isEmpty
                      ? null
                      : _cancelBooking,
                  icon: const Icon(Icons.cancel_schedule_send_rounded),
                  label: const Text('Cancelar'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _manageProvider,
                  icon: const Icon(Icons.business_rounded),
                  label: const Text('Fornecedores'),
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
            KeyedSubtree(key: _dayKey, child: _buildDayCard(context)),
            const SizedBox(height: 18),
            KeyedSubtree(key: _agendaKey, child: _buildAgendaCard(context)),
            const SizedBox(height: 18),
            KeyedSubtree(key: _summaryKey, child: _buildSummaryCard(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(BuildContext context) {
    final List<ToursBooking> scheduled = _dayBookings
        .where((ToursBooking b) => b.status == ToursBookingStatus.scheduled)
        .toList();
    final double charged = scheduled.fold<double>(
      0,
      (double total, ToursBooking b) => total + b.amount,
    );
    final double commission = scheduled.fold<double>(
      0,
      (double total, ToursBooking b) => total + b.commissionAmount,
    );
    final double paid = scheduled
        .where((ToursBooking b) => b.paid)
        .fold<double>(0, (double total, ToursBooking b) => total + b.amount);
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
                _metric(
                  context,
                  Icons.point_of_sale_rounded,
                  'Cobrado',
                  _money(charged),
                ),
                _metric(
                  context,
                  Icons.account_balance_wallet_rounded,
                  'Comissao',
                  _money(commission),
                ),
                _metric(context, Icons.payments_rounded, 'Pago', _money(paid)),
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
                  child: _bookingTile(context, b),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaCard(BuildContext context) {
    final List<_DayCell> cells = _calendarCells();
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
                      _months.length,
                      (int i) => DropdownMenuItem<int>(
                        value: i,
                        child: Text(_months[i]),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value == null) return;
                      setState(
                        () => _selectedDate = DateTime(
                          _selectedDate.year,
                          value + 1,
                          1,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: _week
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
                final _DayCell cell = cells[index];
                if (!cell.inMonth) return const SizedBox.shrink();
                return _ToursAgendaDayCard(
                  date: cell.date,
                  bookings: cell.bookings,
                  selected: _sameDay(cell.date, _selectedDate),
                  onTap: () => setState(() => _selectedDate = cell.date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final double gross = _summaries.fold<double>(
      0,
      (double total, ToursProviderSummary s) => total + s.grossAmount,
    );
    final double paid = _summaries.fold<double>(
      0,
      (double total, ToursProviderSummary s) => total + s.paidAmount,
    );
    final double commission = _summaries.fold<double>(
      0,
      (double total, ToursProviderSummary s) => total + s.commissionAmount,
    );
    final int count = _summaries.fold<int>(
      0,
      (int total, ToursProviderSummary s) => total + s.scheduledCount,
    );
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
              'Totais por fornecedor, valor cobrado e comissão consolidada.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _pickReportStart,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text('Inicio: ${_short(_reportStart)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickReportEnd,
                  icon: const Icon(Icons.event_rounded),
                  label: Text('Fim: ${_short(_reportEnd)}'),
                ),
                FilledButton.icon(
                  onPressed: _loadingSummary ? null : _reloadSummary,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_loadingSummary ? 'Buscando...' : 'Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_summaryError != null) ...<Widget>[
              Text(
                _summaryError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _metric(
                  context,
                  Icons.event_available_rounded,
                  'Agendamentos',
                  '$count',
                ),
                _metric(
                  context,
                  Icons.attach_money_rounded,
                  'Cobrado',
                  _money(gross),
                ),
                _metric(
                  context,
                  Icons.payments_rounded,
                  'Recebido',
                  _money(paid),
                ),
                _metric(
                  context,
                  Icons.account_balance_wallet_rounded,
                  'Comissao',
                  _money(commission),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_summaries.isEmpty)
              _emptyBox(
                context,
                'Nenhum fornecedor possui tours ou viagens no periodo informado.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Fornecedor')),
                    DataColumn(label: Text('Agendados')),
                    DataColumn(label: Text('Pagos')),
                    DataColumn(label: Text('Pendentes')),
                    DataColumn(label: Text('Cobrado')),
                    DataColumn(label: Text('Recebido')),
                    DataColumn(label: Text('Comissao')),
                  ],
                  rows: _summaries
                      .map(
                        (ToursProviderSummary s) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(s.providerName)),
                            DataCell(Text('${s.scheduledCount}')),
                            DataCell(Text('${s.paidCount}')),
                            DataCell(Text('${s.pendingCount}')),
                            DataCell(Text(_money(s.grossAmount))),
                            DataCell(Text(_money(s.paidAmount))),
                            DataCell(Text(_money(s.commissionAmount))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
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

  Future<void> _editBooking() async {
    final ToursBooking? selected = await _pickBooking(
      'Editar agendamento',
      (ToursBooking b) => b.status == ToursBookingStatus.scheduled,
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
        initialDate: selected.startAt,
        booking: selected,
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

  Future<void> _markPayment() async {
    final ToursBooking? selected = await _pickBooking(
      'Informar pago',
      (ToursBooking b) => b.status == ToursBookingStatus.scheduled && !b.paid,
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

  Future<void> _cancelBooking() async {
    final ToursBooking? selected = await _pickBooking(
      'Cancelar agendamento',
      (ToursBooking b) => b.status == ToursBookingStatus.scheduled,
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

  Future<void> _manageProvider() async {
    final _ProviderDraft? draft = await showDialog<_ProviderDraft>(
      context: context,
      builder: (BuildContext context) => _ProviderDialog(providers: _providers),
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
  }

  Future<void> _persist(Future<Object?> Function() action, String title) async {
    setState(() => _saving = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        await AppAlerts.error(
          context,
          title: title,
          message: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<ToursBooking?> _pickBooking(
    String title,
    bool Function(ToursBooking booking) predicate,
  ) {
    final List<ToursBooking> items = _dayBookings.where(predicate).toList();
    if (items.isEmpty) return Future<ToursBooking?>.value(null);
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

  Future<void> _pickSelectedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1, 1, 1),
      lastDate: DateTime(_selectedDate.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(
        () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
      );
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

  Widget _bookingTile(BuildContext context, ToursBooking b) {
    final Color color = b.status == ToursBookingStatus.cancelled
        ? CostaNorteBrand.error
        : b.paid
        ? CostaNorteBrand.success
        : CostaNorteBrand.goldDeep;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CostaNorteBrand.line),
        color: Colors.white,
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
            '${b.providerName} · ${b.guestReference}',
            style: Theme.of(context).textTheme.bodyMedium,
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
            Text(b.description!, style: Theme.of(context).textTheme.bodyMedium),
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
        ],
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
  });

  final DateTime date;
  final List<ToursBooking> bookings;
  final bool selected;
  final VoidCallback onTap;

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
  });
  final List<ToursProvider> providers;
  final DateTime initialDate;
  final ToursBooking? booking;
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
        booking?.startAt ??
        DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          9,
          0,
        );
    _endAt = booking?.endAt ?? _startAt.add(const Duration(hours: 2));
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
    return AlertDialog(
      title: Text(
        widget.booking == null ? 'Novo agendamento' : 'Editar agendamento',
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<ToursServiceType>(
                  value: _serviceType,
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
                  value: _providerId,
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
                    final ToursProvider provider = widget.providers.firstWhere(
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
                  value: _providerOfferingId,
                  decoration: const InputDecoration(
                    labelText: 'Destino / viagem do fornecedor',
                    prefixIcon: Icon(Icons.place_rounded),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Informar manualmente'),
                    ),
                    ...offerings.map(
                      (ToursProviderOffering item) => DropdownMenuItem<int?>(
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
                          selected.description ?? 'Sem detalhes cadastrados.',
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
                    labelText: 'Referencia / quarto',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                      ? 'Informe a referencia'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickStartAt,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Inicio: ${_dateTime(_startAt)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndAt,
                        icon: const Icon(Icons.timelapse_rounded),
                        label: Text('Fim: ${_dateTime(_endAt)}'),
                      ),
                    ),
                  ],
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
                        validator: (String? value) => (_number(value) ?? -1) < 0
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
                        validator: (String? value) => (_number(value) ?? -1) < 0
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paid,
                  title: const Text('Registrar como pago'),
                  onChanged: (bool value) => setState(() {
                    _paid = value;
                    if (!_paid) _paymentMethod = null;
                  }),
                ),
                if (_paid) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ToursPaymentMethod>(
                    value: _paymentMethod,
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
                    validator: (ToursPaymentMethod? value) =>
                        value == null ? 'Informe a forma de pagamento' : null,
                    onChanged: (ToursPaymentMethod? value) =>
                        setState(() => _paymentMethod = value),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }

  Future<void> _pickStartAt() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(_startAt.year - 1, 1, 1),
      lastDate: DateTime(_startAt.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startAt.hour, minute: _startAt.minute),
    );
    if (time == null) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickEndAt() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: DateTime(_startAt.year - 1, 1, 1),
      lastDate: DateTime(_startAt.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _endAt.hour, minute: _endAt.minute),
    );
    if (time == null) return;
    setState(
      () => _endAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
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

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({required this.providers});
  final List<ToursProvider> providers;
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
  bool _active = true;
  ToursServiceType _offeringServiceType = ToursServiceType.tour;
  bool _offeringActive = true;
  int? _editingOfferingIndex;
  List<_ProviderOfferingDraft> _offerings = <_ProviderOfferingDraft>[];

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<int?>(
                value: _selectedId,
                decoration: const InputDecoration(
                  labelText: 'Fornecedor existente',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Novo fornecedor'),
                  ),
                  ...widget.providers.map(
                    (ToursProvider item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: _loadProvider,
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
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _editOffering(index),
                                child: const Text('Editar'),
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
                value: _offeringServiceType,
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
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
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

  void _loadProvider(int? value) {
    setState(() {
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
              value: _method,
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
