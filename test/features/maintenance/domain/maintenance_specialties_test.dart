import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Internet e Portas e janelas têm especialidades distintas', () {
    expect(MaintenanceProviderSpecialty.internet.apiValue, 'INTERNET');
    expect(MaintenanceProviderSpecialty.internet.label, 'Internet');
    expect(
      MaintenanceProviderSpecialty.doorsAndWindows.apiValue,
      'DOORS_AND_WINDOWS',
    );
    expect(
      MaintenanceProviderSpecialty.doorsAndWindows.label,
      'Portas e janelas',
    );

    final MaintenanceProvider internet = MaintenanceProvider.fromJson(
      <String, dynamic>{'id': 1, 'specialty': 'INTERNET'},
    );
    final MaintenanceProvider doors = MaintenanceProvider.fromJson(
      <String, dynamic>{'id': 2, 'specialty': 'DOORS_AND_WINDOWS'},
    );
    expect(internet.specialty, MaintenanceProviderSpecialty.internet);
    expect(doors.specialty, MaintenanceProviderSpecialty.doorsAndWindows);
  });

  test('cadastro envia o código da especialidade de Portas e janelas', () {
    const CreateMaintenanceProviderModel model = CreateMaintenanceProviderModel(
      providerType: MaintenanceProviderType.external,
      specialty: MaintenanceProviderSpecialty.doorsAndWindows,
      name: 'Prestador de portas',
      serviceLabel: 'Manutenção de fechaduras',
      scopeDescription: null,
      contact: null,
      active: true,
    );
    expect(model.toJson()['specialty'], 'DOORS_AND_WINDOWS');
  });

  test('Câmeras, Telefones e TI têm códigos próprios no contrato', () {
    const Map<MaintenanceProviderSpecialty, String> expected =
        <MaintenanceProviderSpecialty, String>{
          MaintenanceProviderSpecialty.cameras: 'CAMERAS',
          MaintenanceProviderSpecialty.telephones: 'TELEPHONES',
          MaintenanceProviderSpecialty.itSupport: 'IT_SUPPORT',
        };
    for (final MapEntry<MaintenanceProviderSpecialty, String> entry
        in expected.entries) {
      expect(entry.key.apiValue, entry.value);
      expect(
        MaintenanceProvider.fromJson(<String, dynamic>{
          'specialty': entry.value,
        }).specialty,
        entry.key,
      );
      expect(
        CreateMaintenanceProviderModel(
          providerType: MaintenanceProviderType.external,
          specialty: entry.key,
          name: entry.key.label,
          serviceLabel: entry.key.label,
          scopeDescription: null,
          contact: null,
          active: true,
        ).toJson()['specialty'],
        entry.value,
      );
    }
  });
}
