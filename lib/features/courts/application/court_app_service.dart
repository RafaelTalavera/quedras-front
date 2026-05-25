import '../../../core/audit/audit_models.dart';
import '../domain/court_models.dart';

abstract interface class CourtAppService {
  Future<List<CourtRateSetting>> listRates();

  Future<List<CourtPartnerCoach>> listPartnerCoaches({bool activeOnly = true});

  Future<CourtPartnerCoach> createPartnerCoach(
    CreateCourtPartnerCoachModel input,
  );

  Future<CourtPartnerCoach> updatePartnerCoach(
    int partnerCoachId,
    UpdateCourtPartnerCoachModel input,
  );

  Future<List<AuditEventModel>> partnerCoachHistory(int partnerCoachId);

  Future<CourtRateSetting> updateRate(
    int rateId,
    UpdateCourtRateSettingModel input,
  );

  Future<List<AuditEventModel>> rateHistory(int rateId);

  Future<List<CourtMaterialSetting>> listMaterials();

  Future<CourtMaterialSetting> updateMaterial(
    int materialId,
    UpdateCourtMaterialSettingModel input,
  );

  Future<List<AuditEventModel>> materialHistory(int materialId);

  Future<List<CourtBooking>> listBookings({
    String? bookingDate,
    String? dateFrom,
    String? dateTo,
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

  Future<List<AuditEventModel>> history(int bookingId);

  Future<CourtSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  });
}
