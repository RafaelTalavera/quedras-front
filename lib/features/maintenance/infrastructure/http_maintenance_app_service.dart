import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/maintenance_app_service.dart';
import '../domain/maintenance_models.dart';

final class HttpMaintenanceAppService implements MaintenanceAppService {
  HttpMaintenanceAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<List<MaintenanceLocation>> listLocations() async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('maintenance/locations', headers: _jsonHeaders),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido da lista de locais de manutencao.',
    );
    return (decoded as List)
        .map<MaintenanceLocation>(
          (Object? item) => MaintenanceLocation.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MaintenanceLocation> createLocation(
    CreateMaintenanceLocationModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'maintenance/locations',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceLocation.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida do local.'),
    );
  }

  @override
  Future<MaintenanceLocation> updateLocation(
    int locationId,
    UpdateMaintenanceLocationModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'maintenance/locations/$locationId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceLocation.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida do local.'),
    );
  }

  @override
  Future<List<MaintenanceOrder>> getLocationHistory(int locationId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'maintenance/locations/$locationId/history',
        headers: _jsonHeaders,
      ),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido do historico de manutencao.',
    );
    return (decoded as List)
        .map<MaintenanceOrder>(
          (Object? item) => MaintenanceOrder.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<List<MaintenanceProvider>> listProviders() async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('maintenance/providers', headers: _jsonHeaders),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido da lista de responsaveis.',
    );
    return (decoded as List)
        .map<MaintenanceProvider>(
          (Object? item) => MaintenanceProvider.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MaintenanceProvider> createProvider(
    CreateMaintenanceProviderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'maintenance/providers',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceProvider.fromJson(
      _expectSuccessObject(
        response,
        invalidMessage: 'Resposta invalida do responsavel.',
      ),
    );
  }

  @override
  Future<MaintenanceProvider> updateProvider(
    int providerId,
    UpdateMaintenanceProviderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'maintenance/providers/$providerId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceProvider.fromJson(
      _expectSuccessObject(
        response,
        invalidMessage: 'Resposta invalida do responsavel.',
      ),
    );
  }

  @override
  Future<List<MaintenanceOrder>> listOrders({
    String? dateFrom,
    String? dateTo,
    int? locationId,
    int? providerId,
    MaintenanceProviderType? providerType,
    MaintenanceOrderStatus? status,
    MaintenancePriority? priority,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) {
      query['dateFrom'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      query['dateTo'] = dateTo;
    }
    if (locationId != null) {
      query['locationId'] = '$locationId';
    }
    if (providerId != null) {
      query['providerId'] = '$providerId';
    }
    if (providerType != null) {
      query['providerType'] = providerType.apiValue;
    }
    if (status != null) {
      query['status'] = status.apiValue;
    }
    if (priority != null) {
      query['priority'] = priority.apiValue;
    }
    final String path = query.isEmpty
        ? 'maintenance/orders'
        : 'maintenance/orders?${Uri(queryParameters: query).query}';
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido da lista de ordens de manutencao.',
    );
    return (decoded as List)
        .map<MaintenanceOrder>(
          (Object? item) => MaintenanceOrder.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MaintenanceOrder> createOrder(CreateMaintenanceOrderModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'maintenance/orders',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceOrder.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida da ordem.'),
    );
  }

  @override
  Future<MaintenanceOrder> updateOrder(
    int orderId,
    UpdateMaintenanceOrderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'maintenance/orders/$orderId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceOrder.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida da ordem.'),
    );
  }

  @override
  Future<List<MaintenanceConflict>> findConflicts({
    required int locationId,
    required String scheduledStartAt,
    required String scheduledEndAt,
    int? excludeOrderId,
  }) async {
    final Map<String, String> query = <String, String>{
      'locationId': '$locationId',
      'scheduledStartAt': scheduledStartAt,
      'scheduledEndAt': scheduledEndAt,
      if (excludeOrderId != null) 'excludeOrderId': '$excludeOrderId',
    };
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'maintenance/orders/conflicts?${Uri(queryParameters: query).query}',
        headers: _jsonHeaders,
      ),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido da lista de conflitos.',
    );
    return (decoded as List)
        .map<MaintenanceConflict>(
          (Object? item) => MaintenanceConflict.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MaintenanceOrder> startOrder(
    int orderId, {
    StartMaintenanceOrderModel? input,
  }) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'maintenance/orders/$orderId/start',
        headers: _jsonHeaders,
        body: jsonEncode((input ?? const StartMaintenanceOrderModel()).toJson()),
      ),
    );
    return MaintenanceOrder.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida da ordem.'),
    );
  }

  @override
  Future<MaintenanceOrder> completeOrder(
    int orderId,
    CompleteMaintenanceOrderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'maintenance/orders/$orderId/complete',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceOrder.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida da ordem.'),
    );
  }

  @override
  Future<MaintenanceOrder> cancelOrder(
    int orderId,
    CancelMaintenanceOrderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'maintenance/orders/$orderId/cancel',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceOrder.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida da ordem.'),
    );
  }

  @override
  Future<List<MaintenanceOrderAttachment>> listAttachments(int orderId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'maintenance/orders/$orderId/attachments',
        headers: _jsonHeaders,
      ),
    );
    final Object? decoded = _expectSuccessList(
      response,
      invalidMessage: 'Formato invalido da lista de anexos.',
    );
    return (decoded as List)
        .map<MaintenanceOrderAttachment>(
          (Object? item) => MaintenanceOrderAttachment.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MaintenanceOrderAttachment> addAttachment(
    int orderId,
    AddMaintenanceAttachmentModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'maintenance/orders/$orderId/attachments',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return MaintenanceOrderAttachment.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resposta invalida do anexo.'),
    );
  }

  @override
  Future<void> deleteAttachment(int orderId, int attachmentId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.delete(
        'maintenance/orders/$orderId/attachments/$attachmentId',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
  }

  @override
  Future<MaintenanceSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{'dateFrom': dateFrom, 'dateTo': dateTo},
    ).query;
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'maintenance/reports/summary?$query',
        headers: _jsonHeaders,
      ),
    );
    return MaintenanceSummaryReport.fromJson(
      _expectSuccessObject(response, invalidMessage: 'Resumo invalido de manutencao.'),
    );
  }

  @override
  Future<MaintenanceSummaryDetail> getSummaryDetails({
    required MaintenanceSummaryGroupBy groupBy,
    required String code,
    required String dateFrom,
    required String dateTo,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{
        'groupBy': groupBy.apiValue,
        'code': code,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    ).query;
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'maintenance/reports/summary/details?$query',
        headers: _jsonHeaders,
      ),
    );
    return MaintenanceSummaryDetail.fromJson(
      _expectSuccessObject(
        response,
        invalidMessage: 'Detalhe invalido do resumo de manutencao.',
      ),
    );
  }

  Future<ApiResponse> _runRequest(
    Future<ApiResponse> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw StateError(
        'Nao foi possivel conectar ao backend local. Verifique o servidor e a rede interna.',
      );
    } on TimeoutException {
      throw StateError('Tempo esgotado ao conectar ao backend local.');
    } on HttpException {
      throw StateError('Erro HTTP de transporte ao consultar o backend local.');
    } on FormatException catch (error) {
      throw StateError('Resposta invalida do backend local: ${error.message}');
    }
  }

  Object? _expectSuccessList(
    ApiResponse response, {
    required String invalidMessage,
  }) {
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError(invalidMessage);
    }
    return decoded;
  }

  Map<String, dynamic> _expectSuccessObject(
    ApiResponse response, {
    required String invalidMessage,
  }) {
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw StateError(invalidMessage);
    }
    return _asMap(decoded);
  }

  String _extractApiErrorMessage(ApiResponse response) {
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
