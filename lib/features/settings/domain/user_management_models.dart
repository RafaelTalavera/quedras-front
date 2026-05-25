enum ManagedUserRole { operator, supervisor }

extension ManagedUserRoleX on ManagedUserRole {
  String get apiValue {
    switch (this) {
      case ManagedUserRole.operator:
        return 'OPERATOR';
      case ManagedUserRole.supervisor:
        return 'SUPERVISOR';
    }
  }

  String get label {
    switch (this) {
      case ManagedUserRole.operator:
        return 'Operador';
      case ManagedUserRole.supervisor:
        return 'Supervisor';
    }
  }

  static ManagedUserRole fromApi(String rawValue) {
    switch (rawValue.trim().toUpperCase()) {
      case 'SUPERVISOR':
        return ManagedUserRole.supervisor;
      case 'OPERATOR':
      default:
        return ManagedUserRole.operator;
    }
  }
}

final class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.role,
    required this.enabled,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String username;
  final ManagedUserRole role;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final int? id = int.tryParse(json['id']?.toString() ?? '');
    final String username = json['username']?.toString().trim() ?? '';
    final String role = json['role']?.toString().trim() ?? '';
    final bool enabled = json['enabled'] == true;

    if (id == null) {
      throw const FormatException('id is required');
    }
    if (username.isEmpty) {
      throw const FormatException('username is required');
    }
    if (role.isEmpty) {
      throw const FormatException('role is required');
    }

    return ManagedUser(
      id: id,
      username: username,
      role: ManagedUserRoleX.fromApi(role),
      enabled: enabled,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

final class CreateManagedUserInput {
  const CreateManagedUserInput({
    required this.username,
    required this.password,
    required this.role,
    required this.enabled,
  });

  final String username;
  final String password;
  final ManagedUserRole role;
  final bool enabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username.trim(),
    'password': password,
    'role': role.apiValue,
    'enabled': enabled,
  };
}

final class UpdateManagedUserInput {
  const UpdateManagedUserInput({required this.role, required this.enabled});

  final ManagedUserRole role;
  final bool enabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.apiValue,
    'enabled': enabled,
  };
}

final class ResetManagedUserPasswordInput {
  const ResetManagedUserPasswordInput({required this.newPassword});

  final String newPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'newPassword': newPassword,
  };
}

final class ChangeOwnPasswordInput {
  const ChangeOwnPasswordInput({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}
