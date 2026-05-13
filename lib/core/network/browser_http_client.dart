import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

final class BrowserHttpClient implements ApiClient {
  BrowserHttpClient({
    required String baseUrl,
    BrowserClient? httpClient,
    Duration requestTimeout = const Duration(seconds: 8),
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _httpClient = httpClient ?? BrowserClient(),
       _requestTimeout = requestTimeout;

  final Uri _baseUri;
  final BrowserClient _httpClient;
  final Duration _requestTimeout;

  static Uri _normalizeBaseUri(String baseUrl) {
    final String normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl
        : '$baseUrl/';
    final Uri parsedBaseUri = Uri.parse(normalizedBaseUrl);
    if (parsedBaseUri.hasScheme) {
      return parsedBaseUri;
    }
    return Uri.base.resolveUri(parsedBaseUri);
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _send('GET', path, headers: headers);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _send('POST', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _send('PUT', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _send('PATCH', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> delete(String path, {Map<String, String>? headers}) {
    return _send('DELETE', path, headers: headers);
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final http.Request request = http.Request(method, _resolve(path));
    request.headers.addAll(_normalizeHeaders(headers));
    if (body != null) {
      request.body = body;
    }

    final http.StreamedResponse streamedResponse = await _httpClient
        .send(request)
        .timeout(_requestTimeout);
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_requestTimeout);
    return ApiResponse(statusCode: response.statusCode, body: response.body);
  }

  Uri _resolve(String path) {
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return _baseUri.resolve(normalizedPath);
  }

  Map<String, String> _normalizeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return const <String, String>{};
    }

    final Map<String, String> normalizedHeaders = <String, String>{};
    headers.forEach((String name, String value) {
      final String normalizedName = name.toLowerCase();
      final String normalizedValue = value.toLowerCase();
      if (normalizedName == 'content-type' &&
          normalizedValue.startsWith('application/json') &&
          !normalizedValue.contains('charset=')) {
        normalizedHeaders[name] = '$value; charset=utf-8';
        return;
      }
      normalizedHeaders[name] = value;
    });
    return normalizedHeaders;
  }
}
