import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/tours_app_service.dart';
import '../domain/tours_models.dart';

final class HttpToursAppService implements ToursAppService {
  HttpToursAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
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
    final ApiResponse response = await _runRequest(
      () =>
          _apiClient.get('tours/reports/summary?$query', headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Formato invalido do resumo de tours e viagens.');
    }

    return ToursSummaryReport.fromJson(_asMap(decoded));
  }

  @override
  Future<ToursSummaryDetail> getSummaryDetail({
    required ToursSummaryGroupBy groupBy,
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
        'tours/reports/summary/details?$query',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Formato invalido do detalhe do resumo de tours.');
    }

    return ToursSummaryDetail.fromJson(_asMap(decoded));
  }

  @override
  Future<List<ToursProvider>> listProviders({bool activeOnly = false}) async {
    final String path = activeOnly
        ? 'tours/providers?activeOnly=true'
        : 'tours/providers';
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de fornecedores.');
    }
    return decoded
        .map<ToursProvider>(
          (Object? item) => ToursProvider.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<ToursProvider> createProvider(CreateToursProviderModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'tours/providers',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ToursProvider.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursProvider> updateProvider(
    int providerId,
    UpdateToursProviderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'tours/providers/$providerId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
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
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de agendamentos.');
    }
    return decoded
        .map<ToursBooking>(
          (Object? item) => ToursBooking.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<ToursBooking> createBooking(CreateToursBookingModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'tours/bookings',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> updateBooking(
    int bookingId,
    UpdateToursBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'tours/bookings/$bookingId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> updatePayment(
    int bookingId,
    UpdateToursPaymentModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'tours/bookings/$bookingId/payment',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<ToursBooking> cancelBooking(
    int bookingId,
    CancelToursBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'tours/bookings/$bookingId/cancel',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return ToursBooking.fromJson(_asMap(_tryDecode(response.body)));
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
