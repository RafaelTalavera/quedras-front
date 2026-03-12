import 'package:flutter/material.dart';

import '../../reservations/application/reservation_app_service.dart';
import '../../reservations/domain/reservation_model.dart';
import '../../reservations/domain/reservation_status.dart';

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
                    child: _ReservationTile(reservation: reservation),
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

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation});

  final ReservationModel reservation;

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
