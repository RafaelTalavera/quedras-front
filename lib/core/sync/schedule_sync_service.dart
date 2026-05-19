import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'schedule_sync_event.dart';

typedef AuthorizationHeaderProvider = String? Function();
typedef UnauthorizedCallback = void Function();

final class ScheduleSyncService {
  ScheduleSyncService({
    required String baseUrl,
    required AuthorizationHeaderProvider authorizationHeaderProvider,
    UnauthorizedCallback? onUnauthorized,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _authorizationHeaderProvider = authorizationHeaderProvider,
       _onUnauthorized = onUnauthorized;

  static const Duration _reconnectDelay = Duration(seconds: 3);

  final Uri _baseUri;
  final AuthorizationHeaderProvider _authorizationHeaderProvider;
  final UnauthorizedCallback? _onUnauthorized;
  final StreamController<ScheduleSyncEvent> _eventsController =
      StreamController<ScheduleSyncEvent>.broadcast();

  http.Client? _client;
  StreamSubscription<String>? _lineSubscription;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _connecting = false;
  bool _disposed = false;
  String? _currentEventName;
  final List<String> _currentEventDataLines = <String>[];

  Stream<ScheduleSyncEvent> get events => _eventsController.stream;

  void start() {
    if (_disposed) {
      return;
    }
    _started = true;
    _connectIfNeeded();
  }

  void stop() {
    _started = false;
    _cancelConnection();
  }

  Future<void> dispose() async {
    _disposed = true;
    _started = false;
    _cancelConnection();
    await _eventsController.close();
  }

  static Uri _normalizeBaseUri(String baseUrl) {
    final String normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final Uri parsed = Uri.parse(normalized);
    if (parsed.hasScheme) {
      return parsed;
    }
    return Uri.base.resolveUri(parsed);
  }

  void _connectIfNeeded() {
    if (_disposed || !_started || _connecting || _lineSubscription != null) {
      return;
    }
    final String? authorization = _authorizationHeaderProvider();
    if (authorization == null || authorization.isEmpty) {
      return;
    }
    _connecting = true;
    _openConnection(authorization);
  }

  Future<void> _openConnection(String authorization) async {
    final http.Client client = http.Client();
    _client = client;
    final http.Request request = http.Request(
      'GET',
      _baseUri.resolve('sync/events'),
    );
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';
    request.headers['Authorization'] = authorization;

    try {
      final http.StreamedResponse response = await client.send(request);
      if (response.statusCode == 401) {
        _onUnauthorized?.call();
        _connecting = false;
        client.close();
        _client = null;
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Nao foi possivel iniciar sincronizacao em tempo real (${response.statusCode}).',
        );
      }
      _connecting = false;
      _lineSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onDone: _handleConnectionClosed,
            onError: _handleConnectionError,
            cancelOnError: true,
          );
    } catch (_) {
      _connecting = false;
      client.close();
      if (identical(_client, client)) {
        _client = null;
      }
      _scheduleReconnect();
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) {
      _dispatchCurrentEvent();
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    if (line.startsWith('event:')) {
      _currentEventName = line.substring(6).trim();
      return;
    }
    if (line.startsWith('data:')) {
      _currentEventDataLines.add(line.substring(5).trimLeft());
    }
  }

  void _dispatchCurrentEvent() {
    final String? eventName = _currentEventName;
    final String payload = _currentEventDataLines.join('\n').trim();
    _currentEventName = null;
    _currentEventDataLines.clear();
    if (payload.isEmpty || eventName != 'schedule-changed') {
      return;
    }
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _eventsController.add(ScheduleSyncEvent.fromJson(decoded));
    } catch (_) {
      return;
    }
  }

  void _handleConnectionClosed() {
    _cleanupConnection();
    _scheduleReconnect();
  }

  void _handleConnectionError(Object _) {
    _cleanupConnection();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_started) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connectIfNeeded);
  }

  void _cancelConnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
  }

  void _cleanupConnection() {
    _currentEventName = null;
    _currentEventDataLines.clear();
    final StreamSubscription<String>? subscription = _lineSubscription;
    _lineSubscription = null;
    subscription?.cancel();
    final http.Client? client = _client;
    _client = null;
    client?.close();
    _connecting = false;
  }
}
