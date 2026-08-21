import 'package:palengkego/features/auth/domain/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login(String email, String password, {UserRole role});
  Future<AppUser> register(
    String email,
    String password,
    String name, {
    String? phoneNumber,
  });
  Future<AppUser> signInWithGoogle();
  Future<void> logout();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Stream<AppUser?> authStateChanges();
}
