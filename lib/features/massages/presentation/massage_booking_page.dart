import 'package:flutter/material.dart';

import '../../../core/feedback/app_alerts.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/app_dialog_dimensions.dart';
import '../../../core/widgets/app_dialog_shell.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../application/massage_app_service.dart';
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

class MassageBookingPage extends StatefulWidget {
  const MassageBookingPage({required this.massageAppService, super.key});

  final MassageAppService massageAppService;

  @override
  State<MassageBookingPage> createState() => _MassageBookingPageState();
}

class _MassageBookingPageState extends State<MassageBookingPage> {
  final GlobalKey _summaryKey = GlobalKey();

  List<MassageProvider> _providers = <MassageProvider>[];
  List<MassageBooking> _bookings = <MassageBooking>[];
  late int _selectedMonth;
  late DateTime _selectedDate;
  late String _selectedTime;
  bool _loading = true;
  bool _savingBooking = false;
  bool _savingProviders = false;
  int? _processingBookingId;
  String? _errorMessage;

  String _selectedTreatment = _treatmentTypes.first;
  int? _selectedProviderId;
  String _draftAmount = '200';
  bool _paid = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedMonth = _selectedDate.month - 1;
    _selectedProviderId = null;
    _selectedTime = _recommendedTimeFor(_selectedDate);
    _load();
  }

  List<MassageProvider> get _activeProviders =>
      _providers.where((MassageProvider provider) => provider.active).toList()
        ..sort(
          (MassageProvider a, MassageProvider b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

  List<MassageBooking> get _monthBookings =>
      _bookings.where((MassageBooking booking) {
        return booking.startAt.year == _selectedDate.year &&
            booking.startAt.month == _selectedMonth + 1;
      }).toList()..sort(
        (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
      );

  List<MassageBooking> get _dayBookings =>
      _bookings.where((MassageBooking booking) {
        return _sameDay(booking.startAt, _selectedDate);
      }).toList()..sort(
        (MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            eyebrow: 'Bem-estar',
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
                  onPressed: _savingBooking || _dayBookings.isEmpty
                      ? null
                      : _openCancellationPicker,
                  icon: const Icon(Icons.cancel_schedule_send_rounded),
                  label: const Text('Cancelar atendimento'),
                ),
                OutlinedButton.icon(
                  onPressed: _savingProviders ? null : _openProviderDialog,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: Text(_savingProviders ? 'Salvando...' : 'Prestadores'),
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
            _buildDetailPanel(context),
            const SizedBox(height: 18),
            _buildAgendaPanel(context),
            const SizedBox(height: 18),
            _buildSummarySection(context),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final List<MassageProvider> providers = await widget.massageAppService
          .listProviders();
      final List<MassageBooking> bookings = await widget.massageAppService
          .listBookings();
      if (!mounted) {
        return;
      }
      setState(() {
        _providers = providers;
        _bookings = bookings;
        _selectedProviderId =
            _selectedProviderId ??
            (_activeProviders.isEmpty ? null : _activeProviders.first.id);
        _selectedTime = _recommendedTimeFor(_selectedDate);
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

  Widget _buildSummarySection(BuildContext context) {
    return Container(
      key: _summaryKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Resumo do mes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Consolidado do volume, prestadores ativos e receita prevista do mes selecionado.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _buildSummaryStrip(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(BuildContext context) {
    final List<MassageBooking> activeBookings = _monthBookings
        .where(
          (MassageBooking booking) =>
              booking.status == MassageBookingStatus.scheduled,
        )
        .toList();
    final int pendingPayments = activeBookings
        .where((MassageBooking booking) => !booking.paid)
        .length;
    final double totalRevenue = activeBookings.fold<double>(
      0,
      (double total, MassageBooking booking) => total + booking.amount,
    );
    final int cancelledBookings = _monthBookings.length - activeBookings.length;

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: <Widget>[
        _MetricCard(
          title: _monthLabels[_selectedMonth],
          value: '${activeBookings.length} ativos',
          caption: cancelledBookings == 0
              ? 'Volume ativo no mes selecionado'
              : '$cancelledBookings cancelados no historico do mes',
          icon: Icons.calendar_view_month_rounded,
        ),
        _MetricCard(
          title: '${_activeProviders.length} prestadores',
          value: 'Combo abastecido por cadastro',
          caption: 'Somente prestadores ativos aparecem na selecao',
          icon: Icons.groups_2_rounded,
        ),
        _MetricCard(
          title: 'R\$ ${totalRevenue.toStringAsFixed(0)}',
          value: pendingPayments == 0
              ? 'Sem pendencias'
              : '$pendingPayments pendentes',
          caption: 'Receita prevista para o mes',
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _buildAgendaPanel(BuildContext context) {
    final List<DateTime?> cells = _monthCells(
      _selectedDate.year,
      _selectedMonth + 1,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                      setState(() {
                        _selectedMonth = value;
                        _selectedDate = nextDate;
                        _selectedTime = _recommendedTimeFor(nextDate);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          _selectedTime = _recommendedTimeFor(date);
                        });
                      },
                      onDoubleTap: () => _openCalendarDayActions(date),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      processing: _processingBookingId == booking.id,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateBookingDialog() async {
    final _BookingDraft? bookingDraft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) {
        return _BookingDialog(
          title: 'Lancar atendimento',
          submitLabel: 'Salvar atendimento',
          initialDate: _selectedDate,
          activeProviders: _activeProviders,
          initialTime: _selectedTime,
          initialClientName: '',
          initialGuestReference: '',
          initialTreatment: _selectedTreatment,
          initialProviderId: _selectedProviderId,
          initialAmount: _draftAmount,
          initialPaid: _paid,
          initialPaymentMethod: _paid ? MassagePaymentMethod.card : null,
          initialPaymentDate: _paid ? _selectedDate : null,
          initialPaymentNotes: '',
        );
      },
    );

    if (bookingDraft == null) {
      return;
    }

    await _createBooking(bookingDraft);
  }

  Future<void> _openEditBookingDialog(MassageBooking booking) async {
    if (booking.status == MassageBookingStatus.cancelled) {
      await AppAlerts.info(
        context,
        title: 'Atendimento cancelado',
        message: 'Atendimentos cancelados nao podem ser editados.',
      );
      return;
    }

    final _BookingDraft? bookingDraft = await showDialog<_BookingDraft>(
      context: context,
      builder: (BuildContext context) {
        return _BookingDialog(
          title: 'Editar atendimento',
          submitLabel: 'Salvar alteracoes',
          initialDate: booking.bookingDate,
          activeProviders: _activeProviders,
          initialTime: _timeLabel(booking.startAt),
          initialClientName: booking.clientName,
          initialGuestReference: booking.guestReference,
          initialTreatment: booking.treatment,
          initialProviderId: booking.providerId,
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

  Future<void> _openCancellationPicker() async {
    final MassageBooking? booking = await showDialog<MassageBooking>(
      context: context,
      builder: (BuildContext context) {
        return _BookingSelectionDialog(
          title: 'Cancelar atendimento',
          description:
              'Selecione o atendimento do dia para registrar o cancelamento com observacao.',
          bookings: _dayBookings,
          emptyMessage: 'Nao ha atendimentos no dia selecionado.',
          onSelectLabel: 'Cancelar',
        );
      },
    );

    if (booking == null) {
      return;
    }

    await _openCancelBookingDialog(booking);
  }

  Future<void> _openProviderDialog() async {
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

    setState(() {
      _providers = updatedProviders;
      if (_selectedProviderId != null &&
          !_activeProviders.any(
            (MassageProvider provider) => provider.id == _selectedProviderId,
          )) {
        _selectedProviderId = _activeProviders.isEmpty
            ? null
            : _activeProviders.first.id;
      }
      _savingProviders = false;
    });
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
        message: 'Esse prestador ja esta ocupado nesse horario.',
      );
      return;
    }

    setState(() {
      _savingBooking = true;
      _errorMessage = null;
    });

    try {
      final MassageBooking created = await widget.massageAppService
          .createBooking(
            CreateMassageBookingModel(
              bookingDate: _formatDateApi(bookingDraft.date),
              startTime: _formatTimeApi(bookingDraft.time),
              clientName: bookingDraft.clientName,
              guestReference: bookingDraft.guestOrExternal,
              treatment: bookingDraft.treatment,
              amount: bookingDraft.amount,
              providerId: bookingDraft.providerId,
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
        _draftAmount = bookingDraft.amount.toStringAsFixed(0);
        _paid = bookingDraft.paid;
        _selectedTime = _recommendedTimeFor(_selectedDate);
        _savingBooking = false;
      });

      await AppAlerts.success(
        context,
        title: 'Atendimento salvo',
        message: 'Atendimento salvo para ${bookingDraft.clientName}.',
      );
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
        message: 'Esse prestador ja esta ocupado nesse horario.',
      );
      return;
    }

    setState(() {
      _savingBooking = true;
      _processingBookingId = original.id;
      _errorMessage = null;
    });

    try {
      final MassageBooking updated = await widget.massageAppService
          .updateBooking(
            original.id,
            UpdateMassageBookingModel(
              bookingDate: _formatDateApi(bookingDraft.date),
              startTime: _formatTimeApi(bookingDraft.time),
              clientName: bookingDraft.clientName,
              guestReference: bookingDraft.guestOrExternal,
              treatment: bookingDraft.treatment,
              amount: bookingDraft.amount,
              providerId: bookingDraft.providerId,
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
        _draftAmount = bookingDraft.amount.toStringAsFixed(0);
        _paid = bookingDraft.paid;
        _selectedTime = _recommendedTimeFor(_selectedDate);
        _savingBooking = false;
        _processingBookingId = null;
      });

      await AppAlerts.success(
        context,
        title: 'Atendimento atualizado',
        message: 'Atendimento atualizado para ${bookingDraft.clientName}.',
      );
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
        return _BookingActionDialog(booking: booking);
      },
    );

    switch (action) {
      case _BookingAction.edit:
        await _openEditBookingDialog(booking);
      case _BookingAction.cancel:
        await _openCancelBookingDialog(booking);
      case null:
        return;
    }
  }

  Future<void> _openCalendarDayActions(DateTime date) async {
    final List<MassageBooking> bookings = _bookingsFor(date);
    if (bookings.isEmpty) {
      return;
    }

    final MassageBooking? selected = await showDialog<MassageBooking>(
      context: context,
      builder: (BuildContext context) {
        return _BookingSelectionDialog(
          title: 'Atendimentos do dia',
          description:
              'Escolha um atendimento para editar o registro ou cancelar a atencao.',
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
        _selectedTime = _recommendedTimeFor(_selectedDate);
      });
      await AppAlerts.success(
        context,
        title: 'Atendimento cancelado',
        message: 'O cancelamento foi registrado sem remover o historico.',
      );
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

  bool _hasBookingConflict({
    required _BookingDraft bookingDraft,
    required int? ignoredBookingId,
  }) {
    final DateTime startAt = _bookingStartAt(bookingDraft.date, bookingDraft.time);
    return _bookingsFor(bookingDraft.date).any(
      (MassageBooking booking) =>
          booking.status == MassageBookingStatus.scheduled &&
          booking.id != ignoredBookingId &&
          booking.providerId == bookingDraft.providerId &&
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

  String _recommendedTimeFor(DateTime date) {
    final Set<String> occupiedSlots = _bookingsFor(
      date,
    ).where(
      (MassageBooking booking) => booking.status == MassageBookingStatus.scheduled,
    ).map((MassageBooking booking) => _timeLabel(booking.startAt)).toSet();

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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: CostaNorteBrand.royalBlueDeep),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(caption, style: Theme.of(context).textTheme.bodySmall),
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
    required this.processing,
  });

  final MassageBooking booking;
  final String provider;
  final bool processing;

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
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _statusColor(booking),
                ),
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
            '${booking.guestReference} - ${booking.treatment} - $provider - '
            'R\$ ${booking.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (booking.cancellationNotes != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Cancelamento: ${booking.cancellationNotes}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CostaNorteBrand.error,
              ),
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
    required this.guestOrExternal,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final DateTime date;
  final String time;
  final String clientName;
  final String guestOrExternal;
  final String treatment;
  final double amount;
  final int providerId;
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
    required this.activeProviders,
    required this.initialTime,
    required this.initialClientName,
    required this.initialGuestReference,
    required this.initialTreatment,
    required this.initialProviderId,
    required this.initialAmount,
    required this.initialPaid,
    required this.initialPaymentMethod,
    required this.initialPaymentDate,
    required this.initialPaymentNotes,
  });

  final String title;
  final String submitLabel;
  final DateTime initialDate;
  final List<MassageProvider> activeProviders;
  final String initialTime;
  final String initialClientName;
  final String initialGuestReference;
  final String initialTreatment;
  final int? initialProviderId;
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
  late final TextEditingController _guestController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentNotesController;

  late DateTime _selectedDate;
  late String _selectedTime;
  late String _selectedTreatment;
  int? _selectedProviderId;
  late bool _paid;
  MassagePaymentMethod? _paymentMethod;
  DateTime? _paymentDate;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(text: widget.initialClientName);
    _guestController = TextEditingController(
      text: widget.initialGuestReference,
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
    final bool hasInitialProvider = widget.activeProviders.any(
      (MassageProvider provider) => provider.id == widget.initialProviderId,
    );
    _selectedProviderId =
        hasInitialProvider
        ? widget.initialProviderId
        : (widget.activeProviders.isEmpty ? null : widget.activeProviders.first.id);
    _paid = widget.initialPaid;
    _paymentMethod = _paid ? widget.initialPaymentMethod : null;
    _paymentDate = _paid ? (widget.initialPaymentDate ?? _selectedDate) : null;
  }

  @override
  void dispose() {
    _clientController.dispose();
    _guestController.dispose();
    _amountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    DropdownButtonFormField<String>(
                      value: _selectedTime,
                      decoration: const InputDecoration(
                        labelText: 'Horario',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                      items: _timeSlots
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
                    TextFormField(
                      controller: _guestController,
                      decoration: const InputDecoration(
                        labelText: 'Hospede ou externo',
                        prefixIcon: Icon(Icons.hotel_rounded),
                      ),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe origem ou apartamento.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedTreatment,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de massagem',
                        prefixIcon: Icon(Icons.spa_outlined),
                      ),
                      items: _treatmentTypes
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
                      items: widget.activeProviders
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pagamento recebido'),
                      value: _paid,
                      onChanged: (bool value) {
                        setState(() {
                          _paid = value;
                          _paymentMethod = value
                              ? (_paymentMethod ?? MassagePaymentMethod.card)
                              : null;
                          _paymentDate = value
                              ? (_paymentDate ?? _selectedDate)
                              : null;
                        });
                      },
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
    final int? providerId = _selectedProviderId;
    if (amount == null || providerId == null) {
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
        guestOrExternal: _guestController.text.trim(),
        treatment: _selectedTreatment,
        amount: amount,
        providerId: providerId,
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
}

enum _BookingAction { edit, cancel }

class _BookingActionDialog extends StatelessWidget {
  const _BookingActionDialog({required this.booking});

  final MassageBooking booking;

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
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_BookingAction.edit),
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Editar registro'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_BookingAction.cancel),
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Cancelar atencao'),
                  ),
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
                                    '${_timeLabel(booking.startAt)} - ${booking.treatment} - ${booking.providerName}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _statusDescription(booking),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: _statusColor(booking),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop<MassageBooking>(
                                    booking,
                                  ),
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

  late List<MassageProvider> _providers;
  bool _saving = false;

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
            active: provider.active,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: AppDialogDimensions.wideFormWidth,
      maxHeight: 700,
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
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 6,
                  child: ListView.separated(
                    itemCount: _providers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final MassageProvider provider = _providers[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: CostaNorteBrand.line),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    provider.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    provider.specialty,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    provider.contact,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: provider.active,
                              onChanged: _saving
                                  ? null
                                  : (bool value) =>
                                        _toggleProvider(index, value),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
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
                        Text(
                          'Novo prestador',
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
                          decoration: const InputDecoration(
                            labelText: 'Especialidade',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contato',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _addProvider,
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: Text(_saving ? 'Salvando...' : 'Adicionar'),
                        ),
                        const Spacer(),
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
    );
  }

  Future<void> _addProvider() async {
    final String name = _nameController.text.trim();
    final String specialty = _specialtyController.text.trim();
    final String contact = _contactController.text.trim();
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
        _saving = false;
      });

      _nameController.clear();
      _specialtyController.clear();
      _contactController.clear();
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

  Future<void> _toggleProvider(int index, bool active) async {
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
        _providers[index] = updated;
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
  return booking.paid ? 'Atendimento pago' : 'Pagamento pendente';
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
