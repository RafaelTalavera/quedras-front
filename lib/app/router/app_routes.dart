enum AppSection {
  massageBooking,
  tennisRental,
  toursTravel,
  maintenance,
  settings,
}

final class AppRoutes {
  static const String login = '/login';
  static const String tennisRental = '/quadras';
  static const String massageBooking = '/massagens';
  static const String toursTravel = '/tours';
  static const String maintenance = '/manutencao';
  static const String settings = '/configuracoes';

  static AppSection sectionByRoute(String route) {
    switch (route) {
      case massageBooking:
        return AppSection.massageBooking;
      case toursTravel:
        return AppSection.toursTravel;
      case maintenance:
        return AppSection.maintenance;
      case settings:
        return AppSection.settings;
      case tennisRental:
      default:
        return AppSection.tennisRental;
    }
  }

  static String routeBySection(AppSection section) {
    switch (section) {
      case AppSection.massageBooking:
        return massageBooking;
      case AppSection.tennisRental:
        return tennisRental;
      case AppSection.toursTravel:
        return toursTravel;
      case AppSection.maintenance:
        return maintenance;
      case AppSection.settings:
        return settings;
    }
  }

  static List<AppSection> sectionsForRole(String role) {
    final String normalizedRole = role.trim().toUpperCase();
    if (normalizedRole == 'SUPERVISOR') {
      return const <AppSection>[AppSection.settings];
    }
    return const <AppSection>[
      AppSection.tennisRental,
      AppSection.massageBooking,
      AppSection.toursTravel,
      AppSection.maintenance,
      AppSection.settings,
    ];
  }

  static bool canAccessSection(String role, AppSection section) {
    return sectionsForRole(role).contains(section);
  }

  static String defaultRouteForRole(String role) {
    return routeBySection(sectionsForRole(role).first);
  }
}
