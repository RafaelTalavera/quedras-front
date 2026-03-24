import 'package:flutter/material.dart';

import '../core/config/backend_config.dart';
import '../core/network/api_client.dart';
import '../core/network/authorized_api_client.dart';
import '../core/network/local_http_client.dart';
import '../core/theme/costa_norte_brand.dart';
import '../features/auth/application/auth_app_service.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/infrastructure/http_auth_app_service.dart';
import '../features/courts/application/court_app_service.dart';
import '../features/courts/infrastructure/http_court_app_service.dart';
import '../features/massages/application/massage_app_service.dart';
import '../features/massages/infrastructure/http_massage_app_service.dart';
import '../features/reservations/application/reservation_app_service.dart';
import '../features/reservations/infrastructure/http_reservation_app_service.dart';
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
  }) : _apiClient = apiClient,
       _authAppService = authAppService,
       _sessionController = sessionController,
       _massageAppService = massageAppService,
       _reservationAppService = reservationAppService,
       _courtAppService = courtAppService;

  final ApiClient? _apiClient;
  final AuthAppService? _authAppService;
  final SessionController? _sessionController;
  final MassageAppService? _massageAppService;
  final ReservationAppService? _reservationAppService;
  final CourtAppService? _courtAppService;

  @override
  State<CostaNorteApp> createState() => _CostaNorteAppState();
}

class _CostaNorteAppState extends State<CostaNorteApp> {
  late final ApiClient _rawApiClient;
  late final ApiClient _authorizedApiClient;
  late final AuthAppService _authAppService;
  late final SessionController _sessionController;
  late final MassageAppService _massageAppService;
  late final ReservationAppService _reservationAppService;
  late final CourtAppService _courtAppService;

  @override
  void initState() {
    super.initState();
    _sessionController = widget._sessionController ?? SessionController();
    _rawApiClient =
        widget._apiClient ?? LocalHttpClient(baseUrl: BackendConfig.apiBaseUrl);
    _authorizedApiClient = AuthorizedApiClient(
      delegate: _rawApiClient,
      authorizationHeaderProvider: () => _sessionController.authorizationHeader,
      onUnauthorized: _sessionController.clearSession,
    );
    _authAppService =
        widget._authAppService ?? HttpAuthAppService(apiClient: _rawApiClient);
    _massageAppService =
        widget._massageAppService ??
        HttpMassageAppService(apiClient: _authorizedApiClient);
    _reservationAppService =
        widget._reservationAppService ??
        HttpReservationAppService(apiClient: _authorizedApiClient);
    _courtAppService =
        widget._courtAppService ??
        HttpCourtAppService(apiClient: _authorizedApiClient);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CostaNorte',
      debugShowCheckedModeBanner: false,
      theme: CostaNorteBrand.buildTheme(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings: settings,
        authAppService: _authAppService,
        sessionController: _sessionController,
        massageAppService: _massageAppService,
        reservationAppService: _reservationAppService,
        courtAppService: _courtAppService,
      ),
    );
  }
}
