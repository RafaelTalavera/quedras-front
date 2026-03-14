final class BackendConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'COSTANORTE_API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'QUEDRAS_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/v1',
    ),
  );
}
