import 'dart:async';
import 'dart:convert';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/user_management_app_service.dart';
import '../domain/user_management_models.dart';

final class HttpUserManagementAppService implements UserManagementAppService {
  HttpUserManagementAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<void> changeOwnPassword(ChangeOwnPasswordInput input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'users/me/password',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
  }

  @override
  Future<ManagedUser> createUser(CreateManagedUserInput input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'users',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ManagedUser.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<ManagedUser>> listUsers() async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('users', headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de usuarios.');
    }

    return decoded
        .map<ManagedUser>(
          (Object? item) => ManagedUser.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<void> resetPassword(
    int userId,
    ResetManagedUserPasswordInput input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'users/$userId/password',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
  }

  @override
  Future<ManagedUser> updateUser(int userId, UpdateManagedUserInput input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'users/$userId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ManagedUser.fromJson(_asMap(_tryDecode(response.body)));
  }

  Future<ApiResponse> _runRequest(
    Future<ApiResponse> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw StateError('Tempo esgotado ao conectar ao backend configurado.');
    } on FormatException catch (error) {
      throw StateError(
        'Resposta invalida do backend configurado: ${error.message}',
      );
    } on Exception {
      throw StateError(
        'Nao foi possivel conectar ao backend configurado. Verifique a URL e a conectividade.',
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
          return PtBrErrorTranslator.translate(asString);
        }
      }
    }
    return 'O backend configurado retornou HTTP ${response.statusCode}.';
  }

  static Object? _tryDecode(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return null;
    }
    return jsonDecode(rawBody);
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Era esperado um objeto JSON.');
    }
    return value.map<String, dynamic>(
      (Object? key, Object? mapValue) =>
          MapEntry<String, dynamic>(key.toString(), mapValue),
    );
  }
}
