import 'package:costanorte/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supervisor has full system section access', () {
    expect(
      AppRoutes.sectionsForRole('SUPERVISOR'),
      const <AppSection>[
        AppSection.tennisRental,
        AppSection.massageBooking,
        AppSection.toursTravel,
        AppSection.maintenance,
        AppSection.settings,
      ],
    );
  });

  test('supervisor can access every registered app section', () {
    for (final AppSection section in AppSection.values) {
      expect(AppRoutes.canAccessSection('SUPERVISOR', section), isTrue);
    }
  });
}
