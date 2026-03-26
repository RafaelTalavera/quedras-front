enum AppEnvironment { local, testRed, prod }

final class AppRuntimeConfig {
  static const String environmentName = String.fromEnvironment(
    'COSTANORTE_APP_ENV',
    defaultValue: 'local',
  );

  static const int _autoRefreshSecondsOverride = int.fromEnvironment(
    'COSTANORTE_AUTO_REFRESH_SECONDS',
    defaultValue: -1,
  );

  static AppEnvironment get environment {
    switch (environmentName.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'test-red':
      case 'test_red':
      case 'network':
      case 'red':
        return AppEnvironment.testRed;
      case 'local':
      default:
        return AppEnvironment.local;
    }
  }

  static Duration get operationalRefreshInterval {
    if (_autoRefreshSecondsOverride >= 0) {
      return Duration(seconds: _autoRefreshSecondsOverride);
    }
    switch (environment) {
      case AppEnvironment.local:
        return const Duration(seconds: 0);
      case AppEnvironment.testRed:
      case AppEnvironment.prod:
        return const Duration(seconds: 20);
    }
  }
}
