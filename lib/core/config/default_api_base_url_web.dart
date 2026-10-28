const String _productionApiBaseUrl =
    'https://quadras-back-production.up.railway.app/api/v1';

String get defaultApiBaseUrl {
  if (_looksLikeLocalFlutterDevServer(Uri.base)) {
    return 'http://127.0.0.1:8080/api/v1';
  }

  // En despliegues web publicados, el frontend consume Railway por defecto.
  return _productionApiBaseUrl;
}

bool _looksLikeLocalFlutterDevServer(Uri uri) {
  final String host = uri.host.toLowerCase();
  if (host != 'localhost' && host != '127.0.0.1') {
    return false;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  return uri.port != 0 && uri.port != 80 && uri.port != 443 && uri.port != 8080;
}
