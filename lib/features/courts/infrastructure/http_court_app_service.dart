import 'dart:async';
import 'dart:convert';

import '../../../core/audit/audit_models.dart';
import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/court_app_service.dart';
import '../domain/court_models.dart';

final class HttpCourtAppService implements CourtAppService {
  HttpCourtAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
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
  Future<List<CourtPartnerCoach>> listPartnerCoaches({
    bool activeOnly = true,
  }) async {
    final String query = Uri(
      queryParameters: <String, String>{'activeOnly': '$activeOnly'},
    ).query;
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'courts/partner-coaches?$query',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError(
        'Formato invalido da lista de professores parceiros de quadras.',
      );
    }
    return decoded
        .map<CourtPartnerCoach>(
          (Object? item) => CourtPartnerCoach.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<CourtPartnerCoach> createPartnerCoach(
    CreateCourtPartnerCoachModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'courts/partner-coaches',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtPartnerCoach.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<CourtPartnerCoach> updatePartnerCoach(
    int partnerCoachId,
    UpdateCourtPartnerCoachModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'courts/partner-coaches/$partnerCoachId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return CourtPartnerCoach.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<AuditEventModel>> partnerCoachHistory(int partnerCoachId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'courts/partner-coaches/$partnerCoachId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido del historial de profesores asociados.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
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
  Future<List<AuditEventModel>> rateHistory(int rateId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get('courts/rates/$rateId/audit', headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido del historial de tarifas.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
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
  Future<List<AuditEventModel>> materialHistory(int materialId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'courts/materials/$materialId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido del historial de materiales.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<List<CourtBooking>> listBookings({
    String? bookingDate,
    String? dateFrom,
    String? dateTo,
    CourtCustomerType? customerType,
    bool? paid,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (bookingDate != null && bookingDate.isNotEmpty) {
      query['bookingDate'] = bookingDate;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      query['dateFrom'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      query['dateTo'] = dateTo;
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
  Future<List<AuditEventModel>> history(int bookingId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'courts/bookings/$bookingId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido del historial de reservas de quadras.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
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
    } on TimeoutException {
      throw StateError('Tempo esgotado ao conectar ao backend configurado.');
    } on FormatException catch (error) {
      throw StateError('Resposta invalida do backend configurado: ${error.message}');
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
