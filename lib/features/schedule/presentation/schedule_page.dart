import 'package:flutter/material.dart';

import '../../reservations/application/reservation_app_service.dart';
import '../../reservations/domain/reservation_model.dart';
import '../../reservations/domain/reservation_status.dart';
import '../../reservations/domain/update_reservation_model.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({required this.reservationAppService, super.key});

  final ReservationAppService reservationAppService;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _selectedDate;
  bool _loading = false;
  String? _error;
  int? _processingReservationId;
  List<ReservationModel> _reservations = const <ReservationModel>[];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Agenda de cancha',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2942),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vista diaria con estado de turnos y recarga manual.',
          style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF4E6071)),
        ),
        const SizedBox(height: 20),
        _FiltersHeader(
          selectedDateLabel: _formatDateDisplay(_selectedDate),
          loading: _loading,
          onPickDate: _pickDate,
          onRefresh: _loadReservations,
        ),
        const SizedBox(height: 14),
        if (_loading)
          const _LoadingCard()
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _loadReservations)
        else if (_reservations.isEmpty)
          const _EmptyCard()
        else
          Column(
            children: _reservations
                .map(
                  (ReservationModel reservation) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReservationTile(
                      reservation: reservation,
                      processing: _processingReservationId == reservation.id,
                      onEdit: reservation.status == ReservationStatus.scheduled
                          ? () => _openEditReservation(reservation)
                          : null,
                      onCancel:
                          reservation.status == ReservationStatus.scheduled
                          ? () => _cancelReservation(reservation)
                          : null,
                    ),
                  ),
                )
                .toList(),
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
      helpText: 'Seleccionar fecha de agenda',
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
    await _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<ReservationModel> items = await widget.reservationAppService
          .listByDate(_formatDateApi(_selectedDate));
      if (!mounted) {
        return;
      }
      setState(() {
        _reservations = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No fue posible cargar la agenda: $error';
        _loading = false;
      });
    }
  }

  Future<void> _openEditReservation(ReservationModel reservation) async {
    final int? reservationId = reservation.id;
    if (reservationId == null) {
      return;
    }

    final _EditReservationDraft? draft =
        await showDialog<_EditReservationDraft>(
          context: context,
          builder: (BuildContext dialogContext) {
            return _EditReservationDialog(reservation: reservation);
          },
        );
    if (draft == null) {
      return;
    }

    setState(() {
      _processingReservationId = reservationId;
      _error = null;
    });

    try {
      await widget.reservationAppService.update(
        reservationId,
        UpdateReservationModel(
          guestName: draft.guestName,
          reservationDate: _formatDateApi(draft.reservationDate),
          startTime: _formatTimeApi(draft.startTime),
          endTime: _formatTimeApi(draft.endTime),
          notes: draft.notes,
        ),
      );
      await _loadReservations();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva actualizada correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _resolveErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingReservationId = null;
        });
      }
    }
  }

  Future<void> _cancelReservation(ReservationModel reservation) async {
    final int? reservationId = reservation.id;
    if (reservationId == null) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Cancelar reserva'),
              content: Text(
                'Se cancelara la reserva de ${reservation.guestName}. Esta accion no elimina el registro.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Cancelar reserva'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _processingReservationId = reservationId;
      _error = null;
    });

    try {
      await widget.reservationAppService.cancel(reservationId);
      await _loadReservations();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _resolveErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingReservationId = null;
        });
      }
    }
  }

  static String _formatDateApi(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime _parseDateApi(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.now();
  }

  static TimeOfDay _parseTimeApi(String value) {
    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final int hour = int.tryParse(parts[0]) ?? 9;
    final int minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTimeApi(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  static String _resolveErrorMessage(Object error) {
    if (error is StateError) {
      final String rawMessage = error.message.toString().trim();
      if (rawMessage.isNotEmpty) {
        return rawMessage;
      }
    }
    return error.toString();
  }

  static String _formatDateDisplay(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _FiltersHeader extends StatelessWidget {
  const _FiltersHeader({
    required this.selectedDateLabel,
    required this.loading,
    required this.onPickDate,
    required this.onRefresh,
  });

  final String selectedDateLabel;
  final bool loading;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Fecha: $selectedDateLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F4C5C),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : () => onPickDate(),
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Cambiar fecha'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : () => onRefresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar agenda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 12),
            Text('Cargando agenda...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF1F0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: const TextStyle(color: Color(0xFF8A1C1C))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const Icon(Icons.event_available_rounded, color: Color(0xFF167D85)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No hay reservas registradas para esta fecha.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EditReservationDraft {
  const _EditReservationDraft({
    required this.guestName,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.notes,
  });

  final String guestName;
  final DateTime reservationDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? notes;
}

class _EditReservationDialog extends StatefulWidget {
  const _EditReservationDialog({required this.reservation});

  final ReservationModel reservation;

  @override
  State<_EditReservationDialog> createState() => _EditReservationDialogState();
}

class _EditReservationDialogState extends State<_EditReservationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    _guestController = TextEditingController(
      text: widget.reservation.guestName,
    );
    _notesController = TextEditingController(
      text: widget.reservation.notes ?? '',
    );
    _selectedDate = _SchedulePageState._parseDateApi(
      widget.reservation.reservationDate,
    );
    _startTime = _SchedulePageState._parseTimeApi(widget.reservation.startTime);
    _endTime = _SchedulePageState._parseTimeApi(widget.reservation.endTime);
  }

  @override
  void dispose() {
    _guestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar reserva'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _guestController,
                  decoration: const InputDecoration(labelText: 'Huesped'),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        'Fecha: ${_SchedulePageState._formatDateDisplay(_selectedDate)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('Inicio: ${_formatTime(_startTime)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.timer_rounded),
                      label: Text('Fin: ${_formatTime(_endTime)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
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
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF8A1C1C)),
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
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Guardar cambios'),
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
      helpText: 'Fecha de reserva',
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

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int startMinutes = (_startTime.hour * 60) + _startTime.minute;
    final int endMinutes = (_endTime.hour * 60) + _endTime.minute;
    if (startMinutes >= endMinutes) {
      setState(() {
        _error = 'La hora de inicio debe ser anterior a la hora de fin.';
      });
      return;
    }

    Navigator.of(context).pop(
      _EditReservationDraft(
        guestName: _guestController.text.trim(),
        reservationDate: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  static String _formatTime(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({
    required this.reservation,
    required this.processing,
    this.onEdit,
    this.onCancel,
  });

  final ReservationModel reservation;
  final bool processing;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = switch (reservation.status) {
      ReservationStatus.scheduled => const Color(0xFF167D85),
      ReservationStatus.completed => const Color(0xFF2B8A3E),
      ReservationStatus.cancelled => const Color(0xFFB3261E),
    };

    final String statusLabel = switch (reservation.status) {
      ReservationStatus.scheduled => 'Programada',
      ReservationStatus.completed => 'Completada',
      ReservationStatus.cancelled => 'Cancelada',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatTime(reservation.startTime)} - ${_formatTime(reservation.endTime)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F4C5C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reservation.guestName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2D3D),
              ),
            ),
            if (reservation.notes != null &&
                reservation.notes!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                reservation.notes!,
                style: const TextStyle(color: Color(0xFF526073)),
              ),
            ],
            if (onEdit != null || onCancel != null) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: processing ? null : onEdit,
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Editar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: processing ? null : onCancel,
                    icon: const Icon(Icons.cancel_rounded),
                    label: Text(processing ? 'Procesando...' : 'Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(String apiTime) {
    final List<String> parts = apiTime.split(':');
    if (parts.length < 2) {
      return apiTime;
    }
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}
