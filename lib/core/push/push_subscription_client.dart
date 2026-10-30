import 'dart:convert';

import '../network/api_client.dart';

final class PushSubscriptionClient {
  const PushSubscriptionClient();

  Future<void> register({
    required ApiClient apiClient,
    required String authorizationHeader,
    required String installationId,
    required String platform,
  }) async {
    await _expectSuccess(
      apiClient.post(
        'push/subscriptions',
        headers: <String, String>{
          'Authorization': authorizationHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object>{
          'installationId': installationId,
          'platform': platform,
          'provider': 'FIREBASE',
          'token': installationId,
        }),
      ),
    );
  }

  Future<void> heartbeat({
    required ApiClient apiClient,
    required String authorizationHeader,
    required String installationId,
  }) async {
    await _expectSuccess(
      apiClient.patch(
        'push/subscriptions/$installationId/heartbeat',
        headers: <String, String>{'Authorization': authorizationHeader},
      ),
      allowNotFound: true,
    );
  }

  Future<void> unregister({
    required ApiClient apiClient,
    required String authorizationHeader,
    required String installationId,
  }) async {
    await _expectSuccess(
      apiClient.delete(
        'push/subscriptions/$installationId',
        headers: <String, String>{'Authorization': authorizationHeader},
      ),
      allowNotFound: true,
    );
  }

  Future<void> _expectSuccess(
    Future<ApiResponse> request, {
    bool allowNotFound = false,
  }) async {
    final ApiResponse response = await request;
    if (!response.isSuccess && !(allowNotFound && response.statusCode == 404)) {
      throw StateError('Falha ao sincronizar a instalacao push.');
    }
  }
}
