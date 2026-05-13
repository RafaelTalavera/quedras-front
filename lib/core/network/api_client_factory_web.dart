import 'api_client.dart';
import 'browser_http_client.dart';

ApiClient createApiClient({required String baseUrl}) {
  return BrowserHttpClient(baseUrl: baseUrl);
}
