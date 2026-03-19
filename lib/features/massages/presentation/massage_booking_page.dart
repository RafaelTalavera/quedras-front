import 'package:flutter/material.dart';

import '../../../core/theme/costa_norte_brand.dart';
import '../../../core/widgets/brand_section_hero.dart';
import '../domain/massage_models.dart';

class MassageBookingPage extends StatefulWidget {
  const MassageBookingPage({super.key});

  @override
  State<MassageBookingPage> createState() => _MassageBookingPageState();
}

class _MassageBookingPageState extends State<MassageBookingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _guestController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '200',
  );

  late List<MassageProvider> _providers;
  late List<MassageBooking> _bookings;
  late int _selectedMonth;
  late DateTime _selectedDate;

  String _selectedTreatment = MassageCatalog.treatmentTypes.first;
  String _selectedTime = '17:00';
  String? _selectedProviderId;
  bool _paid = true;

  @override
  void initState() {
    super.initState();
    _providers = MassageCatalog.seededProviders();
    _bookings = MassageCatalog.seededBookings();
    _selectedMonth = 2;
    _selectedDate = DateTime(MassageCatalog.agendaYear, 3, 6);
    _selectedProviderId = _activeProviders.isEmpty
        ? null
        : _activeProviders.first.id;
  }

  @override
  void dispose() {
    _clientController.dispose();
    _guestController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<MassageProvider> get _activeProviders =>
      _providers.where((MassageProvider provider) => provider.active).toList()
        ..sort(
          (MassageProvider a, MassageProvider b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

  List<MassageBooking> get _monthBookings =>
      _bookings.where((MassageBooking booking) {
        return booking.startAt.year == MassageCatalog.agendaYear &&
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
    final bool compact = MediaQuery.of(context).size.width < 1180;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BrandSectionHero(
            eyebrow: 'Bem-estar',
            title: 'Agendamento de massagens',
            description:
                'Agenda mensal inspirada na planilha do hotel, com cadastro proprio de prestadores para abastecer o combo do formulario.',
            icon: Icons.spa_rounded,
            photoAlignment: Alignment.centerLeft,
            action: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saveBooking,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Lancar atendimento'),
                ),
                OutlinedButton.icon(
                  onPressed: _openProviderDialog,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: const Text('Prestadores'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSummaryStrip(context),
          const SizedBox(height: 18),
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildAgendaPanel(context),
                    const SizedBox(height: 18),
                    _buildDetailPanel(context),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: _buildAgendaPanel(context)),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: _buildDetailPanel(context)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(BuildContext context) {
    final int pendingPayments = _monthBookings
        .where((MassageBooking booking) => !booking.paid)
        .length;
    final double totalRevenue = _monthBookings.fold<double>(
      0,
      (double total, MassageBooking booking) => total + booking.amount,
    );

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: <Widget>[
        _MetricCard(
          title: MassageCatalog.monthLabels[_selectedMonth],
          value: '${_monthBookings.length} atendimentos',
          caption: 'Volume agendado no mes selecionado',
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
      MassageCatalog.agendaYear,
      _selectedMonth + 1,
    );

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
                        'Agenda mensal',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A grade adapta colunas e altura das celulas conforme o tamanho da janela.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Mes da agenda',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      MassageCatalog.monthLabels.length,
                      (int index) => DropdownMenuItem<int>(
                        value: index,
                        child: Text(MassageCatalog.monthLabels[index]),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedMonth = value;
                        _selectedDate = DateTime(
                          MassageCatalog.agendaYear,
                          value + 1,
                          1,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = _agendaColumnsForWidth(
                  constraints.maxWidth,
                );
                final bool showWeekHeader = columns == 7;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showWeekHeader) ...<Widget>[
                      Row(
                        children: MassageCatalog.weekDayLabels
                            .map(
                              (String label) => Expanded(
                                child: Center(
                                  child: Text(
                                    label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: CostaNorteBrand.mutedInk,
                                        ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: _agendaCellHeight(columns),
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
                            });
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Card(
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
                      child: _BookingTile(
                        booking: booking,
                        provider: _providerName(booking.providerId),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Novo atendimento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O prestador e selecionado a partir do cadastro da janela de prestadores.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                    items: MassageCatalog.treatmentTypes
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
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedProviderId,
                    decoration: const InputDecoration(
                      labelText: 'Prestador',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                    items: _activeProviders
                        .map(
                          (MassageProvider provider) =>
                              DropdownMenuItem<String>(
                                value: provider.id,
                                child: Text(
                                  '${provider.name} - ${provider.specialty}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        )
                        .toList(),
                    validator: (String? value) => value == null || value.isEmpty
                        ? 'Cadastre ou selecione um prestador.'
                        : null,
                    onChanged: (String? value) {
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
                      final double? amount = _parseAmount(value);
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
                      });
                    },
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _saveBooking,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar atendimento'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openProviderDialog,
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Cadastrar prestador'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveBooking() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double? amount = _parseAmount(_amountController.text);
    final String? providerId = _selectedProviderId;
    if (amount == null || providerId == null) {
      return;
    }

    final List<String> parts = _selectedTime.split(':');
    final DateTime startAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final bool duplicated = _dayBookings.any(
      (MassageBooking booking) =>
          booking.providerId == providerId &&
          booking.startAt.hour == startAt.hour &&
          booking.startAt.minute == startAt.minute,
    );
    if (duplicated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esse prestador ja esta ocupado nesse horario.'),
        ),
      );
      return;
    }

    setState(() {
      _bookings = <MassageBooking>[
        ..._bookings,
        MassageBooking(
          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
          startAt: startAt,
          clientName: _clientController.text.trim(),
          guestOrExternal: _guestController.text.trim(),
          treatment: _selectedTreatment,
          amount: amount,
          providerId: providerId,
          paid: _paid,
        ),
      ];
    });

    _clientController.clear();
    _guestController.clear();
    _amountController.text = '200';
    setState(() {
      _selectedTreatment = MassageCatalog.treatmentTypes.first;
      _selectedProviderId = _activeProviders.isEmpty
          ? null
          : _activeProviders.first.id;
      _paid = true;
    });
  }

  Future<void> _openProviderDialog() async {
    final List<MassageProvider>? updatedProviders =
        await showDialog<List<MassageProvider>>(
          context: context,
          builder: (BuildContext context) {
            return _ProviderDialog(initialProviders: _providers);
          },
        );

    if (updatedProviders == null) {
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
    });
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

  int _agendaColumnsForWidth(double width) {
    if (width >= 1100) {
      return 7;
    }
    if (width >= 860) {
      return 5;
    }
    if (width >= 620) {
      return 4;
    }
    if (width >= 380) {
      return 2;
    }
    return 1;
  }

  double _agendaCellHeight(int columns) {
    if (columns >= 7) {
      return 150;
    }
    if (columns >= 4) {
      return 138;
    }
    return 126;
  }

  String _selectedDateLabel(DateTime date) {
    return '${_weekdayLabel(date)}, ${date.day} de ${MassageCatalog.monthLabels[date.month - 1]} de ${date.year}';
  }

  String _providerName(String providerId) {
    for (final MassageProvider provider in _providers) {
      if (provider.id == providerId) {
        return provider.name;
      }
    }
    return 'Prestador';
  }

  double? _parseAmount(String? raw) {
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
}

class _AgendaDayCard extends StatelessWidget {
  const _AgendaDayCard({
    required this.date,
    required this.selected,
    required this.bookings,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final List<MassageBooking> bookings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? CostaNorteBrand.goldDeep : CostaNorteBrand.line,
            width: selected ? 1.4 : 1,
          ),
          color: selected ? const Color(0xFFFFF8E7) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${date.day}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (bookings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: CostaNorteBrand.foam,
                    ),
                    child: Text(
                      '${bookings.length}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _weekdayLabel(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: bookings.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Sem atendimentos',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: MassageCatalog.providerColor(
                          bookings.first.providerId,
                        ),
                      ),
                      child: Text(
                        _agendaSummary(bookings),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CostaNorteBrand.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
  const _BookingTile({required this.booking, required this.provider});

  final MassageBooking booking;
  final String provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: MassageCatalog.providerColor(booking.providerId),
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
              Text(
                booking.paid ? 'Pago' : 'Pendente',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: booking.paid
                      ? CostaNorteBrand.success
                      : CostaNorteBrand.goldDeep,
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
            '${booking.guestOrExternal} - ${booking.treatment} - $provider - '
            'R\$ ${booking.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({required this.initialProviders});

  final List<MassageProvider> initialProviders;

  @override
  State<_ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<_ProviderDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  late List<MassageProvider> _providers;

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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  onChanged: (bool value) {
                                    setState(() {
                                      _providers[index] = provider.copyWith(
                                        active: value,
                                      );
                                    });
                                  },
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
                              decoration: const InputDecoration(
                                labelText: 'Nome',
                              ),
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
                              onPressed: _addProvider,
                              icon: const Icon(Icons.playlist_add_rounded),
                              label: const Text('Adicionar'),
                            ),
                            const Spacer(),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                      ).pop<List<MassageProvider>>(_providers);
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
      ),
    );
  }

  void _addProvider() {
    final String name = _nameController.text.trim();
    final String specialty = _specialtyController.text.trim();
    final String contact = _contactController.text.trim();
    if (name.isEmpty || specialty.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete nome, especialidade e contato.'),
        ),
      );
      return;
    }

    final String id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final bool exists = _providers.any(
      (MassageProvider provider) => provider.id == id,
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse prestador ja esta cadastrado.')),
      );
      return;
    }

    setState(() {
      _providers =
          <MassageProvider>[
            ..._providers,
            MassageProvider(
              id: id,
              name: name,
              specialty: specialty,
              contact: contact,
            ),
          ]..sort(
            (MassageProvider a, MassageProvider b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    });

    _nameController.clear();
    _specialtyController.clear();
    _contactController.clear();
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

String _timeLabel(DateTime date) {
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _agendaSummary(List<MassageBooking> bookings) {
  final MassageBooking first = bookings.first;
  if (bookings.length == 1) {
    return '${_timeLabel(first.startAt)} - ${first.clientName}';
  }
  return '${_timeLabel(first.startAt)} - ${first.clientName} +${bookings.length - 1}';
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
