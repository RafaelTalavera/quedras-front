import '../domain/tours_models.dart';

abstract interface class ToursAppService {
  Future<ToursSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  });

  Future<ToursSummaryDetail> getSummaryDetail({
    required ToursSummaryGroupBy groupBy,
    required String code,
    required String dateFrom,
    required String dateTo,
  });

  Future<List<ToursProvider>> listProviders({bool activeOnly = false});

  Future<ToursProvider> createProvider(CreateToursProviderModel input);

  Future<ToursProvider> updateProvider(
    int providerId,
    UpdateToursProviderModel input,
  );

  Future<List<ToursBooking>> listBookings({
    String? dateFrom,
    String? dateTo,
    int? providerId,
    bool? paid,
    ToursServiceType? serviceType,
  });

  Future<ToursBooking> createBooking(CreateToursBookingModel input);

  Future<ToursBooking> updateBooking(
    int bookingId,
    UpdateToursBookingModel input,
  );

  Future<ToursBooking> updatePayment(
    int bookingId,
    UpdateToursPaymentModel input,
  );

  Future<ToursBooking> cancelBooking(
    int bookingId,
    CancelToursBookingModel input,
  );
}
