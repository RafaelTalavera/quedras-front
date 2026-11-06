import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../application/hotel_laundry_app_service.dart';
import '../domain/hotel_laundry_models.dart';
import '../domain/laundry_models.dart';
import '../domain/provider_laundry_models.dart';

final class HttpHotelLaundryAppService implements HotelLaundryAppService {
  HttpHotelLaundryAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  static int _commandSequence = 0;

  @override
  Future<List<LaundryProvider>> listProviders() =>
      _getList('providers', LaundryProvider.fromJson);

  @override
  Future<LaundryProvider> createProvider(
    CreateLaundryProviderRequest request,
  ) => _saveProvider('POST', 'providers', request);

  @override
  Future<LaundryProvider> updateProvider(
    int id,
    CreateLaundryProviderRequest request,
  ) => _saveProvider('PUT', 'providers/$id', request);

  @override
  Future<List<LaundryItem>> listItems() =>
      _getList('items', LaundryItem.fromJson);

  Future<LaundryProvider> _saveProvider(
    String method,
    String path,
    CreateLaundryProviderRequest request,
  ) async => LaundryProvider.fromJson(
    await _request(
      method: method,
      path: path,
      request: () => method == 'POST'
          ? _apiClient.post(
              path,
              headers: _headers,
              body: jsonEncode(request.toJson()),
            )
          : _apiClient.put(
              path,
              headers: _headers,
              body: jsonEncode(request.toJson()),
            ),
    ),
  );

  @override
  Future<HotelLaundryStockTotals> dashboard({int? providerId}) async {
    final String path = _query('dashboard', <String, Object?>{
      'providerId': providerId,
    });
    final Map<String, dynamic> json = await _getObject(path);
    return HotelLaundryStockTotals.fromJson(_map(json['totals']));
  }

  @override
  Future<List<HotelLaundryOperationalDailyRow>> operationalSummary() =>
      _getList('operational-summary', HotelLaundryOperationalDailyRow.fromJson);

  @override
  Future<List<HotelLaundryInventoryMovement>> listInventoryMovements({
    required DateTime date,
  }) => _getList(
    _query('inventory/movements', <String, Object?>{'date': _dateOnly(date)}),
    HotelLaundryInventoryMovement.fromJson,
  );

  @override
  Future<HotelLaundryStockRow?> getAvailableStock({required int itemId}) async {
    final HotelLaundryResultPage<HotelLaundryStockRow> page =
        await _getPage<HotelLaundryStockRow>(
          _query('stock', <String, Object?>{
            'itemId': itemId,
            'bucket': 'HOTEL_AVAILABLE',
            'page': 0,
            'size': 1,
          }),
          HotelLaundryStockRow.fromJson,
        );
    return page.items.firstOrNull;
  }

  @override
  Future<void> createOpeningStock(HotelLaundryOpeningStockInput input) async {
    await _postObject<Map<String, dynamic>>(
      'opening-stock',
      input.toJson(),
      (Map<String, dynamic> json) => json,
    );
  }

  @override
  Future<void> retireInventoryItem(
    HotelLaundryItemRetirementInput input,
  ) async {
    await _postObject<Map<String, dynamic>>(
      'inventory/items/${input.itemId}/retire',
      input.toJson(),
      (Map<String, dynamic> json) => json,
    );
  }

  @override
  Future<void> createManualReturn(HotelLaundryManualReturnInput input) async {
    await _postObject<Map<String, dynamic>>(
      'returns/manual',
      input.toJson(),
      (Map<String, dynamic> json) => json,
    );
  }

  @override
  Future<HotelLaundryResultPage<HotelLaundryDocumentSummary>> listDocuments({
    int? providerId,
    String? status,
    String? documentType,
    int page = 0,
    int size = 20,
  }) => _getPage(
    _query('documents', <String, Object?>{
      'providerId': providerId,
      'status': status,
      'type': documentType,
      'page': page,
      'size': size,
    }),
    HotelLaundryDocumentSummary.fromJson,
  );

  @override
  Future<HotelLaundryResultPage<HotelLaundryReturnSummary>> listReturns({
    int? providerId,
    String? status,
    int page = 0,
    int size = 20,
  }) => _getPage(
    _query('returns', <String, Object?>{
      'providerId': providerId,
      'status': status,
      'page': page,
      'size': size,
    }),
    HotelLaundryReturnSummary.fromJson,
  );

  @override
  Future<HotelLaundryDocumentSummary> createDispatch({
    required HotelLaundryDispatchInput input,
    required bool rewash,
  }) => _postObject(
    rewash ? 'rewash-dispatches' : 'dispatches',
    input.toJson(),
    HotelLaundryDocumentSummary.fromJson,
  );

  @override
  Future<HotelLaundryDocumentSummary> submitDocument({
    required int id,
    required int version,
  }) => _postObject('documents/$id/submit', <String, Object>{
    'version': version,
  }, HotelLaundryDocumentSummary.fromJson);

  @override
  Future<ProviderLaundryReturn> getReturn(int id) async =>
      parseHotelLaundryReturn(await _getObject('returns/$id'));

  @override
  Future<ProviderLaundryReturn> confirmReturn({
    required int id,
    required HotelLaundryReturnConfirmationInput input,
  }) => _postObject(
    'returns/$id/confirm',
    input.toJson(),
    parseHotelLaundryReturn,
  );

  Future<HotelLaundryResultPage<T>> _getPage<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
  ) async => parseHotelLaundryPage<T>(await _getObject(path), parser);

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
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
      if (decoded is! List) throw const FormatException('list expected');
      return decoded.map<T>((Object? item) => parser(_map(item))).toList();
    } on ApiException {
      rethrow;
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

  Future<Map<String, dynamic>> _getObject(String path) => _request(
    method: 'GET',
    path: path,
    request: () => _apiClient.get(path, headers: _headers),
  );

  Future<T> _postObject<T>(
    String path,
    Map<String, Object?> body,
    T Function(Map<String, dynamic>) parser,
  ) async => parser(
    await _request(
      method: 'POST',
      path: path,
      request: () => _apiClient.post(
        path,
        headers: <String, String>{
          ..._headers,
          'Idempotency-Key': _nextIdempotencyKey(),
        },
        body: jsonEncode(body),
      ),
    ),
  );

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    required Future<ApiResponse> Function() request,
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
      return _map(jsonDecode(response.body));
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

  static String _query(String path, Map<String, Object?> values) {
    final Map<String, String> query = <String, String>{
      for (final MapEntry<String, Object?> entry in values.entries)
        if (entry.value != null && entry.value.toString().trim().isNotEmpty)
          entry.key: entry.value.toString(),
    };
    return query.isEmpty ? path : '$path?${Uri(queryParameters: query).query}';
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const FormatException('object expected');
    return raw.map<String, dynamic>(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
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
    return response.statusCode == 409
        ? 'Os dados foram modificados. Atualize e tente novamente.'
        : 'Não foi possível concluir a operação.';
  }

  static String _nextIdempotencyKey() {
    _commandSequence++;
    return 'flutter-hotel-${DateTime.now().microsecondsSinceEpoch}-$_commandSequence';
  }

  static String _dateOnly(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
