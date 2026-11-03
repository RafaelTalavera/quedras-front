import 'package:costanorte/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supervisor has full system section access', () {
    expect(AppRoutes.sectionsForRole('SUPERVISOR'), const <AppSection>[
      AppSection.tennisRental,
      AppSection.massageBooking,
      AppSection.toursTravel,
      AppSection.maintenance,
      AppSection.laundry,
      AppSection.settings,
    ]);
  });

  test('supervisor can access every registered app section', () {
    for (final AppSection section in AppSection.values) {
      expect(AppRoutes.canAccessSection('SUPERVISOR', section), isTrue);
    }
  });

  test('provider can only access laundry and starts there', () {
    expect(AppRoutes.sectionsForRole(' provider '), const <AppSection>[
      AppSection.laundry,
    ]);
    expect(AppRoutes.canAccessSection('PROVIDER', AppSection.laundry), isTrue);
    expect(
      AppRoutes.canAccessSection('PROVIDER', AppSection.maintenance),
      isFalse,
    );
    expect(AppRoutes.defaultRouteForRole('PROVIDER'), AppRoutes.laundry);
  });

  test('unknown roles do not receive an application section', () {
    expect(AppRoutes.sectionsForRole('UNKNOWN'), isEmpty);
    expect(AppRoutes.defaultRouteForRole('UNKNOWN'), AppRoutes.login);
  });
}
