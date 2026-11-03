final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.username,
    required this.role,
    this.laundryProviderId,
  });

  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final String username;
  final String role;
  final int? laundryProviderId;

  String get authorizationHeader => '$tokenType $accessToken';

  String get normalizedRole => role.trim().toUpperCase();

  bool get isSupervisor => normalizedRole == 'SUPERVISOR';

  bool get isOperator => normalizedRole == 'OPERATOR' || isSupervisor;

  bool get isProvider => normalizedRole == 'PROVIDER';

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final String accessToken = json['accessToken']?.toString().trim() ?? '';
    final String tokenType = json['tokenType']?.toString().trim() ?? 'Bearer';
    final int? expiresInSeconds = int.tryParse(
      json['expiresInSeconds']?.toString() ?? '',
    );
    final String username = json['username']?.toString().trim() ?? '';
    final String role = json['role']?.toString().trim() ?? '';
    final Object? rawLaundryProviderId = json['laundryProviderId'];
    final int? laundryProviderId = rawLaundryProviderId == null
        ? null
        : int.tryParse(rawLaundryProviderId.toString());

    if (accessToken.isEmpty) {
      throw const FormatException('accessToken is required');
    }
    if (tokenType.isEmpty) {
      throw const FormatException('tokenType is required');
    }
    if (expiresInSeconds == null || expiresInSeconds <= 0) {
      throw const FormatException(
        'expiresInSeconds must be a positive integer',
      );
    }
    if (username.isEmpty) {
      throw const FormatException('username is required');
    }
    if (role.isEmpty) {
      throw const FormatException('role is required');
    }
    if (rawLaundryProviderId != null &&
        (laundryProviderId == null || laundryProviderId <= 0)) {
      throw const FormatException(
        'laundryProviderId must be a positive integer',
      );
    }
    if (role.toUpperCase() == 'PROVIDER' && laundryProviderId == null) {
      throw const FormatException('laundryProviderId is required for PROVIDER');
    }

    return AuthSession(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresInSeconds: expiresInSeconds,
      username: username,
      role: role,
      laundryProviderId: laundryProviderId,
    );
  }
}
