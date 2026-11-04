import 'dart:async';
import 'dart:convert';

import '../../../core/audit/audit_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../application/laundry_app_service.dart';
import '../domain/laundry_models.dart';

final class HttpLaundryAppService implements LaundryAppService {
  HttpLaundryAppService({required ApiClient apiClient})
    : _apiClient = apiClient;
  final ApiClient _apiClient;
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  static const String _base = 'laundry';

  @override
  Future<List<LaundryProvider>> listProviders() =>
      _getList('$_base/providers', LaundryProvider.fromJson);

  @override
  Future<LaundryProvider> createProvider(
    CreateLaundryProviderRequest request,
  ) async {
    const String path = '$_base/providers';
    final ApiResponse response = await _run(
      'POST',
      path,
      () => _apiClient.post(
        path,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return LaundryProvider.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<LaundryProvider> updateProvider(
    int id,
    CreateLaundryProviderRequest request,
  ) async {
    final String path = '$_base/providers/$id';
    final ApiResponse response = await _run(
      'PUT',
      path,
      () => _apiClient.put(
        path,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return LaundryProvider.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<List<LaundryItem>> listItems() =>
      _getList('$_base/items', LaundryItem.fromJson);

  @override
  Future<LaundryItem> createItem(LaundryItem item) async {
    const String path = '$_base/items';
    final ApiResponse response = await _run(
      'POST',
      path,
      () => _apiClient.post(
        path,
        headers: _headers,
        body: jsonEncode(item.toJson()),
      ),
    );
    return LaundryItem.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<LaundryItem> updateItem(int id, LaundryItem item) async {
    final String path = '$_base/items/$id';
    final ApiResponse response = await _run(
      'PUT',
      path,
      () => _apiClient.put(
        path,
        headers: _headers,
        body: jsonEncode(item.toJson()),
      ),
    );
    return LaundryItem.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<LaundryShipment> createShipment(
    CreateLaundryShipmentRequest request,
  ) async {
    const String path = '$_base/shipments';
    final ApiResponse response = await _run(
      'POST',
      path,
      () => _apiClient.post(
        path,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return LaundryShipment.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<List<LaundryShipment>> listShipments({
    LaundryShipmentStatus? status,
    int? providerId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final Map<String, String> query = <String, String>{
      if (status != null) 'status': status.apiValue,
      if (providerId != null) 'providerId': '$providerId',
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
    };
    final String path = query.isEmpty
        ? '$_base/shipments'
        : '$_base/shipments?${Uri(queryParameters: query).query}';
    return _getList(path, LaundryShipment.fromJson);
  }

  @override
  Future<LaundryShipment> getShipment(int id) async {
    final String path = '$_base/shipments/$id';
    final ApiResponse response = await _run(
      'GET',
      path,
      () => _apiClient.get(path, headers: _headers),
    );
    return LaundryShipment.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<ReceiveLaundryShipmentResult> receiveShipment(
    int id,
    ReceiveLaundryShipmentRequest request,
  ) async {
    final String path = '$_base/shipments/$id/receive';
    final ApiResponse response = await _run(
      'POST',
      path,
      () => _apiClient.post(
        path,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return ReceiveLaundryShipmentResult.fromJson(
      _asMap(_decode(response.body)),
    );
  }

  @override
  Future<LaundryShipment> dispatchShipment(
    int id,
    DispatchLaundryShipmentRequest request,
  ) async {
    final String path = '$_base/shipments/$id/dispatch';
    final ApiResponse response = await _run(
      'POST',
      path,
      () => _apiClient.post(
        path,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return LaundryShipment.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<LaundryShipment> cancelShipment(
    int id,
    String cancellationNotes,
  ) async {
    final String path = '$_base/shipments/$id/cancel';
    final ApiResponse response = await _run(
      'PATCH',
      path,
      () => _apiClient.patch(
        path,
        headers: _headers,
        body: jsonEncode(<String, String>{
          'cancellationNotes': cancellationNotes.trim(),
        }),
      ),
    );
    return LaundryShipment.fromJson(_asMap(_decode(response.body)));
  }

  @override
  Future<List<AuditEventModel>> shipmentAudit(int id) =>
      _getList('$_base/shipments/$id/audit', AuditEventModel.fromJson);

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final ApiResponse response = await _run(
      'GET',
      path,
      () => _apiClient.get(path, headers: _headers),
    );
    final Object? decoded = _decode(response.body);
    if (decoded is! List) {
      throw const ApiException(
        'Formato de resposta inválido.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return decoded.map<T>((Object? item) => parse(_asMap(item))).toList();
  }

  Future<ApiResponse> _run(
    String method,
    String path,
    Future<ApiResponse> Function() request,
  ) async {
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
      return response;
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

  static String _message(ApiResponse response) {
    try {
      final Object? decoded = _decode(response.body);
      if (decoded is Map &&
          decoded['message'] is String &&
          (decoded['message'] as String).trim().isNotEmpty) {
        return (decoded['message'] as String).trim();
      }
    } on FormatException {
      /* fallback */
    }
    switch (response.statusCode) {
      case 403:
        return 'Você não tem autorização para esta operação.';
      case 404:
        return 'A remessa não existe mais.';
      case 409:
        return 'Outra operação modificou a remessa. Os dados serão recarregados.';
      default:
        return response.statusCode >= 500
            ? 'O servidor não conseguiu concluir a operação.'
            : 'Não foi possível concluir a operação.';
    }
  }

  static Object? _decode(String body) =>
      body.trim().isEmpty ? null : jsonDecode(body);
  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Era esperado um objeto JSON.');
    }
    return value.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
}
