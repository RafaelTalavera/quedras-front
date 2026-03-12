import 'package:flutter/material.dart';

import '../core/config/backend_config.dart';
import '../core/network/api_client.dart';
import '../core/network/local_http_client.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class QuedrasApp extends StatelessWidget {
  const QuedrasApp({super.key, ApiClient? apiClient}) : _apiClient = apiClient;

  final ApiClient? _apiClient;

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient =
        _apiClient ?? LocalHttpClient(baseUrl: BackendConfig.apiBaseUrl);

    return MaterialApp(
      title: 'QUEDRAS',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: AppRoutes.dashboard,
      onGenerateRoute: (settings) =>
          AppRouter.generateRoute(settings: settings, apiClient: apiClient),
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
