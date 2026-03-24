import 'dart:convert';
import 'dart:io';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/features/auth/infrastructure/http_auth_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HttpAuthAppService autentica y parsea la sesion JWT', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"accessToken":"jwt-token","tokenType":"Bearer","expiresInSeconds":1800,"username":"operador.demo","role":"OPERATOR"}',
        ),
      );
    final HttpAuthAppService service = HttpAuthAppService(apiClient: client);

    final session = await service.login(
      username: 'operador.demo',
      password: 'Costanorte2026!',
    );

    expect(session.accessToken, 'jwt-token');
    expect(session.authorizationHeader, 'Bearer jwt-token');
    expect(session.role, 'OPERATOR');
    expect(client.calls.length, 1);
    expect(client.calls.single.method, 'POST');
    expect(client.calls.single.path, 'auth/login');
    expect(
      client.calls.single.headers?[HttpHeaders.contentTypeHeader],
      'application/json',
    );
    expect(
      jsonDecode(client.calls.single.body!) as Map<String, dynamic>,
      <String, dynamic>{
        'username': 'operador.demo',
        'password': 'Costanorte2026!',
      },
    );
  });

  test('HttpAuthAppService traduz mensagem de credenciais invalidas', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 401,
          body: '{"message":"Invalid username or password."}',
        ),
      );
    final HttpAuthAppService service = HttpAuthAppService(apiClient: client);

    await expectLater(
      () => service.login(username: 'operador.demo', password: 'incorrecta'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Usu\u00e1rio ou senha inv\u00e1lidos.',
        ),
      ),
    );
  });

  test('HttpAuthAppService rejeita payload invalido do backend', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          body:
              '{"accessToken":"","tokenType":"Bearer","expiresInSeconds":0,"username":"","role":""}',
        ),
      );
    final HttpAuthAppService service = HttpAuthAppService(apiClient: client);

    await expectLater(
      () =>
          service.login(username: 'operador.demo', password: 'Costanorte2026!'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'Formato inv\u00e1lido ao autenticar no backend local: accessToken is required',
        ),
      ),
    );
  });

  test('HttpAuthAppService transforma fallas de red local', () async {
    final _FakeApiClient client = _FakeApiClient()
      ..nextError = const SocketException('Connection refused');
    final HttpAuthAppService service = HttpAuthAppService(apiClient: client);

    await expectLater(
      () =>
          service.login(username: 'operador.demo', password: 'Costanorte2026!'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message.toString(),
          'message',
          'N\u00e3o foi poss\u00edvel conectar ao backend local. Verifique o servidor e a rede interna.',
        ),
      ),
    );
  });
}

final class _FakeApiClient implements ApiClient {
  final List<_Call> calls = <_Call>[];
  final List<ApiResponse> _responses = <ApiResponse>[];
  Object? nextError;

  void enqueue(ApiResponse response) {
    _responses.add(response);
  }

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) {
    return _consume('GET', path, headers: headers);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PATCH', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('POST', path, headers: headers, body: body);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return _consume('PUT', path, headers: headers, body: body);
  }

  Future<ApiResponse> _consume(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    calls.add(_Call(method: method, path: path, headers: headers, body: body));
    final Object? queuedError = nextError;
    if (queuedError != null) {
      nextError = null;
      throw queuedError;
    }
    if (_responses.isEmpty) {
      return const ApiResponse(statusCode: 500, body: '{}');
    }
    return _responses.removeAt(0);
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
