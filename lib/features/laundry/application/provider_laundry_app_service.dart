import '../domain/provider_laundry_models.dart';

abstract interface class ProviderLaundryAppService {
  Future<ProviderLaundryPage<ProviderLaundryDocumentSummary>> listDocuments({
    int page = 0,
    int size = 20,
  });

  Future<ProviderLaundryPage<ProviderLaundryReturnSummary>> listReturns({
    int page = 0,
    int size = 20,
  });

  Future<ProviderLaundryPage<ProviderLaundryStockRow>> listStock({
    required ProviderLaundryStockBucket bucket,
    int page = 0,
    int size = 50,
  });
}
