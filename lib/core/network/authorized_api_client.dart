import 'dart:io';

import 'api_client.dart';

typedef AuthorizationHeaderProvider = String? Function();
typedef UnauthorizedCallback = void Function();

final class AuthorizedApiClient implements ApiClient {
  AuthorizedApiClient({
    required ApiClient delegate,
    required AuthorizationHeaderProvider authorizationHeaderProvider,
    UnauthorizedCallback? onUnauthorized,
  }) : _delegate = delegate,
       _authorizationHeaderProvider = authorizationHeaderProvider,
       _onUnauthorized = onUnauthorized;

  final ApiClient _delegate;
  final AuthorizationHeaderProvider _authorizationHeaderProvider;
  final UnauthorizedCallback? _onUnauthorized;

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _run(
      () => _delegate.get(path, headers: _withAuthorization(headers)),
    );
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _run(
      () => _delegate.post(
        path,
        headers: _withAuthorization(headers),
        body: body,
      ),
    );
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _run(
      () =>
          _delegate.put(path, headers: _withAuthorization(headers), body: body),
    );
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _run(
      () => _delegate.patch(
        path,
        headers: _withAuthorization(headers),
        body: body,
      ),
    );
  }

  Future<ApiResponse> _run(Future<ApiResponse> Function() request) async {
    final ApiResponse response = await request();
    if (response.statusCode == 401) {
      _onUnauthorized?.call();
    }
    return response;
  }

  Map<String, String>? _withAuthorization(Map<String, String>? headers) {
    final String? authorization = _authorizationHeaderProvider();
    if (authorization == null || authorization.isEmpty) {
      return headers;
    }

    if (headers != null &&
        headers.containsKey(HttpHeaders.authorizationHeader)) {
      return headers;
    }

    return <String, String>{
      ...?headers,
      HttpHeaders.authorizationHeader: authorization,
    };
  }
}
