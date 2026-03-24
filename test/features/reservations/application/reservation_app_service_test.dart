import 'package:flutter_test/flutter_test.dart';
import 'package:costanorte/features/reservations/application/reservation_app_service.dart';
import 'package:costanorte/features/reservations/domain/create_reservation_model.dart';
import 'package:costanorte/features/reservations/domain/reservation_status.dart';
import 'package:costanorte/features/reservations/domain/update_reservation_model.dart';

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
    final String targetDate = '2026-12-20';

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

  test('InMemoryReservationAppService rejeita sobreposição', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();
    final String today = _todayDate();

    await expectLater(
      () => service.create(
        CreateReservationModel(
          guestName: 'Conflicto Horario',
          reservationDate: today,
          startTime: '08:30:00',
          endTime: '09:30:00',
          notes: null,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Já existe uma reserva ativa para esse horário.',
        ),
      ),
    );
  });

  test('InMemoryReservationAppService rejeita horário fora da janela', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();

    await expectLater(
      () => service.create(
        CreateReservationModel(
          guestName: 'Horario Fuera',
          reservationDate: '2026-03-20',
          startTime: '06:00:00',
          endTime: '07:00:00',
          notes: null,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'A reserva deve estar dentro do horário de funcionamento, das 07:00 às 23:00.',
        ),
      ),
    );
  });

  test('InMemoryReservationAppService rejeita duração não permitida', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();

    await expectLater(
      () => service.create(
        CreateReservationModel(
          guestName: 'Duracion Fuera',
          reservationDate: '2026-03-20',
          startTime: '10:00:00',
          endTime: '10:45:00',
          notes: null,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'A duração da reserva deve ser de 60, 90 ou 120 minutos.',
        ),
      ),
    );
  });

  test(
    'InMemoryReservationAppService actualiza una reserva existente',
    () async {
      final InMemoryReservationAppService service =
          InMemoryReservationAppService();
      final String today = _todayDate();
      final reservations = await service.listByDate(today);
      final int reservationId = reservations.first.id!;

      final updated = await service.update(
        reservationId,
        UpdateReservationModel(
          guestName: 'Laura Nunes Editada',
          reservationDate: today,
          startTime: '09:00:00',
          endTime: '10:00:00',
          notes: 'Cambio operativo',
        ),
      );

      expect(updated.id, reservationId);
      expect(updated.guestName, 'Laura Nunes Editada');
      expect(updated.startTime, '09:00:00');
      expect(updated.endTime, '10:00:00');
    },
  );

  test(
    'InMemoryReservationAppService rejeita edição com sobreposição',
    () async {
      final InMemoryReservationAppService service =
          InMemoryReservationAppService();
      final String today = _todayDate();
      final reservations = await service.listByDate(today);
      final int reservationId = reservations.first.id!;

      await expectLater(
        () => service.update(
          reservationId,
          UpdateReservationModel(
            guestName: 'Laura Nunes',
            reservationDate: today,
            startTime: '11:30:00',
            endTime: '12:30:00',
            notes: null,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message.toString(),
            'message',
            'Já existe uma reserva ativa para esse horário.',
          ),
        ),
      );
    },
  );

  test('InMemoryReservationAppService cancela uma reserva', () async {
    final InMemoryReservationAppService service =
        InMemoryReservationAppService();

    final created = await service.create(
      CreateReservationModel(
        guestName: 'Cancelar Reserva',
        reservationDate: '2026-03-25',
        startTime: '18:00:00',
        endTime: '19:00:00',
        notes: null,
      ),
    );

    final cancelled = await service.cancel(created.id!);
    expect(cancelled.status, ReservationStatus.cancelled);
  });

  test(
    'InMemoryReservationAppService rejeita editar uma reserva cancelada',
    () async {
      final InMemoryReservationAppService service =
          InMemoryReservationAppService();

      final created = await service.create(
        CreateReservationModel(
          guestName: 'Reserva Cancelada',
          reservationDate: '2026-03-25',
          startTime: '19:00:00',
          endTime: '20:00:00',
          notes: null,
        ),
      );
      await service.cancel(created.id!);

      await expectLater(
        () => service.update(
          created.id!,
          UpdateReservationModel(
            guestName: 'Intento Edicion',
            reservationDate: '2026-03-25',
            startTime: '20:00:00',
            endTime: '21:00:00',
            notes: null,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message.toString(),
            'message',
            'Reservas canceladas não podem ser editadas.',
          ),
        ),
      );
    },
  );

  test(
    'InMemoryReservationAppService retorna not found em cancelamento inexistente',
    () async {
      final InMemoryReservationAppService service =
          InMemoryReservationAppService();

      await expectLater(
        () => service.cancel(999999),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message.toString(),
            'message',
            'Reserva 999999 não encontrada.',
          ),
        ),
      );
    },
  );
}

String _todayDate() {
  final DateTime now = DateTime.now();
  final String month = now.month.toString().padLeft(2, '0');
  final String day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
