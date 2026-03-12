abstract interface class ApiClient {
  Future<ApiResponse> get(String path, {Map<String, String>? headers});

  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  });

  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  });

  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  });
}

final class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
