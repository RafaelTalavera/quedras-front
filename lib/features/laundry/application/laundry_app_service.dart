import '../../../core/audit/audit_models.dart';
import '../domain/laundry_models.dart';

abstract interface class LaundryAppService {
  Future<List<LaundryProvider>> listProviders();
  Future<LaundryProvider> createProvider(CreateLaundryProviderRequest request);
  Future<LaundryProvider> updateProvider(
    int id,
    CreateLaundryProviderRequest request,
  );
  Future<List<LaundryItem>> listItems();
  Future<LaundryItem> createItem(LaundryItem item);
  Future<LaundryItem> updateItem(int id, LaundryItem item);
  Future<LaundryShipment> createShipment(CreateLaundryShipmentRequest request);
  Future<List<LaundryShipment>> listShipments({
    LaundryShipmentStatus? status,
    int? providerId,
    String? dateFrom,
    String? dateTo,
  });
  Future<LaundryShipment> getShipment(int id);
  Future<ReceiveLaundryShipmentResult> receiveShipment(
    int id,
    ReceiveLaundryShipmentRequest request,
  );
  Future<LaundryShipment> dispatchShipment(
    int id,
    DispatchLaundryShipmentRequest request,
  );
  Future<LaundryShipment> cancelShipment(int id, String cancellationNotes);
  Future<List<AuditEventModel>> shipmentAudit(int id);
}
