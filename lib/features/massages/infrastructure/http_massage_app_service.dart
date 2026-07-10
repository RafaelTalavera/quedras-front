import 'dart:async';
import 'dart:convert';

import '../../../core/audit/audit_models.dart';
import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/massage_app_service.dart';
import '../domain/massage_models.dart';

final class HttpMassageAppService implements MassageAppService {
  HttpMassageAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<MassageProviderDetailReport> getProviderDetailReport(
    int providerId, {
    required String dateFrom,
    required String dateTo,
  }) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'massages/reports/providers/$providerId/details?${Uri(queryParameters: <String, String>{"dateFrom": dateFrom, "dateTo": dateTo}).query}',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageProviderDetailReport.fromJson(
      _asMap(_tryDecode(response.body)),
    );
  }

  @override
  Future<List<MassageProviderSummary>> listProviderSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'massages/reports/providers/summary?${Uri(queryParameters: <String, String>{"dateFrom": dateFrom, "dateTo": dateTo}).query}',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError(
        'Formato invalido da lista de resumo de massagens retornada pelo backend configurado.',
      );
    }
    return decoded
        .map<MassageProviderSummary>(
          (Object? item) => MassageProviderSummary.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MassageProvider> createProvider(
    CreateMassageProviderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'massages/providers',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageProvider.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<MassageBooking>> listBookings({
    String? bookingDate,
    String? dateFrom,
    String? dateTo,
    String? clientName,
    String? guestReference,
    int? providerId,
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
    if (clientName != null && clientName.trim().isNotEmpty) {
      query['clientName'] = clientName.trim();
    }
    if (guestReference != null && guestReference.trim().isNotEmpty) {
      query['guestReference'] = guestReference.trim();
    }
    if (providerId != null) {
      query['providerId'] = '$providerId';
    }
    if (paid != null) {
      query['paid'] = '$paid';
    }

    final String path = query.isEmpty
        ? 'massages/bookings'
        : 'massages/bookings?${Uri(queryParameters: query).query}';

    final ApiResponse response = await _runRequest(
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError(
        'Formato inv\u00e1lido da lista de massagens retornada pelo backend configurado.',
      );
    }

    return decoded
        .map<MassageBooking>(
          (Object? item) => MassageBooking.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<List<MassageProvider>> listProviders({bool activeOnly = false}) async {
    final String path = activeOnly
        ? 'massages/providers?activeOnly=true'
        : 'massages/providers';
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(path, headers: _jsonHeaders),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError(
        'Formato inv\u00e1lido da lista de prestadores retornada pelo backend configurado.',
      );
    }

    return decoded
        .map<MassageProvider>(
          (Object? item) => MassageProvider.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MassageBooking> createBooking(CreateMassageBookingModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'massages/bookings',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<MassageBooking> updateBooking(
    int bookingId,
    UpdateMassageBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'massages/bookings/$bookingId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<MassageProvider> updateProvider(
    int providerId,
    UpdateMassageProviderModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'massages/providers/$providerId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageProvider.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<AuditEventModel>> providerHistory(int providerId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'massages/providers/$providerId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido do historico de prestadores.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MassageTherapist> createTherapist(
    int providerId,
    CreateMassageTherapistModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'massages/providers/$providerId/therapists',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return _extractTherapistFromResponseBody(
      response.body,
      expectedName: input.name,
    );
  }

  @override
  Future<MassageTherapist> updateTherapist(
    int providerId,
    int therapistId,
    UpdateMassageTherapistModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'massages/providers/$providerId/therapists/$therapistId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return _extractTherapistFromResponseBody(
      response.body,
      expectedId: therapistId,
      expectedName: input.name,
    );
  }

  @override
  Future<List<AuditEventModel>> therapistHistory(
    int providerId,
    int therapistId,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'massages/providers/$providerId/therapists/$therapistId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido do historico de massagistas.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
  }

  @override
  Future<MassageBooking> updatePayment(
    int bookingId,
    UpdateMassagePaymentModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'massages/bookings/$bookingId/payment',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<MassageBooking> cancelBooking(
    int bookingId,
    CancelMassageBookingModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'massages/bookings/$bookingId/cancel',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return MassageBooking.fromJson(_asMap(_tryDecode(response.body)));
  }

  @override
  Future<List<AuditEventModel>> history(int bookingId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'massages/bookings/$bookingId/audit',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Formato invalido do historico de atendimentos.');
    }
    return decoded
        .whereType<Map>()
        .map<AuditEventModel>(
          (Map item) => AuditEventModel.fromJson(_asMap(item)),
        )
        .toList();
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
        'Resposta inv\u00e1lida do backend configurado: ${error.message}',
      );
    } on Exception {
      throw StateError(
        'N\u00e3o foi poss\u00edvel conectar ao backend configurado. Verifique a URL e a conectividade.',
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

  static MassageTherapist _extractTherapistFromResponseBody(
    String rawBody, {
    int? expectedId,
    String? expectedName,
  }) {
    final Object? decoded = _tryDecode(rawBody);
    if (decoded is Map) {
      final Map<String, dynamic> asMap = _asMap(decoded);
      if (_looksLikeTherapistMap(asMap)) {
        return MassageTherapist.fromJson(asMap);
      }

      final Object? nestedTherapist = asMap['therapist'] ?? asMap['masseuse'];
      if (nestedTherapist is Map) {
        return MassageTherapist.fromJson(_asMap(nestedTherapist));
      }

      final Object? nestedList =
          asMap['therapists'] ??
          asMap['masseuses'] ??
          asMap['massageTherapists'];
      final MassageTherapist? matched = _extractTherapistFromList(
        nestedList,
        expectedId: expectedId,
        expectedName: expectedName,
      );
      if (matched != null) {
        return matched;
      }
    }

    if (decoded is List) {
      final MassageTherapist? matched = _extractTherapistFromList(
        decoded,
        expectedId: expectedId,
        expectedName: expectedName,
      );
      if (matched != null) {
        return matched;
      }
    }

    throw const FormatException(
      'Formato invalido da resposta do backend para masajista.',
    );
  }

  static MassageTherapist? _extractTherapistFromList(
    Object? rawList, {
    int? expectedId,
    String? expectedName,
  }) {
    if (rawList is! List || rawList.isEmpty) {
      return null;
    }
    final List<MassageTherapist> therapists = rawList
        .whereType<Map>()
        .map<MassageTherapist>(
          (Map item) => MassageTherapist.fromJson(_asMap(item)),
        )
        .toList();
    if (therapists.isEmpty) {
      return null;
    }
    if (expectedId != null) {
      for (final MassageTherapist therapist in therapists) {
        if (therapist.id == expectedId) {
          return therapist;
        }
      }
    }
    if (expectedName != null) {
      final String normalizedExpected = expectedName.trim().toLowerCase();
      for (final MassageTherapist therapist in therapists) {
        if (therapist.name.trim().toLowerCase() == normalizedExpected) {
          return therapist;
        }
      }
    }
    return therapists.last;
  }

  static bool _looksLikeTherapistMap(Map<String, dynamic> map) {
    if (map.containsKey('specialty') || map.containsKey('contact')) {
      return false;
    }
    return map.containsKey('id') &&
        (map.containsKey('name') ||
            map.containsKey('active') ||
            map.containsKey('therapist') ||
            map.containsKey('masseuse'));
  }
}
