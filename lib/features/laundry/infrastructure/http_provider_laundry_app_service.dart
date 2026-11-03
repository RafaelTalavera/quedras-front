import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../application/provider_laundry_app_service.dart';
import '../domain/provider_laundry_models.dart';

final class HttpProviderLaundryAppService implements ProviderLaundryAppService {
  HttpProviderLaundryAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
  };

  @override
  Future<ProviderLaundryPage<ProviderLaundryDocumentSummary>> listDocuments({
    int page = 0,
    int size = 20,
  }) => _getPage(
    'provider/documents?page=$page&size=$size',
    ProviderLaundryDocumentSummary.fromJson,
  );

  @override
  Future<ProviderLaundryPage<ProviderLaundryReturnSummary>> listReturns({
    int page = 0,
    int size = 20,
  }) => _getPage(
    'provider/returns?page=$page&size=$size',
    ProviderLaundryReturnSummary.fromJson,
  );

  @override
  Future<ProviderLaundryPage<ProviderLaundryStockRow>> listStock({
    required ProviderLaundryStockBucket bucket,
    int page = 0,
    int size = 50,
  }) => _getPage(
    'provider/stock?bucket=${bucket.apiValue}&page=$page&size=$size',
    ProviderLaundryStockRow.fromJson,
  );

  Future<ProviderLaundryPage<T>> _getPage<T>(
    String path,
    T Function(Map<String, dynamic>) parseItem,
  ) async {
    try {
      final ApiResponse response = await _apiClient.get(
        path,
        headers: _headers,
      );
      if (!response.isSuccess) {
        throw ApiException(
          _message(response),
          kind: ApiErrorKind.http,
          statusCode: response.statusCode,
          method: 'GET',
          path: path,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('page must be an object');
      }
      return parseProviderLaundryPage<T>(
        decoded.map<String, dynamic>(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
        parseItem,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        'Tempo esgotado ao conectar com o servidor.',
        kind: ApiErrorKind.timeout,
        method: 'GET',
        path: path,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Resposta inválida do servidor.',
        kind: ApiErrorKind.invalidResponse,
        method: 'GET',
        path: path,
        cause: error,
      );
    } on Exception catch (error) {
      throw ApiException(
        'Não foi possível conectar ao servidor.',
        kind: ApiErrorKind.network,
        method: 'GET',
        path: path,
        cause: error,
      );
    }
  }

  static String _message(ApiResponse response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        final String message = (decoded['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
    } on FormatException {
      // Use the status fallback below.
    }
    return response.statusCode == 403
        ? 'Você não tem autorização para consultar a lavanderia.'
        : 'Não foi possível consultar a lavanderia.';
  }
}
