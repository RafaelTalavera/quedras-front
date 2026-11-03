import '../domain/provider_laundry_models.dart';

abstract interface class ProviderLaundryAppService {
  Future<ProviderLaundryResultPage<ProviderLaundryDocumentSummary>>
  listDocuments({int page = 0, int size = 20});

  Future<ProviderLaundryResultPage<ProviderLaundryReturnSummary>> listReturns({
    int page = 0,
    int size = 20,
  });

  Future<ProviderLaundryResultPage<ProviderLaundryStockRow>> listStock({
    required ProviderLaundryStockBucket bucket,
    int page = 0,
    int size = 50,
  });
}
