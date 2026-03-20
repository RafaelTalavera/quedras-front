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
}

final class _FakeMassageAppService implements MassageAppService {
  final List<CreateMassageBookingModel> createdBookings =
      <CreateMassageBookingModel>[];
  final List<CreateMassageProviderModel> createdProviders =
      <CreateMassageProviderModel>[];

  @override
  Future<MassageBooking> createBooking(CreateMassageBookingModel input) async {
    createdBookings.add(input);
    return MassageBooking(
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
    );
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
    return const <MassageBooking>[];
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
}
