import 'dart:io';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/features/massages/domain/massage_models.dart';
import 'package:costanorte/features/massages/infrastructure/http_massage_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HttpMassageAppService lista resumo y detalle por prestador', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '[{"providerId":1,"providerName":"Danuska","providerActive":true,"therapistsCount":1,"scheduledCount":2,"cancelledCount":1,"attendedCount":2,"paidCount":1,"pendingCount":1,"grossAmount":330.0,"paidAmount":180.0,"pendingAmount":150.0,"lastBookingAt":"2026-03-20T11:00:00Z"}]',
        ),
      )
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"providerId":1,"providerName":"Danuska","providerActive":true,"summary":{"providerId":1,"providerName":"Danuska","providerActive":true,"therapistsCount":1,"scheduledCount":2,"cancelledCount":1,"attendedCount":2,"paidCount":1,"pendingCount":1,"grossAmount":330.0,"paidAmount":180.0,"pendingAmount":150.0,"lastBookingAt":"2026-03-20T11:00:00Z"},"items":[{"bookingId":10,"bookingDate":"2026-03-20","startTime":"17:00:00","clientName":"Ana","guestReference":"Apto 101","treatment":"Relaxante","therapistId":101,"therapistName":"Danuska","amount":200.0,"paid":false,"paymentMethod":null,"paymentDate":null,"paymentNotes":null,"status":"SCHEDULED","cancellationNotes":null}]}',
        ),
      );
    final HttpMassageAppService service = HttpMassageAppService(
      apiClient: client,
    );

    final List<MassageProviderSummary> summary =
        await service.listProviderSummaryReport(
          dateFrom: '2026-03-01',
          dateTo: '2026-03-31',
        );
    final MassageProviderDetailReport detail = await service
        .getProviderDetailReport(
          1,
          dateFrom: '2026-03-01',
          dateTo: '2026-03-31',
        );

    expect(summary.single.providerName, 'Danuska');
    expect(summary.single.pendingAmount, 150);
    expect(detail.providerId, 1);
    expect(detail.items.single.clientName, 'Ana');
    expect(
      client.calls.first.path,
      'massages/reports/providers/summary?dateFrom=2026-03-01&dateTo=2026-03-31',
    );
    expect(
      client.calls.last.path,
      'massages/reports/providers/1/details?dateFrom=2026-03-01&dateTo=2026-03-31',
    );
  });

  test('HttpMassageAppService lista prestadores y bookings', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '[{"id":1,"name":"Danuska","specialty":"Relaxante","contact":"Interno","active":true}]',
        ),
      )
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '[{"id":10,"bookingDate":"2026-03-20","startTime":"17:00:00","clientName":"Ana","guestReference":"Apto 101","treatment":"Relaxante","amount":200.0,"providerId":1,"providerName":"Danuska","providerActive":true,"paid":false,"paymentMethod":null,"paymentDate":null,"paymentNotes":null}]',
        ),
      );
    final HttpMassageAppService service = HttpMassageAppService(
      apiClient: client,
    );

    final List<MassageProvider> providers = await service.listProviders();
    final List<MassageBooking> bookings = await service.listBookings(
      bookingDate: '2026-03-20',
      paid: false,
    );

    expect(providers.single.id, 1);
    expect(bookings.single.clientName, 'Ana');
    expect(client.calls.first.path, 'massages/providers');
    expect(
      client.calls.last.path,
      'massages/bookings?bookingDate=2026-03-20&paid=false',
    );
  });

  test(
    'HttpMassageAppService crea, actualiza, cancela booking y actualiza pago',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          ApiResponse(
            statusCode: 201,
            body: _bookingJson(
              paid: true,
              paymentMethod: 'CARD',
              paymentNotes: 'Pago no balcao',
            ),
          ),
        )
        ..enqueue(
          ApiResponse(
            statusCode: 200,
            body: _bookingJson(
              paid: false,
              paymentMethod: null,
              paymentNotes: null,
            ),
          ),
        )
        ..enqueue(
          ApiResponse(
            statusCode: 200,
            body: _bookingJson(
              status: 'CANCELLED',
              paid: false,
              paymentMethod: null,
              paymentNotes: null,
              cancellationNotes: 'Cliente desistiu',
              cancelledBy: 'operador.demo',
            ),
          ),
        )
        ..enqueue(
          ApiResponse(
            statusCode: 200,
            body: _bookingJson(
              paid: true,
              paymentMethod: 'PIX',
              paymentNotes: 'Pago depois',
            ),
          ),
        );
      final HttpMassageAppService service = HttpMassageAppService(
        apiClient: client,
      );

      final MassageBooking created = await service.createBooking(
        const CreateMassageBookingModel(
          bookingDate: '2026-03-20',
          startTime: '17:00:00',
          clientName: 'Ana',
          guestReference: 'Apto 101',
          treatment: 'Relaxante',
          amount: 200,
          providerId: 1,
          therapistId: 101,
          paid: true,
          paymentMethod: MassagePaymentMethod.card,
          paymentDate: '2026-03-20',
          paymentNotes: 'Pago no balcao',
        ),
      );
      final MassageBooking updated = await service.updateBooking(
        10,
        const UpdateMassageBookingModel(
          bookingDate: '2026-03-20',
          startTime: '17:00:00',
          clientName: 'Ana',
          guestReference: 'Apto 101',
          treatment: 'Relaxante',
          amount: 200,
          providerId: 1,
          therapistId: 101,
          paid: false,
          paymentMethod: null,
          paymentDate: null,
          paymentNotes: null,
        ),
      );
      final MassageBooking cancelled = await service.cancelBooking(
        10,
        const CancelMassageBookingModel(cancellationNotes: 'Cliente desistiu'),
      );
      final MassageBooking paymentUpdated = await service.updatePayment(
        10,
        const UpdateMassagePaymentModel(
          paymentMethod: MassagePaymentMethod.pix,
          paymentDate: '2026-03-20',
          paymentNotes: 'Pago depois',
        ),
      );

      expect(created.paymentMethod, MassagePaymentMethod.card);
      expect(updated.paid, isFalse);
      expect(cancelled.status, MassageBookingStatus.cancelled);
      expect(cancelled.cancellationNotes, 'Cliente desistiu');
      expect(paymentUpdated.paymentMethod, MassagePaymentMethod.pix);
      expect(client.calls.first.method, 'POST');
      expect(client.calls[1].path, 'massages/bookings/10');
      expect(client.calls[2].path, 'massages/bookings/10/cancel');
      expect(client.calls.last.path, 'massages/bookings/10/payment');
      expect(
        client.calls.last.body,
        '{"paymentMethod":"PIX","paymentDate":"2026-03-20","paymentNotes":"Pago depois"}',
      );
    },
  );

  test('HttpMassageAppService traduce errores y red local', () async {
    final _FakeApiClient apiErrorClient = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 409,
          body:
              '{"message":"Massage provider already has a booking for the selected date and time."}',
        ),
      );
    final HttpMassageAppService apiErrorService = HttpMassageAppService(
      apiClient: apiErrorClient,
    );

    await expectLater(
      () => apiErrorService.listBookings(),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Esse prestador j\u00e1 possui um atendimento para a data e hor\u00e1rio selecionados.',
        ),
      ),
    );

    final _FakeApiClient networkClient = _FakeApiClient()
      ..nextError = const SocketException('Connection refused');
    final HttpMassageAppService networkService = HttpMassageAppService(
      apiClient: networkClient,
    );

    await expectLater(
      () => networkService.listProviders(),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'N\u00e3o foi poss\u00edvel conectar ao backend local. Verifique o servidor e a rede interna.',
        ),
      ),
    );
  });

  test('HttpMassageAppService crea masajista con respuesta directa', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 201,
          body: '{"id":101,"name":"Bruna","active":true}',
        ),
      );
    final HttpMassageAppService service = HttpMassageAppService(
      apiClient: client,
    );

    final MassageTherapist created = await service.createTherapist(
      1,
      const CreateMassageTherapistModel(name: 'Bruna'),
    );

    expect(created.id, 101);
    expect(created.name, 'Bruna');
    expect(client.calls.single.path, 'massages/providers/1/therapists');
    expect(client.calls.single.body, '{"name":"Bruna"}');
  });

  test(
    'HttpMassageAppService crea masajista con respuesta de proveedor embebido',
    () async {
      final _FakeApiClient client = _FakeApiClient()
        ..enqueue(
          const ApiResponse(
            statusCode: 201,
            body:
                '{"id":1,"name":"Danuska","specialty":"Relaxante","contact":"Interno","active":true,"therapists":[{"id":100,"name":"Ana","active":true},{"id":101,"name":"Bruna","active":true}]}',
          ),
        );
      final HttpMassageAppService service = HttpMassageAppService(
        apiClient: client,
      );

      final MassageTherapist created = await service.createTherapist(
        1,
        const CreateMassageTherapistModel(name: 'Bruna'),
      );

      expect(created.id, 101);
      expect(created.name, 'Bruna');
      expect(created.active, isTrue);
    },
  );
}

