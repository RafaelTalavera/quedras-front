import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/application/auth_app_service.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/reservations/application/reservation_app_service.dart';
import '../../features/home/presentation/shell_page.dart';
import 'app_routes.dart';

final class AppRouter {
  static Route<dynamic> generateRoute({
    required RouteSettings settings,
    required ApiClient apiClient,
    required AuthAppService authAppService,
    required SessionController sessionController,
    required ReservationAppService reservationAppService,
  }) {
    final String routeName = settings.name ?? AppRoutes.login;
    if (!sessionController.isAuthenticated) {
      return MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          authAppService: authAppService,
          sessionController: sessionController,
        ),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }

    final String resolvedRoute = routeName == AppRoutes.login
        ? AppRoutes.dashboard
        : routeName;
    final AppSection section = AppRoutes.sectionByRoute(resolvedRoute);

    return MaterialPageRoute<void>(
      builder: (_) => ShellPage(
        section: section,
        apiClient: apiClient,
        sessionController: sessionController,
        reservationAppService: reservationAppService,
      ),
      settings: settings,
    );
  }
}
