import 'package:costanorte/features/maintenance/application/maintenance_provider_selection.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prioriza contato WhatsApp pronto em todas as especialidades', () {
    final List<MaintenanceProvider> providers = <MaintenanceProvider>[];
    final Map<MaintenanceProviderSpecialty, int> readyIds =
        <MaintenanceProviderSpecialty, int>{};
    int id = 1;
    for (final MaintenanceProviderSpecialty specialty
        in MaintenanceProviderSpecialty.values) {
      final MaintenanceProviderType type =
          specialty == MaintenanceProviderSpecialty.generalMaintenance
          ? MaintenanceProviderType.internal
          : MaintenanceProviderType.external;
      providers.add(_provider(id++, specialty, type: type));
      final int readyId = id++;
      readyIds[specialty] = readyId;
      providers.add(
        _provider(
          readyId,
          specialty,
          type: type,
          whatsappNumber: '5548999998888',
          whatsappEnabled: true,
        ),
      );
    }

    final List<MaintenanceProvider> selected = canonicalMaintenanceProviders(
      providers,
    );
    expect(selected, hasLength(readyIds.length));
    for (final MaintenanceProvider provider in selected) {
      expect(provider.id, readyIds[provider.specialty]);
    }
  });

  test('não considera pronto um número inválido', () {
    final List<MaintenanceProvider> selected =
        canonicalMaintenanceProviders(<MaintenanceProvider>[
          _provider(
            1,
            MaintenanceProviderSpecialty.elevators,
            whatsappNumber: '123',
            whatsappEnabled: true,
          ),
          _provider(
            2,
            MaintenanceProviderSpecialty.elevators,
            whatsappNumber: '5548999998888',
            whatsappEnabled: true,
          ),
        ]);
    expect(selected.single.id, 2);
  });
}

MaintenanceProvider _provider(
  int id,
  MaintenanceProviderSpecialty specialty, {
  MaintenanceProviderType type = MaintenanceProviderType.external,
  String? whatsappNumber,
  bool whatsappEnabled = false,
}) => MaintenanceProvider(
  id: id,
  providerType: type,
  specialty: specialty,
  name: 'Prestador $id',
  serviceLabel: specialty.label,
  scopeDescription: null,
  contact: null,
  whatsappNumber: whatsappNumber,
  whatsappEnabled: whatsappEnabled,
  active: true,
  createdAt: null,
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
);
