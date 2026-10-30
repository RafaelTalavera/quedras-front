import 'dart:convert';

import 'package:costanorte/core/network/api_client.dart';
import 'package:costanorte/core/push/push_subscription_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sincroniza alta, heartbeat y baja con contrato autenticado', () async {
    final _RecordingApiClient apiClient = _RecordingApiClient();
    const PushSubscriptionClient client = PushSubscriptionClient();

    await client.register(
      apiClient: apiClient,
      authorizationHeader: 'Bearer jwt',
      installationId: 'firebase-installation-id-001',
      platform: 'WEB',
    );
    await client.heartbeat(
      apiClient: apiClient,
      authorizationHeader: 'Bearer jwt',
      installationId: 'firebase-installation-id-001',
    );
    await client.unregister(
      apiClient: apiClient,
      authorizationHeader: 'Bearer jwt',
      installationId: 'firebase-installation-id-001',
    );

    expect(
      apiClient.calls.map((_Call call) => '${call.method} ${call.path}'),
      <String>[
        'POST push/subscriptions',
        'PATCH push/subscriptions/firebase-installation-id-001/heartbeat',
        'DELETE push/subscriptions/firebase-installation-id-001',
      ],
    );
    final Map<String, Object?> payload =
        jsonDecode(apiClient.calls.first.body!) as Map<String, Object?>;
    expect(payload, <String, Object?>{
      'installationId': 'firebase-installation-id-001',
      'platform': 'WEB',
      'provider': 'FIREBASE',
      'token': 'firebase-installation-id-001',
    });
    expect(apiClient.calls.first.headers?['Authorization'], 'Bearer jwt');
  });

  test('acepta baja repetida cuando backend responde 404', () async {
    final _RecordingApiClient apiClient = _RecordingApiClient(statusCode: 404);

    await const PushSubscriptionClient().unregister(
      apiClient: apiClient,
      authorizationHeader: 'Bearer jwt',
      installationId: 'firebase-installation-id-001',
    );
  });

  test('propaga falla de registro para permitir reintento posterior', () async {
    final _RecordingApiClient apiClient = _RecordingApiClient(statusCode: 503);

    expect(
      () => const PushSubscriptionClient().register(
        apiClient: apiClient,
        authorizationHeader: 'Bearer jwt',
        installationId: 'firebase-installation-id-001',
        platform: 'WEB',
      ),
      throwsStateError,
    );
  });
}

final class _RecordingApiClient implements ApiClient {
  _RecordingApiClient({this.statusCode = 204});

  final int statusCode;
  final List<_Call> calls = <_Call>[];

  ApiResponse _response(
    String method,
    String path,
    Map<String, String>? headers,
    String? body,
  ) {
    calls.add(_Call(method, path, headers, body));
    return ApiResponse(statusCode: statusCode, body: '');
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async => _response('DELETE', path, headers, null);

  @override
  Future<ApiResponse> get(String path, {Map<String, String>? headers}) async =>
      _response('GET', path, headers, null);

  @override
  Future<ApiResponse> patch(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async => _response('PATCH', path, headers, body);

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async => _response('POST', path, headers, body);

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async => _response('PUT', path, headers, body);
}

final class _Call {
  const _Call(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, String>? headers;
  final String? body;
}
