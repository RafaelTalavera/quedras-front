import 'default_api_base_url.dart' as default_base_url;

final class BackendConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'COSTANORTE_API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'QUEDRAS_API_BASE_URL',
      defaultValue: '',
    ),
  );

  static String get apiBaseUrl {
    final String override = _apiBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return default_base_url.defaultApiBaseUrl;
  }
}
