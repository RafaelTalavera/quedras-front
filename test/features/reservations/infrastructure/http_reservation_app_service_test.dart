import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quedras/core/network/api_client.dart';
import 'package:quedras/features/reservations/domain/create_reservation_model.dart';
import 'package:quedras/features/reservations/domain/update_reservation_model.dart';
import 'package:quedras/features/reservations/infrastructure/http_reservation_app_service.dart';

void main() {
  test('HttpReservationAppService lista reservas por fecha', () async {
    final _FakeApiClient client = _FakeApiClient();
    client.enqueue(
      const ApiResponse(
        statusCode: 200,
        body:
            '[{"id":10,"guestName":"Ana","reservationDate":"2026-03-25","startTime":"09:00:00","endTime":"10:00:00","status":"SCHEDULED","notes":null,"createdAt":"2026-03-12T12:00:00Z","updatedAt":"2026-03-12T12:00:00Z"}]',
      ),
    );
    final HttpReservationAppService service = HttpReservationAppService(
      apiClient: client,
    );

    final list = await service.listByDate('2026-03-25');

    expect(list.length, 1);
    expect(list.first.id, 10);
    expect(client.calls.length, 1);
    expect(client.calls.first.method, 'GET');
    expect(client.calls.first.path, 'reservations?reservationDate=2026-03-25');
  });

  test('HttpReservationAppService crea reserva via POST', () async {
    final _FakeApiClient client = _FakeApiClient();
    client.enqueue(
      const ApiResponse(
        statusCode: 201,
        body:
            '{"id":11,"guestName":"Pedro","reservationDate":"2026-03-25","startTime":"10:00:00","endTime":"11:00:00","status":"SCHEDULED","notes":"Turno","createdAt":"2026-03-12T12:00:00Z","updatedAt":"2026-03-12T12:00:00Z"}',
      ),
    );
    final HttpReservationAppService service = HttpReservationAppService(
      apiClient: client,
    );

    final created = await service.create(
      CreateReservationModel(
        guestName: 'Pedro',
        reservationDate: '2026-03-25',
        startTime: '10:00:00',
        endTime: '11:00:00',
        notes: 'Turno',
      ),
    );

    expect(created.id, 11);
    expect(client.calls.length, 1);
    expect(client.calls.first.method, 'POST');
    expect(client.calls.first.path, 'reservations');
  });

  test('HttpReservationAppService actualiza y cancela reserva', () async {
    final _FakeApiClient client = _FakeApiClient();
    client
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"id":12,"guestName":"Laura","reservationDate":"2026-03-25","startTime":"12:00:00","endTime":"13:00:00","status":"SCHEDULED","notes":"Editada","createdAt":"2026-03-12T12:00:00Z","updatedAt":"2026-03-12T12:30:00Z"}',
        ),
      )
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"id":12,"guestName":"Laura","reservationDate":"2026-03-25","startTime":"12:00:00","endTime":"13:00:00","status":"CANCELLED","notes":"Editada","createdAt":"2026-03-12T12:00:00Z","updatedAt":"2026-03-12T12:40:00Z"}',
        ),
      );
    final HttpReservationAppService service = HttpReservationAppService(
      apiClient: client,
    );

    final updated = await service.update(
      12,
      UpdateReservationModel(
        guestName: 'Laura',
        reservationDate: '2026-03-25',
        startTime: '12:00:00',
        endTime: '13:00:00',
        notes: 'Editada',
      ),
    );
    final cancelled = await service.cancel(12);

    expect(updated.status.toApiValue(), 'SCHEDULED');
    expect(cancelled.status.toApiValue(), 'CANCELLED');
    expect(client.calls.length, 2);
    expect(client.calls.first.method, 'PUT');
    expect(client.calls.first.path, 'reservations/12');
    expect(client.calls.last.method, 'PATCH');
    expect(client.calls.last.path, 'reservations/12/cancel');
  });

  test('HttpReservationAppService propaga mensaje de error de API', () async {
    final _FakeApiClient client = _FakeApiClient();
    client.enqueue(
      const ApiResponse(
        statusCode: 409,
        body: '{"message":"Reservation overlaps with an existing booking."}',
      ),
    );
    final HttpReservationAppService service = HttpReservationAppService(
      apiClient: client,
    );

    await expectLater(
      () => service.create(
        CreateReservationModel(
          guestName: 'Conflicto',
          reservationDate: '2026-03-25',
          startTime: '10:30:00',
          endTime: '11:30:00',
          notes: null,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Reservation overlaps with an existing booking.',
        ),
      ),
    );
  });

  test('HttpReservationAppService transforma fallas de red local', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..nextError = const SocketException('Connection refused');
    final HttpReservationAppService service = HttpReservationAppService(
      apiClient: client,
    );

    await expectLater(
      () => service.listByDate('2026-03-25'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'No fue posible conectar con el backend local. Verifique servidor y red interna.',
        ),
      ),
    );
  });
}

final class _FakeApiClient implements ApiClient {
  final List<_Call> calls = <_Call>[];
  final List<ApiResponse> _responses = <ApiResponse>[];
  Object? nextError;

  void enqueue(ApiResponse response) {
    _responses.add(response);
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _consume('GET', path, headers: headers);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PATCH', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('POST', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PUT', path, headers: headers, body: body);
  }

  Future<ApiResponse> _consume(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    calls.add(_Call(method: method, path: path, headers: headers, body: body));
    final Object? queuedError = nextError;
    if (queuedError != null) {
      nextError = null;
      throw queuedError;
    }
    if (_responses.isEmpty) {
      return const ApiResponse(statusCode: 500, body: '{}');
    }
    return _responses.removeAt(0);
  }
}

final class _Call {
  const _Call({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String>? headers;
  final String? body;
}
