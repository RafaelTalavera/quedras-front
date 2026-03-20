import 'package:costanorte/features/massages/application/massage_app_service.dart';
import 'package:costanorte/features/massages/domain/massage_models.dart';
import 'package:costanorte/features/massages/presentation/massage_booking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'MassageBookingPage persiste atendimento via service y muestra retorno del backend',
    (WidgetTester tester) async {
      final _FakeMassageAppService service = _FakeMassageAppService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agendamento de massagens'), findsOneWidget);

      await tester.tap(find.text('Lancar atendimento'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
      await tester.enterText(find.byType(TextFormField).at(1), 'Apto 202');
      await tester.enterText(find.byType(TextFormField).at(2), '250');

      await tester.tap(find.text('Salvar atendimento'));
      await tester.pumpAndSettle();

      expect(service.createdBookings.length, 1);
      expect(service.createdBookings.single.clientName, 'Maria');
      expect(service.createdBookings.single.guestReference, 'Apto 202');
      expect(
        service.createdBookings.single.paymentMethod,
        MassagePaymentMethod.card,
      );
      expect(service.createdBookings.single.paymentDate, isNotNull);
      expect(find.text('Maria'), findsOneWidget);
      expect(
        find.textContaining('Apto 202 - Relaxante - Danuska'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MassageBookingPage permite cancelar un atendimento con observacion',
    (WidgetTester tester) async {
      final _FakeMassageAppService service = _FakeMassageAppService.withBookings(
        <MassageBooking>[
          _bookingFixture(id: 10, clientName: 'Maria', paid: false),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar atendimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Observacao do cancelamento'),
        'Cliente nao compareceu',
      );
      await tester.tap(find.text('Confirmar cancelamento'));
      await tester.pumpAndSettle();

      expect(service.cancelledBookingId, 10);
      expect(service.cancelNotes, 'Cliente nao compareceu');
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.textContaining('Cliente nao compareceu'), findsOneWidget);
    },
  );
}

final class _FakeMassageAppService implements MassageAppService {
  _FakeMassageAppService({List<MassageBooking>? initialBookings})
    : _bookings = List<MassageBooking>.from(initialBookings ?? const <MassageBooking>[]);

  _FakeMassageAppService.withBookings(List<MassageBooking> bookings)
    : _bookings = List<MassageBooking>.from(bookings);

  final List<CreateMassageBookingModel> createdBookings =
      <CreateMassageBookingModel>[];
  final List<CreateMassageProviderModel> createdProviders =
      <CreateMassageProviderModel>[];
  final List<UpdateMassageBookingModel> updatedBookings =
      <UpdateMassageBookingModel>[];
  final List<MassageBooking> _bookings;
  int? cancelledBookingId;
  String? cancelNotes;

  @override
  Future<MassageBooking> createBooking(CreateMassageBookingModel input) async {
    createdBookings.add(input);
    final MassageBooking booking = MassageBooking(
      id: 50,
      bookingDate: DateTime.parse(input.bookingDate),
      startTime: input.startTime,
      clientName: input.clientName,
      guestReference: input.guestReference,
      treatment: input.treatment,
      amount: input.amount,
      providerId: input.providerId,
      providerName: 'Danuska',
      providerActive: true,
      paid: input.paid,
      paymentMethod: input.paymentMethod,
      paymentDate: input.paymentDate == null
          ? null
          : DateTime.parse(input.paymentDate!),
      paymentNotes: input.paymentNotes,
      status: MassageBookingStatus.scheduled,
      cancellationNotes: null,
      createdAt: DateTime.parse('${input.bookingDate}T12:00:00Z'),
      updatedAt: DateTime.parse('${input.bookingDate}T12:00:00Z'),
      cancelledAt: null,
      createdBy: 'operador.demo',
      updatedBy: 'operador.demo',
      cancelledBy: null,
    );
    _bookings.add(booking);
    return booking;
  }

  @override
  Future<MassageProvider> createProvider(
    CreateMassageProviderModel input,
  ) async {
    createdProviders.add(input);
    return const MassageProvider(
      id: 2,
      name: 'Nova',
      specialty: 'Relaxante',
      contact: 'Interno',
      active: true,
    );
  }

  @override
  Future<List<MassageBooking>> listBookings({
    String? bookingDate,
    String? clientName,
    String? guestReference,
    int? providerId,
    bool? paid,
  }) async {
    return List<MassageBooking>.from(_bookings);
  }

  @override
  Future<List<MassageProvider>> listProviders({bool activeOnly = false}) async {
    return const <MassageProvider>[
      MassageProvider(
        id: 1,
        name: 'Danuska',
        specialty: 'Relaxante',
        contact: 'Interno',
        active: true,
      ),
    ];
  }

  @override
  Future<MassageBooking> updatePayment(
    int bookingId,
    UpdateMassagePaymentModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<MassageBooking> updateBooking(
    int bookingId,
    UpdateMassageBookingModel input,
  ) async {
    updatedBookings.add(input);
    final int index = _bookings.indexWhere((MassageBooking item) => item.id == bookingId);
    final MassageBooking updated = _bookings[index].copyWith(
      bookingDate: DateTime.parse(input.bookingDate),
      startTime: input.startTime,
      clientName: input.clientName,
      guestReference: input.guestReference,
      treatment: input.treatment,
      amount: input.amount,
      providerId: input.providerId,
      providerName: 'Danuska',
      providerActive: true,
      paid: input.paid,
      paymentMethod: input.paymentMethod,
      paymentDate: input.paymentDate == null
          ? null
          : DateTime.parse(input.paymentDate!),
      paymentNotes: input.paymentNotes,
      updatedAt: DateTime.parse('${input.bookingDate}T13:00:00Z'),
      updatedBy: 'operador.demo',
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<MassageProvider> updateProvider(
    int providerId,
    UpdateMassageProviderModel input,
  ) async {
    return MassageProvider(
      id: providerId,
      name: input.name,
      specialty: input.specialty,
      contact: input.contact,
      active: input.active,
    );
  }

  @override
  Future<MassageBooking> cancelBooking(
    int bookingId,
    CancelMassageBookingModel input,
  ) async {
    cancelledBookingId = bookingId;
    cancelNotes = input.cancellationNotes;
    final int index = _bookings.indexWhere((MassageBooking item) => item.id == bookingId);
    final MassageBooking cancelled = _bookings[index].copyWith(
      status: MassageBookingStatus.cancelled,
      cancellationNotes: input.cancellationNotes,
      cancelledAt: DateTime.parse('2026-03-20T15:00:00Z'),
      cancelledBy: 'operador.demo',
      updatedAt: DateTime.parse('2026-03-20T15:00:00Z'),
      updatedBy: 'operador.demo',
    );
    _bookings[index] = cancelled;
    return cancelled;
  }
}

MassageBooking _bookingFixture({
  required int id,
  required String clientName,
  required bool paid,
}) {
  return MassageBooking(
    id: id,
    bookingDate: DateTime.parse('2026-03-20'),
    startTime: '17:00:00',
    clientName: clientName,
    guestReference: 'Apto 202',
    treatment: 'Relaxante',
    amount: 250,
    providerId: 1,
    providerName: 'Danuska',
    providerActive: true,
    paid: paid,
    paymentMethod: paid ? MassagePaymentMethod.card : null,
    paymentDate: paid ? DateTime.parse('2026-03-20') : null,
    paymentNotes: null,
    status: MassageBookingStatus.scheduled,
    cancellationNotes: null,
    createdAt: DateTime.parse('2026-03-20T12:00:00Z'),
    updatedAt: DateTime.parse('2026-03-20T12:00:00Z'),
    cancelledAt: null,
    createdBy: 'operador.demo',
    updatedBy: 'operador.demo',
    cancelledBy: null,
  );
}
