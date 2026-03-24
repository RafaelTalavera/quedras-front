import 'package:flutter/material.dart';

import '../../features/auth/application/auth_app_service.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/courts/application/court_app_service.dart';
import '../../features/home/presentation/shell_page.dart';
import '../../features/massages/application/massage_app_service.dart';
import '../../features/reservations/application/reservation_app_service.dart';
import 'app_routes.dart';

final class AppRouter {
  static Route<dynamic> generateRoute({
    required RouteSettings settings,
    required AuthAppService authAppService,
    required SessionController sessionController,
    required MassageAppService massageAppService,
    required ReservationAppService reservationAppService,
    required CourtAppService courtAppService,
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
        ? AppRoutes.tennisRental
        : routeName;
    final AppSection section = AppRoutes.sectionByRoute(resolvedRoute);

    return MaterialPageRoute<void>(
      builder: (_) => ShellPage(
        section: section,
        sessionController: sessionController,
        massageAppService: massageAppService,
        reservationAppService: reservationAppService,
        courtAppService: courtAppService,
      ),
      settings: settings,
    );
  }
}
