import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'firebase_push_config.dart';
import 'push_subscription_client.dart';

abstract interface class PushNotificationService {
  Stream<void> get notificationsChanged;
  Stream<PushMaintenanceOpenRequest> get openedMaintenanceOrders;
  PushMaintenanceOpenRequest? takePendingMaintenanceOrder();
  Future<void> startSession(String authorizationHeader, ApiClient apiClient);
  Future<void> heartbeat();
  Future<void> stopSession();
  void dispose();
}

final class PushMaintenanceOpenRequest {
  const PushMaintenanceOpenRequest({required this.orderId, this.dueAt});

  final int orderId;
  final DateTime? dueAt;
}

final class DisabledPushNotificationService implements PushNotificationService {
  const DisabledPushNotificationService();

  @override
  Stream<void> get notificationsChanged => const Stream<void>.empty();

  @override
  Stream<PushMaintenanceOpenRequest> get openedMaintenanceOrders =>
      const Stream<PushMaintenanceOpenRequest>.empty();

  @override
  PushMaintenanceOpenRequest? takePendingMaintenanceOrder() => null;

  @override
  Future<void> heartbeat() async {}

  @override
  Future<void> startSession(
    String authorizationHeader,
    ApiClient apiClient,
  ) async {}

  @override
  Future<void> stopSession() async {}

  @override
  void dispose() {}
}

final class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService._(
    this._messaging, {
    PushSubscriptionClient subscriptionClient = const PushSubscriptionClient(),
  }) : _subscriptionClient = subscriptionClient;

  final FirebaseMessaging _messaging;
  final PushSubscriptionClient _subscriptionClient;
  final StreamController<void> _notificationsChanged =
      StreamController<void>.broadcast();
  final StreamController<PushMaintenanceOpenRequest> _openedMaintenanceOrders =
      StreamController<PushMaintenanceOpenRequest>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  String? _authorizationHeader;
  ApiClient? _apiClient;
  String? _installationId;
  PushMaintenanceOpenRequest? _pendingMaintenanceOrder;
  Future<void> _operation = Future<void>.value();

  static Future<PushNotificationService> bootstrap() async {
    if (!FirebasePushConfig.shouldInitialize) {
      return const DisabledPushNotificationService();
    }
    await Firebase.initializeApp(options: FirebasePushConfig.options);
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
    final FirebasePushNotificationService service =
        FirebasePushNotificationService._(FirebaseMessaging.instance);
    await service._initialize();
    return service;
  }

  @override
  Stream<void> get notificationsChanged => _notificationsChanged.stream;

  @override
  Stream<PushMaintenanceOpenRequest> get openedMaintenanceOrders =>
      _openedMaintenanceOrders.stream;

  Future<void> _initialize() async {
    _subscriptions.add(
      _messaging.onRegistered.listen((String installationId) {
        _installationId = installationId;
        _queue(_registerCurrentInstallation);
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (_maintenanceOrderId(message) != null) {
          _notificationsChanged.add(null);
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage),
    );
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  @override
  Future<void> startSession(
    String authorizationHeader,
    ApiClient apiClient,
  ) async {
    _authorizationHeader = authorizationHeader;
    _apiClient = apiClient;
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }
    await _messaging.register(
      vapidKey: kIsWeb ? FirebasePushConfig.webVapidKey : null,
      serviceWorkerScriptPath: kIsWeb
          ? FirebasePushConfig.serviceWorkerScriptPath
          : null,
    );
  }

  @override
  Future<void> heartbeat() async {
    final String? installationId = _installationId;
    final ApiClient? apiClient = _apiClient;
    final String? authorizationHeader = _authorizationHeader;
    if (installationId == null ||
        apiClient == null ||
        authorizationHeader == null) {
      return;
    }
    await _subscriptionClient.heartbeat(
      apiClient: apiClient,
      authorizationHeader: authorizationHeader,
      installationId: installationId,
    );
  }

  @override
  Future<void> stopSession() async {
    final String? installationId = _installationId;
    final ApiClient? apiClient = _apiClient;
    final String? authorizationHeader = _authorizationHeader;
    if (installationId != null &&
        apiClient != null &&
        authorizationHeader != null) {
      await _subscriptionClient.unregister(
        apiClient: apiClient,
        authorizationHeader: authorizationHeader,
        installationId: installationId,
      );
    }
    await _messaging.unregister();
    _installationId = null;
    _authorizationHeader = null;
    _apiClient = null;
  }

  Future<void> _registerCurrentInstallation() async {
    final String? installationId = _installationId;
    final ApiClient? apiClient = _apiClient;
    final String? authorizationHeader = _authorizationHeader;
    if (installationId == null ||
        apiClient == null ||
        authorizationHeader == null) {
      return;
    }
    await _subscriptionClient.register(
      apiClient: apiClient,
      authorizationHeader: authorizationHeader,
      installationId: installationId,
      platform: _platform,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final int? orderId = _maintenanceOrderId(message);
    if (orderId == null) return;
    final PushMaintenanceOpenRequest request = PushMaintenanceOpenRequest(
      orderId: orderId,
      dueAt: DateTime.tryParse(message.data['dueAt']?.toString() ?? ''),
    );
    _pendingMaintenanceOrder = request;
    _openedMaintenanceOrders.add(request);
  }

  int? _maintenanceOrderId(RemoteMessage message) {
    if (message.data['module'] != 'maintenance') return null;
    return int.tryParse(message.data['orderId']?.toString() ?? '');
  }

  void _queue(Future<void> Function() action) {
    _operation = _operation.then((_) => action()).catchError((Object _) {});
  }

  @override
  PushMaintenanceOpenRequest? takePendingMaintenanceOrder() {
    final PushMaintenanceOpenRequest? value = _pendingMaintenanceOrder;
    _pendingMaintenanceOrder = null;
    return value;
  }

  @override
  void dispose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_notificationsChanged.close());
    unawaited(_openedMaintenanceOrders.close());
  }

  String get _platform {
    if (kIsWeb) return 'WEB';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      _ => throw UnsupportedError('Plataforma push nao suportada.'),
    };
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: FirebasePushConfig.options);
  }
}
