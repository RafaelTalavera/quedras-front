enum AppSection { dashboard, schedule, newReservation }

final class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String schedule = '/agenda';
  static const String newReservation = '/reservas/nueva';

  static AppSection sectionByRoute(String route) {
    switch (route) {
      case schedule:
        return AppSection.schedule;
      case newReservation:
        return AppSection.newReservation;
      case dashboard:
      default:
        return AppSection.dashboard;
    }
  }

  static String routeBySection(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return dashboard;
      case AppSection.schedule:
        return schedule;
      case AppSection.newReservation:
        return newReservation;
    }
  }
}
