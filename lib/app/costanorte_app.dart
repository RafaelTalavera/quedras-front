import 'package:flutter/material.dart';

import '../core/config/backend_config.dart';
import '../core/network/api_client.dart';
import '../core/network/authorized_api_client.dart';
import '../core/network/local_http_client.dart';
import '../features/auth/application/auth_app_service.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/infrastructure/http_auth_app_service.dart';
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
    ReservationAppService? reservationAppService,
  }) : _apiClient = apiClient,
       _authAppService = authAppService,
       _sessionController = sessionController,
       _reservationAppService = reservationAppService;

  final ApiClient? _apiClient;
  final AuthAppService? _authAppService;
  final SessionController? _sessionController;
  final ReservationAppService? _reservationAppService;

  @override
  State<CostaNorteApp> createState() => _CostaNorteAppState();
}

class _CostaNorteAppState extends State<CostaNorteApp> {
  late final ApiClient _rawApiClient;
  late final ApiClient _authorizedApiClient;
  late final AuthAppService _authAppService;
  late final SessionController _sessionController;
  late final ReservationAppService _reservationAppService;

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
    _reservationAppService =
        widget._reservationAppService ??
        HttpReservationAppService(apiClient: _authorizedApiClient);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CostaNorte',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings: settings,
        apiClient: _authorizedApiClient,
        authAppService: _authAppService,
        sessionController: _sessionController,
        reservationAppService: _reservationAppService,
      ),
    );
  }

  ThemeData _buildTheme() {
    const Color oceanBlue = Color(0xFF0F4C5C);
    const Color sand = Color(0xFFF4EBD0);

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: oceanBlue,
      brightness: Brightness.light,
      primary: oceanBlue,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(secondary: sand),
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      fontFamily: 'Cambria',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F2438),
          fontFamily: 'Cambria',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x160F4C5C)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.78),
        indicatorColor: const Color(0x33167D85),
        selectedIconTheme: const IconThemeData(color: Color(0xFF0F4C5C)),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFF0F4C5C),
          fontFamily: 'Cambria',
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF425466),
          fontFamily: 'Cambria',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
