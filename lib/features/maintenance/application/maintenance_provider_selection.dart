import '../../../core/whatsapp/manual_whatsapp_dialog.dart'
    show normalizeManualWhatsappNumber;
import '../domain/maintenance_models.dart';

/// Resolves the WhatsApp destination, including providers created before the
/// dedicated WhatsApp fields existed and whose phone is stored in `contact`.
/// An explicitly configured but disabled WhatsApp number remains disabled.
String? maintenanceProviderWhatsappNumber(MaintenanceProvider provider) {
  final String? explicitNumber = normalizeManualWhatsappNumber(
    provider.whatsappNumber,
  );
  if (provider.whatsappNumber != null) {
    return provider.whatsappEnabled ? explicitNumber : null;
  }
  return normalizeManualWhatsappNumber(provider.contact);
}

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
                maintenanceProviderWhatsappNumber(left) != null;
            final bool rightReady =
                maintenanceProviderWhatsappNumber(right) != null;
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
