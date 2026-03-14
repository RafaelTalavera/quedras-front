import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/network/api_client.dart';
import '../application/auth_app_service.dart';
import '../domain/auth_session.dart';

final class HttpAuthAppService implements AuthAppService {
  HttpAuthAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'auth/login',
        headers: _jsonHeaders,
        body: jsonEncode(<String, String>{
          'username': username.trim(),
          'password': password,
        }),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Formato invalido al autenticar contra backend local.');
    }

    try {
      return AuthSession.fromJson(
        decoded.map<String, dynamic>(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
      );
    } on FormatException catch (error) {
      throw StateError(
        'Formato invalido al autenticar contra backend local: ${error.message}',
      );
    }
  }

  Future<ApiResponse> _runRequest(
    Future<ApiResponse> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw StateError(
        'No fue posible conectar con el backend local. Verifique servidor y red interna.',
      );
    } on TimeoutException {
      throw StateError('Timeout al conectar con el backend local.');
    } on HttpException {
      throw StateError(
        'Error HTTP de transporte al autenticar con backend local.',
      );
    } on FormatException catch (error) {
      throw StateError(
        'Respuesta invalida del backend local: ${error.message}',
      );
    }
  }

  static String _extractApiErrorMessage(ApiResponse response) {
    final Object? decoded = _tryDecode(response.body);
    if (decoded is Map) {
      final Object? message = decoded['message'];
      if (message != null) {
        final String asString = message.toString().trim();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }
    return 'Backend local devolvio HTTP ${response.statusCode}.';
  }

  static Object? _tryDecode(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return null;
    }
    return jsonDecode(rawBody);
  }
}
