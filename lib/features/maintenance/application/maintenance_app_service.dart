import '../../../core/audit/audit_models.dart';
import '../domain/maintenance_models.dart';

abstract interface class MaintenanceAppService {
  Future<List<MaintenanceLocation>> listLocations();

  Future<MaintenanceLocation> createLocation(
    CreateMaintenanceLocationModel input,
  );

  Future<MaintenanceLocation> updateLocation(
    int locationId,
    UpdateMaintenanceLocationModel input,
  );

  Future<void> deleteLocation(int locationId);

  Future<List<AuditEventModel>> locationAudit(int locationId);

  Future<List<MaintenanceOrder>> getLocationHistory(int locationId);

  Future<List<MaintenanceProvider>> listProviders();

  Future<List<MaintenancePlan>> listPlans();

  Future<MaintenancePlan> createPlan(CreateMaintenancePlanModel input);

  Future<MaintenancePlan> updatePlan(
    int planId,
    UpdateMaintenancePlanModel input,
  );

  Future<MaintenanceOrder> generateOrderFromPlan(
    int planId, {
    GenerateMaintenancePlanOrderModel? input,
  });

  Future<MaintenanceProvider> createProvider(
    CreateMaintenanceProviderModel input,
  );

  Future<MaintenanceProvider> updateProvider(
    int providerId,
    UpdateMaintenanceProviderModel input,
  );

  Future<void> deleteProvider(int providerId);

  Future<List<AuditEventModel>> providerAudit(int providerId);

  Future<List<MaintenanceOrder>> listOrders({
    String? dateFrom,
    String? dateTo,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
  });

  Future<MaintenanceOrder> createOrder(CreateMaintenanceOrderModel input);

  Future<MaintenanceOrder> updateOrder(
    int orderId,
    UpdateMaintenanceOrderModel input,
  );

  Future<List<MaintenanceConflict>> findConflicts({
    required int locationId,
    required String scheduledStartAt,
    required String scheduledEndAt,
    int? excludeOrderId,
  });

  Future<MaintenanceOrder> startOrder(
    int orderId, {
    StartMaintenanceOrderModel? input,
  });

  Future<MaintenanceOrder> completeOrder(
    int orderId,
    CompleteMaintenanceOrderModel input,
  );

  Future<MaintenanceOrder> cancelOrder(
    int orderId,
    CancelMaintenanceOrderModel input,
  );

  Future<List<MaintenanceOrderAttachment>> listAttachments(int orderId);

  Future<MaintenanceOrderAttachment> addAttachment(
    int orderId,
    AddMaintenanceAttachmentModel input,
  );

  Future<void> deleteAttachment(int orderId, int attachmentId);

  Future<List<AuditEventModel>> history(int orderId);

  Future<MaintenanceSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  });

  Future<MaintenanceDailyExecutiveReport> getDailyExecutiveReport({
    required String date,
  });

  Future<MaintenanceSummaryDetail> getSummaryDetails({
    required MaintenanceSummaryGroupBy groupBy,
    required String groupKey,
    required String dateFrom,
    required String dateTo,
  });
}
