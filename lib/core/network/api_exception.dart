enum ApiErrorKind { http, network, timeout, transport, invalidResponse }

final class ApiException implements Exception {
  const ApiException(
    this.message, {
    required this.kind,
    this.statusCode,
    this.method,
    this.path,
    this.cause,
  });

  final String message;
  final ApiErrorKind kind;
  final int? statusCode;
  final String? method;
  final String? path;
  final Object? cause;

  @override
  String toString() => message;
}
