String get defaultApiBaseUrl {
  if (_looksLikeLocalFlutterDevServer(Uri.base)) {
    return 'http://127.0.0.1:8091/api/v1';
  }

  final Uri apiUri = Uri.base.resolve('/api/v1');
  final String url = apiUri.toString();
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

bool _looksLikeLocalFlutterDevServer(Uri uri) {
  final String host = uri.host.toLowerCase();
  if (host != 'localhost' && host != '127.0.0.1') {
    return false;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  return uri.port != 0 && uri.port != 80 && uri.port != 443 && uri.port != 8091;
}
