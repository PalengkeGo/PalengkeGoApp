import 'package:palengkego/features/auth/domain/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login(String email, String password, {UserRole role});
  Future<AppUser> register(String email, String password, String name);
  Future<AppUser> signInWithGoogle();
  Future<void> logout();
  Stream<AppUser?> authStateChanges();
}
