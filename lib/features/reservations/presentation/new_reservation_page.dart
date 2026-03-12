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
          'Nueva reserva',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2942),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Alta operativa con validaciones locales y guardado en memoria.',
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
                      labelText: 'Huesped',
                      hintText: 'Nombre y apellido',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese el nombre del huesped.';
                      }
                      if (value.trim().length < 3) {
                        return 'El nombre debe tener al menos 3 caracteres.';
                      }
                      if (value.trim().length > 120) {
                        return 'El nombre no puede superar 120 caracteres.';
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
                          'Fecha: ${_formatDateDisplay(_selectedDate)}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickStartTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Inicio: ${_formatTime(_startTime)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickEndTime,
                        icon: const Icon(Icons.timer_rounded),
                        label: Text('Fin: ${_formatTime(_endTime)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      hintText: 'Detalles del turno',
                    ),
                    minLines: 2,
                    maxLines: 3,
                    validator: (String? value) {
                      if (value != null && value.trim().length > 500) {
                        return 'Las notas no pueden superar 500 caracteres.';
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
                        label: Text(
                          _saving ? 'Guardando...' : 'Guardar reserva',
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _saving ? null : _resetForm,
                        child: const Text('Limpiar'),
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
                  'Contrato JSON aplicado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A3B4C),
                  ),
                ),
                SizedBox(height: 8),
                _FieldHint(
                  label: 'Payload de alta',
                  hint:
                      'guestName, reservationDate(yyyy-MM-dd), startTime, endTime, notes',
                ),
                SizedBox(height: 12),
                _FieldHint(label: 'Estado inicial', hint: 'SCHEDULED'),
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
      helpText: 'Seleccionar fecha de reserva',
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
      helpText: 'Hora de inicio',
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
      helpText: 'Hora de fin',
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

    if (_toMinutes(_startTime) >= _toMinutes(_endTime)) {
      setState(() {
        _error = 'La hora de inicio debe ser menor a la hora de fin.';
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
            'Reserva creada correctamente para ${_guestController.text.trim()}.';
        _error = null;
      });
      _guestController.clear();
      _notesController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _success = null;
        _error = 'No se pudo crear la reserva: $error';
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
