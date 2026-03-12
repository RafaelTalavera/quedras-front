import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/network/api_client.dart';
import '../application/reservation_app_service.dart';
import '../domain/create_reservation_model.dart';
import '../domain/reservation_model.dart';
import '../domain/update_reservation_model.dart';

final class HttpReservationAppService implements ReservationAppService {
  HttpReservationAppService({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const Map<String, String> _jsonHeaders = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
  };

  final ApiClient _apiClient;

  @override
  Future<List<ReservationModel>> listByDate(String reservationDate) async {
    final String encodedDate = Uri.encodeQueryComponent(reservationDate);
    final ApiResponse response = await _runRequest(
      () => _apiClient.get(
        'reservations?reservationDate=$encodedDate',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }

    final Object? decoded = _tryDecode(response.body);
    if (decoded is! List) {
      throw StateError('Invalid reservation list format from local backend.');
    }

    final List<ReservationModel> reservations = <ReservationModel>[];
    for (final Object? item in decoded) {
      reservations.add(ReservationModel.fromJson(_asMap(item)));
    }
    return reservations;
  }

  @override
  Future<ReservationModel> create(CreateReservationModel input) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.post(
        'reservations',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return _parseReservation(response.body);
  }

  @override
  Future<ReservationModel> update(
    int reservationId,
    UpdateReservationModel input,
  ) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.put(
        'reservations/$reservationId',
        headers: _jsonHeaders,
        body: jsonEncode(input.toJson()),
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return _parseReservation(response.body);
  }

  @override
  Future<ReservationModel> cancel(int reservationId) async {
    final ApiResponse response = await _runRequest(
      () => _apiClient.patch(
        'reservations/$reservationId/cancel',
        headers: _jsonHeaders,
      ),
    );
    if (!response.isSuccess) {
      throw StateError(_extractApiErrorMessage(response));
    }
    return _parseReservation(response.body);
  }

  Future<ApiResponse> _runRequest(
    Future<ApiResponse> Function() request,
  ) async {
    try {
      return await request();
    } on SocketException {
      throw StateError(
        'No fue posible conectar con el backend local. Verifique servidor y red interna.',
      );
    } on TimeoutException {
      throw StateError('Timeout al conectar con el backend local.');
    } on HttpException {
      throw StateError('Error HTTP de transporte al consultar backend local.');
    } on FormatException catch (error) {
      throw StateError(
        'Respuesta invalida del backend local: ${error.message}',
      );
    }
  }

  ReservationModel _parseReservation(String rawBody) {
    final Object? decoded = _tryDecode(rawBody);
    return ReservationModel.fromJson(_asMap(decoded));
  }

  static String _extractApiErrorMessage(ApiResponse response) {
    final Object? decoded = _tryDecode(response.body);
    if (decoded is Map) {
      final Object? message = decoded['message'];
      if (message != null) {
        final String asString = message.toString().trim();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }
    return 'Backend local devolvio HTTP ${response.statusCode}.';
  }

  static Object? _tryDecode(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return null;
    }
    return jsonDecode(rawBody);
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Se esperaba un objeto JSON.');
    }
    return value.map<String, dynamic>(
      (Object? key, Object? mapValue) =>
          MapEntry<String, dynamic>(key.toString(), mapValue),
    );
  }
}
