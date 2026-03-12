import 'package:flutter_test/flutter_test.dart';
import 'package:quedras/features/reservations/application/reservation_app_service.dart';
import 'package:quedras/features/reservations/domain/create_reservation_model.dart';

void main() {
  test('InMemoryReservationAppService devuelve agenda del dia', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();

    final String today = _todayDate();
    final reservations = await service.listByDate(today);

    expect(reservations, isNotEmpty);
    expect(reservations.first.reservationDate, today);
  });

  test('InMemoryReservationAppService agrega una reserva nueva', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();
    final String targetDate = '2026-03-20';

    await service.create(
      CreateReservationModel(
        guestName: 'Pedro Lima',
        reservationDate: targetDate,
        startTime: '17:00:00',
        endTime: '18:00:00',
        notes: 'Turno tarde',
      ),
    );

    final reservations = await service.listByDate(targetDate);
    expect(reservations.length, 1);
    expect(reservations.first.guestName, 'Pedro Lima');
  });
}

String _todayDate() {
  final DateTime now = DateTime.now();
  final String month = now.month.toString().padLeft(2, '0');
  final String day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