String _bookingJson({
  String status = 'SCHEDULED',
  bool paid = false,
  String? paymentMethod,
  String? paymentNotes,
  String? cancellationNotes,
  String? cancelledBy,
}) =>
    '{"id":10,"bookingDate":"2026-03-20","startTime":"17:00:00","clientName":"Ana","guestReference":"Apto 101","treatment":"Relaxante","amount":200.0,"providerId":1,"providerName":"Danuska","providerActive":true,"paid":$paid,"paymentMethod":${paymentMethod == null ? 'null' : '"$paymentMethod"'},"paymentDate":"2026-03-20","paymentNotes":${paymentNotes == null ? 'null' : '"$paymentNotes"'},"status":"$status","cancellationNotes":${cancellationNotes == null ? 'null' : '"$cancellationNotes"'},"createdAt":"2026-03-20T12:00:00Z","updatedAt":"2026-03-20T12:30:00Z","cancelledAt":${status == 'CANCELLED' ? '"2026-03-20T13:00:00Z"' : 'null'},"createdBy":"operador.demo","updatedBy":"operador.demo","cancelledBy":${cancelledBy == null ? 'null' : '"$cancelledBy"'}}';

final class _FakeApiClient implements ApiClient {
  final List<_Call> calls = <_Call>[];
  final List<ApiResponse> _responses = <ApiResponse>[];
  Object? nextError;

  void enqueue(ApiResponse response) {
    _responses.add(response);
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _consume('GET', path, body: null);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PATCH', path, body: body);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('POST', path, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PUT', path, body: body);
  }

  Future<ApiResponse> _consume(
    String method,
    String path, {
    String? body,
  }) async {
    calls.add(_Call(method: method, path: path, body: body));
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
  const _Call({required this.method, required this.path, required this.body});

  final String method;
  final String path;
  final String? body;
}
