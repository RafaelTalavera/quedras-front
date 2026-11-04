import '../domain/hotel_laundry_models.dart';
import '../domain/laundry_models.dart';
import '../domain/provider_laundry_models.dart';

abstract interface class HotelLaundryAppService {
  Future<List<LaundryProvider>> listProviders();
  Future<LaundryProvider> createProvider(CreateLaundryProviderRequest request);
  Future<LaundryProvider> updateProvider(
    int id,
    CreateLaundryProviderRequest request,
  );
  Future<List<LaundryItem>> listItems();
  Future<HotelLaundryStockTotals> dashboard({int? providerId});
  Future<HotelLaundryResultPage<HotelLaundryDocumentSummary>> listDocuments({
    int? providerId,
    String? status,
    String? documentType,
    int page = 0,
    int size = 20,
  });
  Future<HotelLaundryResultPage<HotelLaundryReturnSummary>> listReturns({
    int? providerId,
    String? status,
    int page = 0,
    int size = 20,
  });
  Future<HotelLaundryDocumentSummary> createDispatch({
    required HotelLaundryDispatchInput input,
    required bool rewash,
  });
  Future<HotelLaundryDocumentSummary> submitDocument({
    required int id,
    required int version,
  });
  Future<ProviderLaundryReturn> getReturn(int id);
  Future<ProviderLaundryReturn> confirmReturn({
    required int id,
    required HotelLaundryReturnConfirmationInput input,
  });
}
