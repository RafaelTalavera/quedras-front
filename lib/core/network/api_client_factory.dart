import 'api_client.dart';
import 'api_client_factory_io.dart'
    if (dart.library.html) 'api_client_factory_web.dart' as impl;

ApiClient createApiClient({required String baseUrl}) {
  return impl.createApiClient(baseUrl: baseUrl);
}
