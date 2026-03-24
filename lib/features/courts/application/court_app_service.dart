import '../domain/court_models.dart';

abstract interface class CourtAppService {
  Future<List<CourtRateSetting>> listRates();

  Future<CourtRateSetting> updateRate(
    int rateId,
    UpdateCourtRateSettingModel input,
  );

  Future<List<CourtMaterialSetting>> listMaterials();

  Future<CourtMaterialSetting> updateMaterial(
    int materialId,
    UpdateCourtMaterialSettingModel input,
  );

  Future<List<CourtBooking>> listBookings({
    String? bookingDate,
    CourtCustomerType? customerType,
    bool? paid,
  });

  Future<CourtBooking> createBooking(CreateCourtBookingModel input);

  Future<CourtBooking> updateBooking(
    int bookingId,
    UpdateCourtBookingModel input,
  );

  Future<CourtBooking> updatePayment(
    int bookingId,
    UpdateCourtPaymentModel input,
  );

  Future<CourtBooking> cancelBooking(
    int bookingId,
    CancelCourtBookingModel input,
  );

  Future<CourtSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  });
}
