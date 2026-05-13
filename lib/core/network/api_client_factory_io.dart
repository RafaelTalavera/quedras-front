import 'api_client.dart';
import 'local_http_client.dart';

ApiClient createApiClient({required String baseUrl}) {
  return LocalHttpClient(baseUrl: baseUrl);
}
