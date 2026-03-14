import 'package:flutter_test/flutter_test.dart';
import 'package:costanorte/features/reservations/domain/create_reservation_model.dart';
import 'package:costanorte/features/reservations/domain/reservation_model.dart';
import 'package:costanorte/features/reservations/domain/reservation_status.dart';

void main() {
  test('ReservationModel parsea JSON backend y conserva contrato', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'id': 11,
      'guestName': 'Laura Suárez',
      'reservationDate': '2026-03-12',
      'startTime': '09:00:00',
      'endTime': '10:00:00',
      'status': 'SCHEDULED',
      'notes': 'Huesped suite 202',
      'createdAt': '2026-03-12T10:00:00Z',
      'updatedAt': '2026-03-12T10:05:00Z',
    };

    final ReservationModel model = ReservationModel.fromJson(json);
    final Map<String, dynamic> mappedJson = model.toJson();

    expect(model.id, 11);
    expect(model.status, ReservationStatus.scheduled);
    expect(mappedJson['status'], 'SCHEDULED');
    expect(mappedJson['reservationDate'], '2026-03-12');
    expect(mappedJson['startTime'], '09:00:00');
  });

  test('CreateReservationModel serializa payload de alta', () {
    final CreateReservationModel model = CreateReservationModel(
      guestName: '  Martin Gomez  ',
      reservationDate: '2026-03-13',
      startTime: '11:00:00',
      endTime: '12:00:00',
      notes: 'Uso de raquetas del hotel',
    );

    final Map<String, dynamic> payload = model.toJson();

    expect(payload['guestName'], 'Martin Gomez');
    expect(payload['reservationDate'], '2026-03-13');
    expect(payload['startTime'], '11:00:00');
    expect(payload['endTime'], '12:00:00');
    expect(payload['notes'], 'Uso de raquetas del hotel');
  });
}
