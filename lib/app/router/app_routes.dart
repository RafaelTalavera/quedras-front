enum AppSection {
  massageBooking,
  tennisRental,
  toursTravel,
  maintenance,
  laundry,
  settings,
}

final class AppRoutes {
  static const List<AppSection> _fullSystemSections = <AppSection>[
    AppSection.tennisRental,
    AppSection.massageBooking,
    AppSection.toursTravel,
    AppSection.maintenance,
    AppSection.laundry,
    AppSection.settings,
  ];
  static const List<AppSection> _providerSections = <AppSection>[
    AppSection.laundry,
  ];

  static const String login = '/login';
  static const String tennisRental = '/quadras';
  static const String massageBooking = '/massagens';
  static const String toursTravel = '/tours';
  static const String maintenance = '/manutencao';
  static const String laundry = '/lavanderia';
  static const String settings = '/configuracoes';

  static AppSection sectionByRoute(String route) {
    switch (route) {
      case massageBooking:
        return AppSection.massageBooking;
      case toursTravel:
        return AppSection.toursTravel;
      case maintenance:
        return AppSection.maintenance;
      case laundry:
        return AppSection.laundry;
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
      case AppSection.laundry:
        return laundry;
      case AppSection.settings:
        return settings;
    }
  }

  static List<AppSection> sectionsForRole(String role) {
    final String normalizedRole = role.trim().toUpperCase();
    if (normalizedRole == 'SUPERVISOR' || normalizedRole == 'OPERATOR') {
      return _fullSystemSections;
    }
    if (normalizedRole == 'PROVIDER') {
      return _providerSections;
    }
    return const <AppSection>[];
  }

  static bool canAccessSection(String role, AppSection section) {
    return sectionsForRole(role).contains(section);
  }

  static String defaultRouteForRole(String role) {
    final List<AppSection> sections = sectionsForRole(role);
    return sections.isEmpty ? login : routeBySection(sections.first);
  }
}
