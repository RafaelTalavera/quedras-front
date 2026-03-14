final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.username,
    required this.role,
  });

  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final String username;
  final String role;

  String get authorizationHeader => '$tokenType $accessToken';

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final String accessToken = json['accessToken']?.toString().trim() ?? '';
    final String tokenType = json['tokenType']?.toString().trim() ?? 'Bearer';
    final int? expiresInSeconds = int.tryParse(
      json['expiresInSeconds']?.toString() ?? '',
    );
    final String username = json['username']?.toString().trim() ?? '';
    final String role = json['role']?.toString().trim() ?? '';

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

    return AuthSession(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresInSeconds: expiresInSeconds,
      username: username,
      role: role,
    );
  }
}
