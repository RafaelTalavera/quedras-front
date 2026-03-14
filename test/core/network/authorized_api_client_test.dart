import 'dart:io';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/network/authorized_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AuthorizedApiClient adjunta Authorization cuando existe sesion',
    () async {
      final _FakeApiClient delegate = _FakeApiClient();
      final AuthorizedApiClient client = AuthorizedApiClient(
        delegate: delegate,
        authorizationHeaderProvider: () => 'Bearer signed-token',
      );

      await client.get('reservations');

      expect(delegate.calls.length, 1);
      expect(
        delegate.calls.single.headers?[HttpHeaders.authorizationHeader],
        'Bearer signed-token',
      );
    },
  );

  test(
    'AuthorizedApiClient respeta Authorization explicito del caller',
    () async {
      final _FakeApiClient delegate = _FakeApiClient();
      final AuthorizedApiClient client = AuthorizedApiClient(
        delegate: delegate,
        authorizationHeaderProvider: () => 'Bearer session-token',
      );

      await client.post(
        'reservations',
        headers: const <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer custom-token',
        },
      );

      expect(delegate.calls.length, 1);
      expect(
        delegate.calls.single.headers?[HttpHeaders.authorizationHeader],
        'Bearer custom-token',
      );
    },
  );

  test('AuthorizedApiClient ejecuta callback al recibir 401', () async {
    final _FakeApiClient delegate = _FakeApiClient()
      ..nextResponse = const ApiResponse(statusCode: 401, body: '{}');
    bool unauthorizedTriggered = false;
    final AuthorizedApiClient client = AuthorizedApiClient(
      delegate: delegate,
      authorizationHeaderProvider: () => 'Bearer signed-token',
      onUnauthorized: () {
        unauthorizedTriggered = true;
      },
    );

    final ApiResponse response = await client.get('reservations');

    expect(response.statusCode, 401);
    expect(unauthorizedTriggered, isTrue);
  });
}

final class _FakeApiClient implements ApiClient {
  final List<_Call> calls = <_Call>[];
  ApiResponse nextResponse = const ApiResponse(statusCode: 200, body: '{}');

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    calls.add(_Call(method: 'GET', path: path, headers: headers, body: null));
    return Future<ApiResponse>.value(nextResponse);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    calls.add(_Call(method: 'PATCH', path: path, headers: headers, body: body));
    return Future<ApiResponse>.value(nextResponse);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    calls.add(_Call(method: 'POST', path: path, headers: headers, body: body));
    return Future<ApiResponse>.value(nextResponse);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    calls.add(_Call(method: 'PUT', path: path, headers: headers, body: body));
    return Future<ApiResponse>.value(nextResponse);
  }
}

final class _Call {
  const _Call({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String>? headers;
  final String? body;
}
