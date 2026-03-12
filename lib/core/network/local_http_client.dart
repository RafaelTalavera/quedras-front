import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

final class LocalHttpClient implements ApiClient {
  LocalHttpClient({
    required String baseUrl,
    HttpClient? httpClient,
    Duration requestTimeout = const Duration(seconds: 8),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _httpClient = httpClient ?? HttpClient(),
       _requestTimeout = requestTimeout;

  final Uri _baseUri;
  final HttpClient _httpClient;
  final Duration _requestTimeout;

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async {
    return _send('GET', path, headers: headers);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return _send('POST', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return _send('PUT', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    return _send('PATCH', path, headers: headers, body: body);
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final HttpClientRequest request = await _httpClient
        .openUrl(method, _resolve(path))
        .timeout(_requestTimeout);
    _applyHeaders(request, headers);
    if (body != null) {
      request.write(body);
    }
    final HttpClientResponse response = await request.close().timeout(
      _requestTimeout,
    );
    final String responseBody = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);
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
