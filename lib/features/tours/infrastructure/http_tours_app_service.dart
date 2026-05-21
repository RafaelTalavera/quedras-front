import 'dart:async';
import 'dart:convert';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../application/tours_app_service.dart';
import '../domain/tours_models.dart';

final class HttpToursAppService implements ToursAppService {
  HttpToursAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<ToursSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{'dateFrom': dateFrom, 'dateTo': dateTo},
    ).query;
    final String path = 'tours/reports/summary?$query';
    final ApiResponse response = await _runRequest(
      method: 'GET',
      path: path,
      request: () => _apiClient.get(path, headers: _jsonHeaders),
    );

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw const ApiException(
        'Formato invalido do resumo de tours e viagens.',
        kind: ApiErrorKind.invalidResponse,
      );
    }

    return ToursSummaryReport.fromJson(_asMap(decoded));
  }

  @override
  Future<ToursSummaryDetail> getSummaryDetail({
    required ToursSummaryGroupBy groupBy,
    required String groupKey,
    required String dateFrom,
    required String dateTo,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{
        'groupBy': groupBy.apiValue,
        'groupKey': groupKey,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    ).query;
    final String path = 'tours/reports/summary/details?$query';
    final ApiResponse response = await _runRequest(
      method: 'GET',
      path: path,
      request: () => _apiClient.get(path, headers: _jsonHeaders),
    );

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw const ApiException(
        'Formato invalido do detalhe do resumo de tours.',
        kind: ApiErrorKind.invalidResponse,
      );
    }

    return ToursSummaryDetail.fromJson(_asMap(decoded));
  }

  @override
  Future<List<ToursProvider>> listProviders({bool activeOnly = false}) async {
    final String path = activeOnly
        ? 'tours/providers?activeOnly=true'
        : 'tours/providers';
    final ApiResponse response = await _runRequest(
      method: 'GET',
      path: path,
      request: () => _apiClient.get(path, headers: _jsonHeaders),
    );
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw const ApiException(
        'Formato invalido da lista de fornecedores.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return decoded
        .map<ToursProvider>(
          (Object? item) => ToursProvider.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<ToursProvider> createProvider(CreateToursProviderModel input) async {
    const String path = 'tours/providers';
    final ApiResponse response = await _runRequest(
      method: 'POST',
      path: path,
      request: () => _apiClient.post(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursProvider.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursProvider> updateProvider(
    int providerId,
    UpdateToursProviderModel input,
  ) async {
    final String path = 'tours/providers/$providerId';
    final ApiResponse response = await _runRequest(
      method: 'PUT',
      path: path,
      request: () => _apiClient.put(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursProvider.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<ToursBooking>> listBookings({
    String? dateFrom,
    String? dateTo,
    int? providerId,
    bool? paid,
    ToursServiceType? serviceType,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) {
      query['dateFrom'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      query['dateTo'] = dateTo;
    }
    if (providerId != null) {
      query['providerId'] = '$providerId';
    }
    if (paid != null) {
      query['paid'] = '$paid';
    }
    if (serviceType != null) {
      query['serviceType'] = serviceType.apiValue;
    }

    final String path = query.isEmpty
        ? 'tours/bookings'
        : 'tours/bookings?${Uri(queryParameters: query).query}';
    final ApiResponse response = await _runRequest(
      method: 'GET',
      path: path,
      request: () => _apiClient.get(path, headers: _jsonHeaders),
    );
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw const ApiException(
        'Formato invalido da lista de agendamentos.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    return decoded
        .map<ToursBooking>(
          (Object? item) => ToursBooking.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<ToursBooking> createBooking(CreateToursBookingModel input) async {
    const String path = 'tours/bookings';
    final ApiResponse response = await _runRequest(
      method: 'POST',
      path: path,
      request: () => _apiClient.post(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> updateBooking(
    int bookingId,
    UpdateToursBookingModel input,
  ) async {
    final String path = 'tours/bookings/$bookingId';
    final ApiResponse response = await _runRequest(
      method: 'PUT',
      path: path,
      request: () => _apiClient.put(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> updatePayment(
    int bookingId,
    UpdateToursPaymentModel input,
  ) async {
    final String path = 'tours/bookings/$bookingId/payment';
    final ApiResponse response = await _runRequest(
      method: 'PATCH',
      path: path,
      request: () => _apiClient.patch(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> cancelBooking(
    int bookingId,
    CancelToursBookingModel input,
  ) async {
    final String path = 'tours/bookings/$bookingId/cancel';
    final ApiResponse response = await _runRequest(
      method: 'PATCH',
      path: path,
      request: () => _apiClient.patch(
        path,
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  Future<ApiResponse> _runRequest({
    required String method,
    required String path,
    required Future<ApiResponse> Function() request,
  }) async {
    try {
      final ApiResponse response = await request();
      if (!response.isSuccess) {
        throw ApiException(
          _extractApiErrorMessage(response),
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
        'Tempo esgotado ao conectar ao backend configurado.',
        kind: ApiErrorKind.timeout,
        method: method,
        path: path,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Resposta invalida do backend configurado: ${error.message}',
        kind: ApiErrorKind.invalidResponse,
        method: method,
        path: path,
        cause: error,
      );
    } on Exception catch (error) {
      throw ApiException(
        'Nao foi possivel conectar ao backend configurado. Verifique a URL e a conectividade.',
        kind: ApiErrorKind.network,
        method: method,
        path: path,
        cause: error,
      );
    }
  }

  static String _extractApiErrorMessage(ApiResponse response) {
    try {
      final String? message = _extractMessage(_tryDecode(response.body));
      if (message != null) {
        return PtBrErrorTranslator.translate(message);
      }
    } on FormatException {
      final String rawBody = response.body.trim();
      if (rawBody.isNotEmpty && !_looksLikeHtml(rawBody)) {
        return PtBrErrorTranslator.translate(rawBody);
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

  static String? _extractMessage(Object? decoded) {
    if (decoded is String) {
      final String trimmed = decoded.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (decoded is! Map) {
      return null;
    }

    for (final String key in <String>['message', 'error', 'detail', 'title']) {
      final String? extracted = _extractText(decoded[key]);
      if (extracted != null) {
        return extracted;
      }
    }

    for (final String key in <String>['errors', 'details', 'issues']) {
      final String? extracted = _extractText(decoded[key]);
      if (extracted != null) {
        return extracted;
      }
    }

    return null;
  }

  static String? _extractText(Object? value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List) {
      for (final Object? item in value) {
        final String? extracted = _extractText(item);
        if (extracted != null) {
          return extracted;
        }
      }
      return null;
    }

    if (value is Map) {
      for (final Object? nestedValue in value.values) {
        final String? extracted = _extractText(nestedValue);
        if (extracted != null) {
          return extracted;
        }
      }
    }

    return null;
  }

  static bool _looksLikeHtml(String rawBody) {
    final String normalized = rawBody.trimLeft().toLowerCase();
    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html');
  }
}
