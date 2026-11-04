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
    'Content-Type': 'application/json',
  };
  static int _commandSequence = 0;

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryDocumentSummary>>
  listDocuments({int page = 0, int size = 20}) => _getPage(
    'provider/documents?page=$page&size=$size',
    ProviderLaundryDocumentSummary.fromJson,
  );

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryReturnSummary>> listReturns({
    int page = 0,
    int size = 20,
  }) => _getPage(
    'provider/returns?page=$page&size=$size',
    ProviderLaundryReturnSummary.fromJson,
  );

  @override
  Future<ProviderLaundryResultPage<ProviderLaundryStockRow>> listStock({
    required ProviderLaundryStockBucket bucket,
    int page = 0,
    int size = 50,
  }) => _getPage(
    'provider/stock?bucket=${bucket.apiValue}&page=$page&size=$size',
    ProviderLaundryStockRow.fromJson,
  );

  @override
  Future<ProviderLaundryDocument> getDocument(int id) =>
      _getObject('documents/$id', ProviderLaundryDocument.fromJson);

  @override
  Future<ProviderLaundryDocument> acknowledgeDocument({
    required int id,
    required int version,
    String? notes,
  }) => _postObject('dispatches/$id/acknowledgements', <String, Object?>{
    'version': version,
    'notes': _trimmedOrNull(notes),
  }, ProviderLaundryDocument.fromJson);

  @override
  Future<ProviderLaundryDocument> observeDocument({
    required int id,
    required int version,
    required String notes,
  }) {
    final String normalizedNotes = notes.trim();
    if (normalizedNotes.isEmpty) {
      throw ArgumentError.value(notes, 'notes', 'must not be blank');
    }
    if (normalizedNotes.length > 500) {
      throw ArgumentError.value(notes, 'notes', 'must not exceed 500 chars');
    }
    return _postObject('documents/$id/observations', <String, Object?>{
      'version': version,
      'notes': normalizedNotes,
    }, ProviderLaundryDocument.fromJson);
  }

  @override
  Future<ProviderLaundryReturn> getReturn(int id) =>
      _getObject('returns/$id', ProviderLaundryReturn.fromJson);

  @override
  Future<ProviderLaundryReturn> createReturn(
    ProviderLaundryReturnInput input,
  ) => _postObject('returns', input.toJson(), ProviderLaundryReturn.fromJson);

  @override
  Future<ProviderLaundryReturn> updateReturn({
    required int id,
    required ProviderLaundryReturnInput input,
  }) =>
      _putObject('returns/$id', input.toJson(), ProviderLaundryReturn.fromJson);

  @override
  Future<ProviderLaundryReturn> submitReturn({
    required int id,
    required int version,
  }) => _postObject('returns/$id/submit', <String, Object?>{
    'version': version,
  }, ProviderLaundryReturn.fromJson);

  Future<T> _getObject<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
  ) => _objectRequest(
    method: 'GET',
    path: path,
    request: () => _apiClient.get(path, headers: _headers),
    parser: parser,
  );

  Future<T> _postObject<T>(
    String path,
    Map<String, Object?> body,
    T Function(Map<String, dynamic>) parser,
  ) {
    final Map<String, String> headers = <String, String>{
      ..._headers,
      'Idempotency-Key': _nextIdempotencyKey(),
    };
    return _objectRequest(
      method: 'POST',
      path: path,
      request: () =>
          _apiClient.post(path, headers: headers, body: jsonEncode(body)),
      parser: parser,
    );
  }

  Future<T> _putObject<T>(
    String path,
    Map<String, Object?> body,
    T Function(Map<String, dynamic>) parser,
  ) {
    final Map<String, String> headers = <String, String>{
      ..._headers,
      'Idempotency-Key': _nextIdempotencyKey(),
    };
    return _objectRequest(
      method: 'PUT',
      path: path,
      request: () =>
          _apiClient.put(path, headers: headers, body: jsonEncode(body)),
      parser: parser,
    );
  }

  Future<T> _objectRequest<T>({
    required String method,
    required String path,
    required Future<ApiResponse> Function() request,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      final ApiResponse response = await request();
      if (!response.isSuccess) {
        throw ApiException(
          _message(response),
          kind: ApiErrorKind.http,
          statusCode: response.statusCode,
          method: method,
          path: path,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException('object expected');
      return parser(
        decoded.map<String, dynamic>(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        'Tempo esgotado ao conectar com o servidor.',
        kind: ApiErrorKind.timeout,
        method: method,
        path: path,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Resposta inválida do servidor.',
        kind: ApiErrorKind.invalidResponse,
        method: method,
        path: path,
        cause: error,
      );
    } on Exception catch (error) {
      throw ApiException(
        'Não foi possível conectar ao servidor.',
        kind: ApiErrorKind.network,
        method: method,
        path: path,
        cause: error,
      );
    }
  }

  Future<ProviderLaundryResultPage<T>> _getPage<T>(
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

  static String _nextIdempotencyKey() {
    _commandSequence++;
    return 'flutter-provider-${DateTime.now().microsecondsSinceEpoch}-$_commandSequence';
  }

  static String? _trimmedOrNull(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
