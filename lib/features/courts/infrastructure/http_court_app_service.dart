import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/court_app_service.dart';
import '../domain/court_models.dart';

final class HttpCourtAppService implements CourtAppService {
  HttpCourtAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<List<CourtRateSetting>> listRates() async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('courts/rates', headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de tarifas de quadras.');
    }
    return decoded
        .map<CourtRateSetting>(
          (Object? item) => CourtRateSetting.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<CourtRateSetting> updateRate(
    int rateId,
    UpdateCourtRateSettingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'courts/rates/$rateId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtRateSetting.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<CourtMaterialSetting>> listMaterials() async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('courts/materials', headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de materiais de quadras.');
    }
    return decoded
        .map<CourtMaterialSetting>(
          (Object? item) => CourtMaterialSetting.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<CourtMaterialSetting> updateMaterial(
    int materialId,
    UpdateCourtMaterialSettingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'courts/materials/$materialId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtMaterialSetting.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<CourtBooking>> listBookings({
    String? bookingDate,
    CourtCustomerType? customerType,
    bool? paid,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (bookingDate != null && bookingDate.isNotEmpty) {
      query['bookingDate'] = bookingDate;
    }
    if (customerType != null) {
      query['customerType'] = customerType.apiValue;
    }
    if (paid != null) {
      query['paid'] = '$paid';
    }
    final String path = query.isEmpty
        ? 'courts/bookings'
        : 'courts/bookings?${Uri(queryParameters: query).query}';
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido da lista de reservas de quadras.');
    }
    return decoded
        .map<CourtBooking>(
          (Object? item) => CourtBooking.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<CourtBooking> createBooking(CreateCourtBookingModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'courts/bookings',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<CourtBooking> updateBooking(
    int bookingId,
    UpdateCourtBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'courts/bookings/$bookingId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<CourtBooking> updatePayment(
    int bookingId,
    UpdateCourtPaymentModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'courts/bookings/$bookingId/payment',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<CourtBooking> cancelBooking(
    int bookingId,
    CancelCourtBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'courts/bookings/$bookingId/cancel',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<CourtSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{'dateFrom': dateFrom, 'dateTo': dateTo},
    ).query;
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'courts/bookings/summary?$query',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtSummaryReport.fromJson(_asMap(_tryDecode(response.body)));
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
