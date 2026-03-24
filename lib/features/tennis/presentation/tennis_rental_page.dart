import 'package:flutter/material.dart';

import '../../../core/feedback/app_alerts.dart';
import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../../courts/application/court_app_service.dart';
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

class TennisRentalPage extends StatefulWidget {
  const TennisRentalPage({required this.courtAppService, super.key});

  final CourtAppService courtAppService;

  @override
  State<TennisRentalPage> createState() => _TennisRentalPageState();
}

class _TennisRentalPageState extends State<TennisRentalPage> {
  late DateTime _selectedDate;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  List<CourtBooking> _bookings = <CourtBooking>[];
  CourtSummaryReport? _summary;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _load();
  }

  List<CourtBooking> get _monthBookings => _bookings.where((CourtBooking item) {
    return item.bookingDate.year == _selectedDate.year &&
        item.bookingDate.month == _selectedDate.month;
  }).toList()
    ..sort((CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime));

  List<CourtBooking> get _dayBookings => _monthBookings.where((CourtBooking item) {
    return _sameDay(item.bookingDate, _selectedDate);
  }).toList()
    ..sort((CourtBooking a, CourtBooking b) => a.startTime.compareTo(b.startTime));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            eyebrow: 'Operacao ativa',
            title: 'Quadras de tenis',
            description:
                'Reserva operativa de quadras com controle de horas, pagamento, materiais y reglas por tipo de usuario.',
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
                  onPressed: _saving || _dayBookings.isEmpty
                      ? null
                      : _openPaymentDialog,
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Informar pago'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _dayBookings.isEmpty
                      ? null
                      : _openCancelDialog,
                  icon: const Icon(Icons.cancel_schedule_send_rounded),
                  label: const Text('Cancelar reserva'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _openSettingsDialog,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Tarifas y materiales'),
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
            _buildSelectedDayCard(context),
            const SizedBox(height: 18),
            _buildCalendarCard(context),
            const SizedBox(height: 18),
            _buildSummaryCard(context),
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
      final DateTime firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final DateTime lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      final List<CourtBooking> bookings = await widget.courtAppService.listBookings();
      final CourtSummaryReport summary = await widget.courtAppService.getSummaryReport(
        dateFrom: _formatDate(firstDay),
        dateTo: _formatDate(lastDay),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = bookings;
        _summary = summary;
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

  Widget _buildSelectedDayCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Dia selecionado', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(_fullDateLabel(_selectedDate), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (_dayBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CostaNorteBrand.line),
                ),
                child: const Text('Nao ha reservas para este dia.'),
              )
            else
              ..._dayBookings.map((CourtBooking booking) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
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
                              child: Text(
                                booking.customerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: _statusColor(booking).withValues(alpha: 0.14),
                              ),
                              child: Text(
                                _statusLabel(booking),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _statusColor(booking),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)} · ${booking.customerType.label} · ${booking.durationHours.toStringAsFixed(1)} h',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cancha: ${_formatCurrency(booking.courtAmount)} · Materiales: ${_formatCurrency(booking.materialsAmount)} · Total: ${_formatCurrency(booking.totalAmount)}',
                        ),
                        const SizedBox(height: 4),
                        Text('Referencia: ${booking.customerReference}'),
                        if (booking.materials.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            booking.materials
                                .map<String>((CourtBookingMaterial item) => '${item.materialLabel} x${item.quantity}')
                                .join(' · '),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    final List<_CalendarCell> cells = _buildCalendarCells();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Agenda mensal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${_courtMonthLabels[_selectedDate.month - 1]} ${_selectedDate.year}'),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                    });
                    _load();
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 980,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: _courtWeekLabels.map((String label) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 122,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final _CalendarCell cell = cells[index];
                        if (cell.date == null) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFFF7F7F5),
                              border: Border.all(color: CostaNorteBrand.line),
                            ),
                          );
                        }
                        final List<CourtBooking> dayBookings = _monthBookings.where((CourtBooking item) {
                          return _sameDay(item.bookingDate, cell.date!);
                        }).toList();
                        final bool selected = _sameDay(cell.date!, _selectedDate);
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _selectedDate = cell.date!;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: selected ? CostaNorteBrand.foam : Colors.white,
                              border: Border.all(
                                color: selected ? CostaNorteBrand.royalBlue : CostaNorteBrand.line,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('${cell.date!.day}', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                Text(
                                  '${dayBookings.length} reservas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                ...dayBookings.take(2).map((CourtBooking booking) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '${booking.startTime.substring(0, 5)} ${booking.customerName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final CourtSummaryReport? summary = _summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Resumo do mes', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (summary == null)
              const Text('Resumo indisponivel.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _MetricChip(label: 'Ativas', value: '${summary.scheduledCount}'),
                  _MetricChip(label: 'Canceladas', value: '${summary.cancelledCount}'),
                  _MetricChip(label: 'Horas totais', value: summary.totalHours.toStringAsFixed(1)),
                  _MetricChip(label: 'Hospedes', value: summary.guestHours.toStringAsFixed(1)),
                  _MetricChip(label: 'VIP', value: summary.vipHours.toStringAsFixed(1)),
                  _MetricChip(label: 'Externos', value: summary.externalHours.toStringAsFixed(1)),
                  _MetricChip(
                    label: 'Professor parceiro',
                    value: summary.partnerCoachHours.toStringAsFixed(1),
                  ),
                  _MetricChip(label: 'Cobrado', value: _formatCurrency(summary.paidAmount)),
                  _MetricChip(label: 'Pendente', value: _formatCurrency(summary.pendingAmount)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<_CalendarCell> _buildCalendarCells() {
    final DateTime firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final DateTime lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final int leadingEmpty = firstDay.weekday - 1;
    final List<_CalendarCell> cells = <_CalendarCell>[
      for (int i = 0; i < leadingEmpty; i++) const _CalendarCell.empty(),
    ];
    for (int day = 1; day <= lastDay.day; day++) {
      cells.add(_CalendarCell(date: DateTime(_selectedDate.year, _selectedDate.month, day)));
    }
    while (cells.length % 7 != 0) {
      cells.add(const _CalendarCell.empty());
    }
    return cells;
  }

  Future<void> _openCreateDialog() async {
    final _CourtBookingFormResult? result = await showDialog<_CourtBookingFormResult>(
      context: context,
      builder: (BuildContext context) => _CourtBookingDialog(service: widget.courtAppService),
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
        message: 'A reserva da quadra foi registrada com sucesso.',
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

  Future<void> _openPaymentDialog() async {
    final CourtBooking? booking = await _pickBooking('Selecione a reserva para informar o pagamento');
    if (booking == null || !mounted) {
      return;
    }
    final _PaymentResult? result = await showDialog<_PaymentResult>(
      context: context,
      builder: (BuildContext context) => _PaymentDialog(booking: booking),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.updatePayment(
        booking.id,
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

  Future<void> _openCancelDialog() async {
    final CourtBooking? booking = await _pickBooking('Selecione a reserva para cancelar');
    if (booking == null || !mounted) {
      return;
    }
    final TextEditingController notesController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancelar reserva'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Motivo'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancelar reserva'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      notesController.dispose();
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.courtAppService.cancelBooking(
        booking.id,
        CancelCourtBookingModel(cancellationNotes: notesController.text.trim()),
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
        message: 'La reserva fue cancelada y quedó en el histórico.',
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
      notesController.dispose();
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
      builder: (BuildContext context) => _CourtSettingsDialog(service: widget.courtAppService),
    );
    if (mounted) {
      _load();
    }
  }

  Future<CourtBooking?> _pickBooking(String title) async {
    return showDialog<CourtBooking>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: _dayBookings.isEmpty
                ? const Text('No hay reservas activas para este dia.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _dayBookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final CourtBooking booking = _dayBookings[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CalendarCell {
  const _CalendarCell({this.date});

  const _CalendarCell.empty() : date = null;

  final DateTime? date;
}

class _CourtBookingDialog extends StatefulWidget {
  const _CourtBookingDialog({required this.service});

  final CourtAppService service;

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
  bool _paid = false;
  CourtPaymentMethod _paymentMethod = CourtPaymentMethod.pix;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _bookingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _referenceController = TextEditingController();
    _racketsController = TextEditingController(text: '0');
    _ballsController = TextEditingController(text: '0');
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
      title: const Text('Nova reserva de quadra'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty ? 'Informe el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(labelText: 'Referencia'),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty ? 'Informe la referencia' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CourtCustomerType>(
                  value: _customerType,
                  decoration: const InputDecoration(labelText: 'Tipo de usuario'),
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
                      _customerType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text('Fecha: ${_formatShortDate(_bookingDate)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(start: true),
                        child: Text('Inicio: ${_formatTimeOfDay(_startTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(start: false),
                        child: Text('Fin: ${_formatTimeOfDay(_endTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _racketsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Raquetas'),
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
                SwitchListTile(
                  value: _paid,
                  onChanged: (bool value) {
                    setState(() {
                      _paid = value;
                    });
                  },
                  title: const Text('Pagado'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_paid)
                  DropdownButtonFormField<CourtPaymentMethod>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Modalidad de pago'),
                    items: CourtPaymentMethod.values.map((CourtPaymentMethod item) {
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      selectableDayPredicate: (DateTime day) => !_isBeforeToday(day),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _bookingDate = picked;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final TimeOfDay initialValue = start ? _startTime : _endTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialValue,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
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
    _notesController = TextEditingController(text: widget.booking.paymentNotes ?? '');
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
          child: const Text('Guardar'),
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
  List<CourtRateSetting> _rates = <CourtRateSetting>[];
  List<CourtMaterialSetting> _materials = <CourtMaterialSetting>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tarifas y materiales'),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Tarifas', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ..._rates.map((CourtRateSetting rate) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${rate.customerType.label} · ${rate.pricingPeriod.label}'),
                        subtitle: Text(_formatCurrency(rate.amount)),
                        trailing: IconButton(
                          onPressed: _saving ? null : () => _editRate(rate),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Text('Materiales', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ..._materials.map((CourtMaterialSetting material) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(material.label),
                        subtitle: Text(_formatCurrency(material.unitPrice)),
                        trailing: IconButton(
                          onPressed: _saving ? null : () => _editMaterial(material),
                          icon: const Icon(Icons.edit_rounded),
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
    final List<CourtMaterialSetting> materials = await widget.service.listMaterials();
    if (!mounted) {
      return;
    }
    setState(() {
      _rates = rates;
      _materials = materials;
      _loading = false;
    });
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
              title: Text('${rate.customerType.label} · ${rate.pricingPeriod.label}'),
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
    final TextEditingController labelController = TextEditingController(text: material.label);
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
                    decoration: const InputDecoration(labelText: 'Nombre'),
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
          unitPrice: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
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
      materials: <CreateCourtBookingMaterialModel>[
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
  return booking.paid ? 'Pago' : 'Pendiente';
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

DateTime _todayDate() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isBeforeToday(DateTime value) {
  final DateTime normalized = DateTime(value.year, value.month, value.day);
  return normalized.isBefore(_todayDate());
}

bool _isCourtBookingOverlapMessage(String message) {
  return message == 'Ja existe uma reserva ativa para esse horario da quadra.' ||
      message == 'Court booking overlaps with an existing active booking.' ||
      message == 'Ja existe uma reserva ativa para esse horario.';
}

String _formatTimeOfDay(TimeOfDay value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _fullDateLabel(DateTime date) {
  return '${_courtWeekLabels[date.weekday - 1]}, ${date.day} de ${_courtMonthLabels[date.month - 1]} de ${date.year}';
}
