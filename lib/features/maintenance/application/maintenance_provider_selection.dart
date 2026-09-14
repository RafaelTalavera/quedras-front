import '../../../core/whatsapp/manual_whatsapp_dialog.dart'
    show normalizeManualWhatsappNumber;
import '../domain/maintenance_models.dart';

/// Keeps one visible provider per maintenance specialty, preferring a provider
/// whose manual WhatsApp contact is ready for the operator.
List<MaintenanceProvider> canonicalMaintenanceProviders(
  List<MaintenanceProvider> providers,
) {
  const List<MaintenanceProviderSpecialty> specialties =
      <MaintenanceProviderSpecialty>[
        MaintenanceProviderSpecialty.airConditioning,
        MaintenanceProviderSpecialty.elevators,
        MaintenanceProviderSpecialty.doorsAndWindows,
        MaintenanceProviderSpecialty.internet,
        MaintenanceProviderSpecialty.cameras,
        MaintenanceProviderSpecialty.telephones,
        MaintenanceProviderSpecialty.itSupport,
        MaintenanceProviderSpecialty.generalMaintenance,
      ];
  final List<MaintenanceProvider> result = <MaintenanceProvider>[];
  for (final MaintenanceProviderSpecialty specialty in specialties) {
    final List<MaintenanceProvider> matches =
        providers
            .where(
              (MaintenanceProvider provider) =>
                  provider.specialty == specialty &&
                  (specialty !=
                          MaintenanceProviderSpecialty.generalMaintenance ||
                      provider.providerType ==
                          MaintenanceProviderType.internal),
            )
            .toList()
          ..sort((MaintenanceProvider left, MaintenanceProvider right) {
            if (left.active != right.active) {
              return left.active ? -1 : 1;
            }
            final bool leftReady =
                left.whatsappEnabled &&
                normalizeManualWhatsappNumber(left.whatsappNumber) != null;
            final bool rightReady =
                right.whatsappEnabled &&
                normalizeManualWhatsappNumber(right.whatsappNumber) != null;
            if (leftReady != rightReady) {
              return leftReady ? -1 : 1;
            }
            return left.id.compareTo(right.id);
          });
    if (matches.isNotEmpty) {
      result.add(matches.first);
    }
  }
  return result;
}
