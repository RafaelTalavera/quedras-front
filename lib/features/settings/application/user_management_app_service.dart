import '../domain/user_management_models.dart';

abstract interface class UserManagementAppService {
  Future<List<ManagedUser>> listUsers();

  Future<ManagedUser> createUser(CreateManagedUserInput input);

  Future<ManagedUser> updateUser(int userId, UpdateManagedUserInput input);

  Future<void> resetPassword(int userId, ResetManagedUserPasswordInput input);

  Future<void> changeOwnPassword(ChangeOwnPasswordInput input);
}
