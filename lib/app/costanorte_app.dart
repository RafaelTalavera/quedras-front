import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/backend_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_client_factory.dart';
import '../core/network/authorized_api_client.dart';
import '../core/push/push_notification_service.dart';
import '../core/sync/schedule_sync_service.dart';
import '../core/theme/costa_norte_brand.dart';
import '../features/auth/application/auth_app_service.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/infrastructure/http_auth_app_service.dart';
import '../features/courts/application/court_app_service.dart';
import '../features/courts/infrastructure/http_court_app_service.dart';
import '../features/massages/application/massage_app_service.dart';
import '../features/massages/infrastructure/http_massage_app_service.dart';
import '../features/maintenance/application/maintenance_app_service.dart';
import '../features/maintenance/infrastructure/http_maintenance_app_service.dart';
import '../features/laundry/application/laundry_app_service.dart';
import '../features/laundry/infrastructure/http_laundry_app_service.dart';
import '../features/reservations/application/reservation_app_service.dart';
import '../features/reservations/infrastructure/http_reservation_app_service.dart';
import '../features/settings/application/user_management_app_service.dart';
import '../features/settings/infrastructure/http_user_management_app_service.dart';
import '../features/tours/application/tours_app_service.dart';
import '../features/tours/infrastructure/http_tours_app_service.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class CostaNorteApp extends StatefulWidget {
  const CostaNorteApp({
    super.key,
    ApiClient? apiClient,
    AuthAppService? authAppService,
    SessionController? sessionController,
    MassageAppService? massageAppService,
    ReservationAppService? reservationAppService,
    CourtAppService? courtAppService,
    ToursAppService? toursAppService,
    MaintenanceAppService? maintenanceAppService,
    LaundryAppService? laundryAppService,
    UserManagementAppService? userManagementAppService,
    PushNotificationService? pushNotificationService,
  }) : _apiClient = apiClient,
       _authAppService = authAppService,
       _sessionController = sessionController,
       _massageAppService = massageAppService,
       _reservationAppService = reservationAppService,
       _courtAppService = courtAppService,
       _toursAppService = toursAppService,
       _maintenanceAppService = maintenanceAppService,
       _laundryAppService = laundryAppService,
       _userManagementAppService = userManagementAppService,
       _pushNotificationService = pushNotificationService;

  final ApiClient? _apiClient;
  final AuthAppService? _authAppService;
  final SessionController? _sessionController;
  final MassageAppService? _massageAppService;
  final ReservationAppService? _reservationAppService;
  final CourtAppService? _courtAppService;
  final ToursAppService? _toursAppService;
  final MaintenanceAppService? _maintenanceAppService;
  final LaundryAppService? _laundryAppService;
  final UserManagementAppService? _userManagementAppService;
  final PushNotificationService? _pushNotificationService;

  @override
  State<CostaNorteApp> createState() => _CostaNorteAppState();
}

class _CostaNorteAppState extends State<CostaNorteApp>
    with WidgetsBindingObserver {
  late final ApiClient _rawApiClient;
  late final ApiClient _authorizedApiClient;
  late final AuthAppService _authAppService;
  late final SessionController _sessionController;
  late final MassageAppService _massageAppService;
  late final ReservationAppService _reservationAppService;
  late final CourtAppService _courtAppService;
  late final ToursAppService _toursAppService;
  late final MaintenanceAppService _maintenanceAppService;
  late final LaundryAppService _laundryAppService;
  late final UserManagementAppService _userManagementAppService;
  late final ScheduleSyncService _scheduleSyncService;
  late final PushNotificationService _pushNotificationService;
  bool _pushSessionActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionController = widget._sessionController ?? SessionController();
    _rawApiClient =
        widget._apiClient ?? createApiClient(baseUrl: BackendConfig.apiBaseUrl);
    _authorizedApiClient = AuthorizedApiClient(
      delegate: _rawApiClient,
      authorizationHeaderProvider: () => _sessionController.authorizationHeader,
      onUnauthorized: _sessionController.clearSession,
    );
    _authAppService =
        widget._authAppService ?? HttpAuthAppService(apiClient: _rawApiClient);
    _scheduleSyncService = ScheduleSyncService(
      baseUrl: BackendConfig.apiBaseUrl,
      authorizationHeaderProvider: () => _sessionController.authorizationHeader,
      onUnauthorized: _sessionController.clearSession,
    );
    _massageAppService =
        widget._massageAppService ??
        HttpMassageAppService(apiClient: _authorizedApiClient);
    _reservationAppService =
        widget._reservationAppService ??
        HttpReservationAppService(apiClient: _authorizedApiClient);
    _courtAppService =
        widget._courtAppService ??
        HttpCourtAppService(apiClient: _authorizedApiClient);
    _toursAppService =
        widget._toursAppService ??
        HttpToursAppService(apiClient: _authorizedApiClient);
    _maintenanceAppService =
        widget._maintenanceAppService ??
        HttpMaintenanceAppService(apiClient: _authorizedApiClient);
    _laundryAppService =
        widget._laundryAppService ??
        HttpLaundryAppService(apiClient: _authorizedApiClient);
    _userManagementAppService =
        widget._userManagementAppService ??
        HttpUserManagementAppService(apiClient: _authorizedApiClient);
    _pushNotificationService =
        widget._pushNotificationService ??
        const DisabledPushNotificationService();
    _sessionController.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionController.removeListener(_handleSessionChanged);
    _scheduleSyncService.dispose();
    _pushNotificationService.dispose();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (_sessionController.isAuthenticated) {
      _scheduleSyncService.start();
      final String? authorization = _sessionController.authorizationHeader;
      if (authorization != null) {
        _pushSessionActive = true;
        unawaited(
          _pushNotificationService
              .startSession(authorization, _rawApiClient)
              .catchError((Object _) {}),
        );
      }
      return;
    }
    _scheduleSyncService.stop();
    if (!_pushSessionActive) {
      return;
    }
    _pushSessionActive = false;
    unawaited(_pushNotificationService.stopSession().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _sessionController.isAuthenticated) {
      unawaited(_pushNotificationService.heartbeat().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CostaNorte',
      debugShowCheckedModeBanner: false,
      theme: CostaNorteBrand.buildTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings: settings,
        authAppService: _authAppService,
        sessionController: _sessionController,
        massageAppService: _massageAppService,
        reservationAppService: _reservationAppService,
        courtAppService: _courtAppService,
        toursAppService: _toursAppService,
        maintenanceAppService: _maintenanceAppService,
        laundryAppService: _laundryAppService,
        userManagementAppService: _userManagementAppService,
        scheduleSyncService: _scheduleSyncService,
        pushNotificationService: _pushNotificationService,
      ),
    );
  }
}
