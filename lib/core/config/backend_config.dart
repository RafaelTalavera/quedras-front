import 'default_api_base_url.dart' as default_base_url;

final class BackendConfig {
  // El frontend solo resuelve la URL HTTP del backend.
  // No consume variables de base de datos como COSTANORTE_DB_* o QUADRAS_DB_*.
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

  static String get laundryV2BaseUrl {
    final Uri base = Uri.parse(apiBaseUrl);
    final List<String> segments = base.pathSegments
        .where((String segment) => segment.isNotEmpty)
        .toList();
    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1') {
      segments[segments.length - 1] = 'v2';
    } else {
      segments.addAll(const <String>['api', 'v2']);
    }
    segments.add('laundry');
    return base.replace(pathSegments: segments).toString();
  }
}
