import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/home/presentation/shell_page.dart';
import 'app_routes.dart';

final class AppRouter {
  static Route<dynamic> generateRoute({
    required RouteSettings settings,
    required ApiClient apiClient,
  }) {
    final String routeName = settings.name ?? AppRoutes.dashboard;
    final AppSection section = AppRoutes.sectionByRoute(routeName);

    return MaterialPageRoute<void>(
      builder: (_) => ShellPage(section: section, apiClient: apiClient),
      settings: settings,
    );
  }
}
