import '../domain/create_reservation_model.dart';
import '../domain/reservation_model.dart';
import '../domain/reservation_status.dart';

abstract interface class ReservationAppService {
  Future<List<ReservationModel>> listByDate(String reservationDate);

  Future<ReservationModel> create(CreateReservationModel input);
}

final class InMemoryReservationAppService implements ReservationAppService {
  InMemoryReservationAppService()
    : _items = <ReservationModel>[
        ReservationModel(
          id: 1,
          guestName: 'Laura Nunes',
          reservationDate: _todayDate(),
          startTime: '08:00:00',
          endTime: '09:00:00',
          status: ReservationStatus.scheduled,
          notes: 'Clase individual',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        ReservationModel(
          id: 2,
          guestName: 'Martin Alves',
          reservationDate: _todayDate(),
          startTime: '11:00:00',
          endTime: '12:00:00',
          status: ReservationStatus.scheduled,
          notes: 'Huesped habitacion 402',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      ];

  final List<ReservationModel> _items;
  int _nextId = 3;

  @override
  Future<List<ReservationModel>> listByDate(String reservationDate) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final List<ReservationModel> list = _items
        .where(
          (ReservationModel item) => item.reservationDate == reservationDate,
        )
        .toList();
    list.sort((ReservationModel a, ReservationModel b) {
      return _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime));
    });
    return list;
  }

  @override
  Future<ReservationModel> create(CreateReservationModel input) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));

    if (input.guestName.trim().length < 3) {
      throw StateError(
        'El nombre del huesped debe tener al menos 3 caracteres.',
      );
    }
    if (_timeToMinutes(input.startTime) >= _timeToMinutes(input.endTime)) {
      throw StateError('La hora de inicio debe ser anterior a la hora de fin.');
    }

    final DateTime now = DateTime.now().toUtc();
    final ReservationModel created = ReservationModel(
      id: _nextId++,
      guestName: input.guestName,
      reservationDate: input.reservationDate,
      startTime: input.startTime,
      endTime: input.endTime,
      status: ReservationStatus.scheduled,
      notes: input.notes,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(created);
    return created;
  }

  static int _timeToMinutes(String value) {
    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return 0;
    }
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  static String _todayDate() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
