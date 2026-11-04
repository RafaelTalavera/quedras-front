import 'package:flutter/material.dart';

import '../../features/auth/application/auth_app_service.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/courts/application/court_app_service.dart';
import '../../features/home/presentation/shell_page.dart';
import '../../features/massages/application/massage_app_service.dart';
import '../../features/maintenance/application/maintenance_app_service.dart';
import '../../features/laundry/application/laundry_app_service.dart';
import '../../features/laundry/application/hotel_laundry_app_service.dart';
import '../../features/laundry/application/provider_laundry_app_service.dart';
import '../../features/reservations/application/reservation_app_service.dart';
import '../../features/settings/application/user_management_app_service.dart';
import '../../features/tours/application/tours_app_service.dart';
import '../../core/sync/schedule_sync_service.dart';
import '../../core/push/push_notification_service.dart';
import 'app_routes.dart';

final class AppRouter {
  static Route<dynamic> generateRoute({
    required RouteSettings settings,
    required AuthAppService authAppService,
    required SessionController sessionController,
    required MassageAppService massageAppService,
    required ReservationAppService reservationAppService,
    required CourtAppService courtAppService,
    required ToursAppService toursAppService,
    required MaintenanceAppService maintenanceAppService,
    required LaundryAppService laundryAppService,
    required HotelLaundryAppService hotelLaundryAppService,
    required ProviderLaundryAppService providerLaundryAppService,
    required UserManagementAppService userManagementAppService,
    required ScheduleSyncService scheduleSyncService,
    required PushNotificationService pushNotificationService,
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

    final String sessionRole = sessionController.session?.role ?? 'OPERATOR';
    final List<AppSection> allowedSections = AppRoutes.sectionsForRole(
      sessionRole,
    );
    if (allowedSections.isEmpty) {
      sessionController.clearSession();
      return MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          authAppService: authAppService,
          sessionController: sessionController,
        ),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }
    final String requestedRoute = routeName == AppRoutes.login
        ? AppRoutes.defaultRouteForRole(sessionRole)
        : routeName;
    final AppSection requestedSection = AppRoutes.sectionByRoute(
      requestedRoute,
    );
    final AppSection section =
        AppRoutes.canAccessSection(sessionRole, requestedSection)
        ? requestedSection
        : allowedSections.first;

    return MaterialPageRoute<void>(
      builder: (_) => ShellPage(
        section: section,
        sessionController: sessionController,
        massageAppService: massageAppService,
        reservationAppService: reservationAppService,
        courtAppService: courtAppService,
        toursAppService: toursAppService,
        maintenanceAppService: maintenanceAppService,
        laundryAppService: laundryAppService,
        hotelLaundryAppService: hotelLaundryAppService,
        providerLaundryAppService: providerLaundryAppService,
        userManagementAppService: userManagementAppService,
        scheduleSyncService: scheduleSyncService,
        pushNotificationService: pushNotificationService,
      ),
      settings: RouteSettings(name: AppRoutes.routeBySection(section)),
    );
  }
}
