import 'package:flutter/material.dart';

import '../application/reservation_app_service.dart';
import '../domain/create_reservation_model.dart';

class NewReservationPage extends StatefulWidget {
  const NewReservationPage({required this.reservationAppService, super.key});

  final ReservationAppService reservationAppService;

  @override
  State<NewReservationPage> createState() => _NewReservationPageState();
}

class _NewReservationPageState extends State<NewReservationPage> {
  static const int _openingMinutes = 7 * 60;
  static const int _closingMinutes = 23 * 60;
  static const Set<int> _allowedDurationsMinutes = <int>{60, 90, 120};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestController;
  late final TextEditingController _notesController;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _guestController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _guestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Nova reserva',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2942),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cadastre novas reservas de quadra com regras de horário e duração já aplicadas na interface.',
          style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF4E6071)),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _guestController,
                    decoration: const InputDecoration(
                      labelText: 'Responsável',
                      hintText: 'Nome completo',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o responsável pela reserva.';
                      }
                      if (value.trim().length < 3) {
                        return 'O nome deve ter pelo menos 3 caracteres.';
                      }
                      if (value.trim().length > 120) {
                        return 'O nome não pode ultrapassar 120 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(
                          'Data: ${_formatDateDisplay(_selectedDate)}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickStartTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Início: ${_formatTime(_startTime)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickEndTime,
                        icon: const Icon(Icons.timer_rounded),
                        label: Text('Fim: ${_formatTime(_endTime)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      hintText: 'Detalhes da reserva',
                    ),
                    minLines: 2,
                    maxLines: 3,
                    validator: (String? value) {
                      if (value != null && value.trim().length > 500) {
                        return 'As observações não podem ultrapassar 500 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _submitForm,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              )
                            : const Icon(Icons.save_alt_rounded),
                        label: Text(_saving ? 'Salvando...' : 'Salvar reserva'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _saving ? null : _resetForm,
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFF1F0),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF8A1C1C)),
              ),
            ),
          ),
        ],
        if (_success != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFEAF7ED),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _success!,
                style: const TextStyle(color: Color(0xFF1E6B31)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'Orientações rápidas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A3B4C),
                  ),
                ),
                SizedBox(height: 8),
                _FieldHint(
                  label: 'Horário permitido',
                  hint: 'Reservas entre 07:00 e 23:00.',
                ),
                SizedBox(height: 12),
                _FieldHint(label: 'Duração', hint: '60, 90 ou 120 minutos.'),
                SizedBox(height: 12),
                _FieldHint(
                  label: 'Disponibilidade',
                  hint: 'A quadra não pode ter reservas sobrepostas.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Selecionar data da reserva',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Horário de início',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startTime = picked;
    });
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Horário de término',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _endTime = picked;
    });
  }

  Future<void> _submitForm() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int startMinutes = _toMinutes(_startTime);
    final int endMinutes = _toMinutes(_endTime);

    if (startMinutes >= endMinutes) {
      setState(() {
        _error = 'O horário de início deve ser anterior ao horário de término.';
        _success = null;
      });
      return;
    }
    if (startMinutes < _openingMinutes || endMinutes > _closingMinutes) {
      setState(() {
        _error =
            'A reserva deve estar dentro do horário de funcionamento, das 07:00 às 23:00.';
        _success = null;
      });
      return;
    }
    final int durationMinutes = endMinutes - startMinutes;
    if (!_allowedDurationsMinutes.contains(durationMinutes)) {
      setState(() {
        _error = 'A duração da reserva deve ser de 60, 90 ou 120 minutos.';
        _success = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.reservationAppService.create(
        CreateReservationModel(
          guestName: _guestController.text,
          reservationDate: _formatDateApi(_selectedDate),
          startTime: _formatTimeApi(_startTime),
          endTime: _formatTimeApi(_endTime),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _success =
            'Reserva criada com sucesso para ${_guestController.text.trim()}.';
        _error = null;
      });
      _guestController.clear();
      _notesController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String errorMessage = _resolveErrorMessage(error);
      setState(() {
        _saving = false;
        _success = null;
        _error = errorMessage;
      });
    }
  }

  void _resetForm() {
    _guestController.clear();
    _notesController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      _error = null;
      _success = null;
    });
  }

  static int _toMinutes(TimeOfDay value) => (value.hour * 60) + value.minute;

  static String _resolveErrorMessage(Object error) {
    if (error is StateError) {
      final String rawMessage = error.message.toString().trim();
      if (rawMessage.isNotEmpty) {
        return rawMessage;
      }
    }
    return error.toString();
  }

  static String _formatDateApi(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatDateDisplay(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatTime(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatTimeApi(TimeOfDay value) => '${_formatTime(value)}:00';
}

class _FieldHint extends StatelessWidget {
  const _FieldHint({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF425466),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 13, color: Color(0xFF68778B)),
        ),
      ],
    );
  }
}
