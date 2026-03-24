import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/localization/pt_br_error_translator.dart';
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
      throw StateError('Formato inv\u00e1lido ao autenticar no backend local.');
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
        'Formato inv\u00e1lido ao autenticar no backend local: ${error.message}',
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
        'N\u00e3o foi poss\u00edvel conectar ao backend local. Verifique o servidor e a rede interna.',
      );
    } on TimeoutException {
      throw StateError('Tempo esgotado ao conectar ao backend local.');
    } on HttpException {
      throw StateError(
        'Erro HTTP de transporte ao autenticar no backend local.',
      );
    } on FormatException catch (error) {
      throw StateError('Resposta inv\u00e1lida do backend local: ${error.message}');
    }
  }

  static String _extractApiErrorMessage(ApiResponse response) {
    final Object? decoded = _tryDecode(response.body);
    if (decoded is Map) {
      final Object? message = decoded['message'];
      if (message != null) {
        final String asString = message.toString().trim();
        if (asString.isNotEmpty) {
          return PtBrErrorTranslator.translate(asString);
        }
      }
    }
    return 'O backend local retornou HTTP ${response.statusCode}.';
  }

  static Object? _tryDecode(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return null;
    }
    return jsonDecode(rawBody);
  }
}
