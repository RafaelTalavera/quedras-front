import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/localization/pt_br_error_translator.dart';
import '../../../core/network/api_client.dart';
import '../application/massage_app_service.dart';
import '../domain/massage_models.dart';

final class HttpMassageAppService implements MassageAppService {
  HttpMassageAppService({required ApiClient apiClient}) : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<MassageProvider> createProvider(CreateMassageProviderModel input) async {
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
    String? clientName,
    String? guestReference,
    int? providerId,
    bool? paid,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (bookingDate != null && bookingDate.isNotEmpty) {
      query['bookingDate'] = bookingDate;
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
        'Formato inv\u00e1lido da lista de massagens retornada pelo backend local.',
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
        'Formato inv\u00e1lido da lista de prestadores retornada pelo backend local.',
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

  Future<ApiResponse> _runRequest(
    Future<ApiResponse> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw StateError(
        'N\u00e3o foi poss\u00edvel conectar ao backend local. Verifique o servidor e a rede interna.',
      );
    } on TimeoutException {
      throw StateError('Tempo esgotado ao conectar ao backend local.');
    } on HttpException {
      throw StateError('Erro HTTP de transporte ao consultar o backend local.');
    } on FormatException catch (error) {
      throw StateError('Resposta inv\u00e1lida do backend local: ${error.message}');
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
