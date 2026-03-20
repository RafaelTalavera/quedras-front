import '../domain/massage_models.dart';

abstract interface class MassageAppService {
  Future<List<MassageProvider>> listProviders({bool activeOnly = false});

  Future<MassageProvider> createProvider(CreateMassageProviderModel input);

  Future<MassageProvider> updateProvider(
    int providerId,
    UpdateMassageProviderModel input,
  );

  Future<List<MassageBooking>> listBookings({
    String? bookingDate,
    String? clientName,
    String? guestReference,
    int? providerId,
    bool? paid,
  });

  Future<MassageBooking> createBooking(CreateMassageBookingModel input);

  Future<MassageBooking> updateBooking(
    int bookingId,
    UpdateMassageBookingModel input,
  );

  Future<MassageBooking> updatePayment(
    int bookingId,
    UpdateMassagePaymentModel input,
  );

  Future<MassageBooking> cancelBooking(
    int bookingId,
    CancelMassageBookingModel input,
  );
}
