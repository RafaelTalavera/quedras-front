import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

final class LocalHttpClient implements ApiClient {
  LocalHttpClient({required String baseUrl, HttpClient? httpClient})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _httpClient;

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async {
    final HttpClientRequest request = await _httpClient.getUrl(_resolve(path));
    _applyHeaders(request, headers);
    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();
    return ApiResponse(statusCode: response.statusCode, body: body);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final HttpClientRequest request = await _httpClient.postUrl(_resolve(path));
    _applyHeaders(request, headers);
    if (body != null) {
      request.write(body);
    }
    final HttpClientResponse response = await request.close();
    final String responseBody = await response.transform(utf8.decoder).join();
    return ApiResponse(statusCode: response.statusCode, body: responseBody);
  }

  Uri _resolve(String path) {
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return _baseUri.resolve(normalizedPath);
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return;
    }
    headers.forEach(request.headers.add);
  }
}
