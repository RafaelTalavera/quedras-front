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
      final _FakeMassageAppService service =
          _FakeMassageAppService.withBookings(<MassageBooking>[
            _bookingFixture(id: 10, clientName: 'Maria', paid: false),
          ]);

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
      expect(find.textContaining('Cliente nao compareceu'), findsWidgets);
    },
  );

  testWidgets(
    'MassageBookingPage permite informar pago desde la accion rapida superior',
    (WidgetTester tester) async {
      final _FakeMassageAppService service =
          _FakeMassageAppService.withBookings(<MassageBooking>[
            _bookingFixture(id: 10, clientName: 'Maria', paid: false),
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();
      final DateTime bookingDate = service.currentBookings.single.bookingDate;

      await tester.tap(find.text('Informar pago').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Informar pago').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Observacao do pagamento'),
        'Pago na recepcao',
      );
      await tester.tap(find.text('Confirmar pagamento'));
      await tester.pumpAndSettle();

      expect(service.paymentUpdatedBookingId, 10);
      expect(service.paymentUpdate?.paymentMethod, MassagePaymentMethod.card);
      expect(service.paymentUpdate?.paymentDate, _formatDate(bookingDate));
      expect(service.paymentUpdate?.paymentNotes, 'Pago na recepcao');
      expect(find.text('Pago'), findsWidgets);
      expect(
        find.textContaining(
          'Pago em ${_formatShortDate(bookingDate)} via Cartao',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'MassageBookingPage muestra informar pago en acciones del booking',
    (WidgetTester tester) async {
      final _FakeMassageAppService service =
          _FakeMassageAppService.withBookings(<MassageBooking>[
            _bookingFixture(id: 10, clientName: 'Maria', paid: false),
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maria'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Maria'));
      await tester.pumpAndSettle();

      expect(find.text('Editar registro'), findsOneWidget);
      expect(find.text('Informar pago'), findsWidgets);
      expect(find.text('Cancelar atencao'), findsOneWidget);
    },
  );

  testWidgets(
    'MassageBookingPage lista atendimientos no elegibles en informar pago con motivo visible',
    (WidgetTester tester) async {
      final _FakeMassageAppService service =
          _FakeMassageAppService.withBookings(<MassageBooking>[
            _bookingFixture(id: 10, clientName: 'Maria', paid: true),
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Informar pago'));
      await tester.pumpAndSettle();

      expect(find.text('Maria'), findsWidgets);
      expect(
        find.text('Todos os atendimentos do dia ja estao pagos ou cancelados.'),
        findsOneWidget,
      );
      expect(find.text('Pagamento ja informado'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Informar pago'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'MassageBookingPage muestra resumen por prestador y permite ver detalle',
    (WidgetTester tester) async {
      final _FakeMassageAppService service =
          _FakeMassageAppService.withBookings(<MassageBooking>[
            _bookingFixture(id: 10, clientName: 'Maria', paid: false),
            _bookingFixture(id: 11, clientName: 'Ana', paid: true),
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MassageBookingPage(massageAppService: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resumo por prestador'), findsOneWidget);
      expect(find.text('Danuska'), findsWidgets);
      expect(find.text('Ver detalhe'), findsWidgets);

      final Finder detailButton = find.widgetWithText(
        TextButton,
        'Ver detalhe',
      );
      expect(detailButton, findsWidgets);

      await tester.ensureVisible(detailButton.first);
      await tester.tap(detailButton.first);
      await tester.pumpAndSettle();

      expect(find.text('Detalhe de Danuska'), findsOneWidget);
      expect(find.text('Maria'), findsWidgets);
      expect(find.text('Ana'), findsWidgets);
    },
  );
}

final class _FakeMassageAppService implements MassageAppService {
  _FakeMassageAppService({List<MassageBooking>? initialBookings})
    : _bookings = List<MassageBooking>.from(
        initialBookings ?? const <MassageBooking>[],
      );

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
  int? paymentUpdatedBookingId;
  UpdateMassagePaymentModel? paymentUpdate;

  List<MassageBooking> get currentBookings =>
      List<MassageBooking>.unmodifiable(_bookings);

  @override
  Future<MassageProviderDetailReport> getProviderDetailReport(
    int providerId, {
    required String dateFrom,
    required String dateTo,
  }) async {
    final List<MassageBooking> providerBookings = _bookings
        .where((MassageBooking booking) => booking.providerId == providerId)
        .toList()
      ..sort((MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt));
    final MassageProviderSummary summary =
        (await listProviderSummaryReport(dateFrom: dateFrom, dateTo: dateTo))
            .firstWhere((MassageProviderSummary item) => item.providerId == providerId);
    return MassageProviderDetailReport(
      providerId: providerId,
      providerName: 'Danuska',
      providerActive: true,
      summary: summary,
      items: providerBookings
          .map<MassageProviderReportItem>(
            (MassageBooking booking) => MassageProviderReportItem(
              bookingId: booking.id,
              bookingDate: booking.bookingDate,
              startTime: booking.startTime,
              clientName: booking.clientName,
              guestReference: booking.guestReference,
              treatment: booking.treatment,
              therapistId: booking.therapistId,
              therapistName: booking.therapistName,
              amount: booking.amount,
              paid: booking.paid,
              paymentMethod: booking.paymentMethod,
              paymentDate: booking.paymentDate,
              paymentNotes: booking.paymentNotes,
              status: booking.status,
              cancellationNotes: booking.cancellationNotes,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<MassageProviderSummary>> listProviderSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    final List<MassageBooking> activeBookings = _bookings
        .where((MassageBooking booking) => booking.status == MassageBookingStatus.scheduled)
        .toList();
    final int paidCount = activeBookings.where((MassageBooking booking) => booking.paid).length;
    final int pendingCount = activeBookings.where((MassageBooking booking) => !booking.paid).length;
    final double paidAmount = activeBookings
        .where((MassageBooking booking) => booking.paid)
        .fold<double>(0, (double total, MassageBooking booking) => total + booking.amount);
    final double pendingAmount = activeBookings
        .where((MassageBooking booking) => !booking.paid)
        .fold<double>(0, (double total, MassageBooking booking) => total + booking.amount);
    final double grossAmount = activeBookings.fold<double>(
      0,
      (double total, MassageBooking booking) => total + booking.amount,
    );
    final DateTime? lastBookingAt = _bookings.isEmpty
        ? null
        : (_bookings.toList()..sort((MassageBooking a, MassageBooking b) => a.startAt.compareTo(b.startAt))).last.startAt;
    return <MassageProviderSummary>[
      MassageProviderSummary(
        providerId: 1,
        providerName: 'Danuska',
        providerActive: true,
        therapistsCount: 1,
        scheduledCount: activeBookings.length,
        cancelledCount: _bookings.length - activeBookings.length,
        attendedCount: activeBookings.length,
        paidCount: paidCount,
        pendingCount: pendingCount,
        grossAmount: grossAmount,
        paidAmount: paidAmount,
        pendingAmount: pendingAmount,
        lastBookingAt: lastBookingAt,
      ),
    ];
  }

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
      therapistId: input.therapistId,
      therapistName: 'Danuska',
      therapistActive: true,
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
      therapists: <MassageTherapist>[],
    );
  }

  @override
  Future<MassageTherapist> createTherapist(
    int providerId,
    CreateMassageTherapistModel input,
  ) async {
    return MassageTherapist(id: 99, name: input.name, active: true);
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
        therapists: <MassageTherapist>[
          MassageTherapist(id: 101, name: 'Danuska', active: true),
        ],
      ),
    ];
  }

  @override
  Future<MassageBooking> updatePayment(
    int bookingId,
    UpdateMassagePaymentModel input,
  ) async {
    paymentUpdatedBookingId = bookingId;
    paymentUpdate = input;
    final int index = _bookings.indexWhere(
      (MassageBooking item) => item.id == bookingId,
    );
    final MassageBooking updated = _bookings[index].copyWith(
      paid: true,
      paymentMethod: input.paymentMethod,
      paymentDate: DateTime.parse(input.paymentDate),
      paymentNotes: input.paymentNotes,
      updatedAt: DateTime.parse('${input.paymentDate}T13:30:00Z'),
      updatedBy: 'operador.demo',
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<MassageBooking> updateBooking(
    int bookingId,
    UpdateMassageBookingModel input,
  ) async {
    updatedBookings.add(input);
    final int index = _bookings.indexWhere(
      (MassageBooking item) => item.id == bookingId,
    );
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
      therapistId: input.therapistId,
      therapistName: 'Danuska',
      therapistActive: true,
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
      therapists: const <MassageTherapist>[
        MassageTherapist(id: 101, name: 'Danuska', active: true),
      ],
    );
  }

  @override
  Future<MassageTherapist> updateTherapist(
    int providerId,
    int therapistId,
    UpdateMassageTherapistModel input,
  ) async {
    return MassageTherapist(
      id: therapistId,
      name: input.name,
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
    final int index = _bookings.indexWhere(
      (MassageBooking item) => item.id == bookingId,
    );
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
  final DateTime today = DateTime.now();
  final DateTime bookingDate = DateTime(today.year, today.month, today.day);
  return MassageBooking(
    id: id,
    bookingDate: bookingDate,
    startTime: '17:00:00',
    clientName: clientName,
    guestReference: 'Apto 202',
    treatment: 'Relaxante',
    amount: 250,
    providerId: 1,
    providerName: 'Danuska',
    providerActive: true,
    therapistId: 101,
    therapistName: 'Danuska',
    therapistActive: true,
    paid: paid,
    paymentMethod: paid ? MassagePaymentMethod.card : null,
    paymentDate: paid ? bookingDate : null,
    paymentNotes: null,
    status: MassageBookingStatus.scheduled,
    cancellationNotes: null,
    createdAt: DateTime.parse('${_formatDate(bookingDate)}T12:00:00Z'),
    updatedAt: DateTime.parse('${_formatDate(bookingDate)}T12:00:00Z'),
    cancelledAt: null,
    createdBy: 'operador.demo',
    updatedBy: 'operador.demo',
    cancelledBy: null,
  );
}

String _formatDate(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatShortDate(DateTime date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
