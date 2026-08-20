import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/features/auth/data/auth_repository.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';

class MockAuthRepository implements AuthRepository {
  AppUser? _currentUser;
  final _authStateController = StreamController<AppUser?>.broadcast();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _uidKey = 'mock_auth_uid';
  static const _roleKey = 'mock_auth_role';

  MockAuthRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = await _storage.read(key: _uidKey);
      final roleString = await _storage.read(key: _roleKey);

      if (uid != null && roleString != null) {
        final role = roleString == 'stall holder'
            ? UserRole.vendor
            : UserRole.customer;
        _currentUser = AppUser(
          uid: uid,
          email: role == UserRole.vendor
              ? MockUsers.vendor.email
              : MockUsers.customer.email,
          displayName: role == UserRole.vendor
              ? MockUsers.vendor.displayName
              : MockUsers.customer.displayName,
          role: role,
        );
        _authStateController.add(_currentUser);
      }
    } catch (_) {
      // Secure storage unavailable (e.g. in tests) — start logged out.
      _currentUser = null;
    }
  }

  Future<void> _saveSession(AppUser user) async {
    try {
      await _storage.write(key: _uidKey, value: user.uid);
      await _storage.write(
        key: _roleKey,
        value: user.role == UserRole.vendor ? 'stall holder' : 'customer',
      );
    } catch (_) {
      // Session persistence is best-effort for the mock layer.
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: _uidKey);
    await _storage.delete(key: _roleKey);
  }

  @override
  Future<AppUser> login(
    String email,
    String password, {
    UserRole role = UserRole.customer,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = AppUser(
      uid: role == UserRole.vendor ? 'stall holder-001' : 'customer-001',
      email: email.isEmpty
          ? (role == UserRole.vendor
                ? MockUsers.vendor.email
                : MockUsers.customer.email)
          : email,
      displayName: role == UserRole.vendor
          ? MockUsers.vendor.displayName
          : MockUsers.customer.displayName,
      role: role,
    );
    await _saveSession(_currentUser!);
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> register(String email, String password, String name) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = AppUser(
      uid: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: name,
      role: UserRole.customer,
    );
    await _saveSession(_currentUser!);
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    await _clearSession();
    _authStateController.add(null);
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    // Mock has no real password store — accept any value so demos can flow.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    // Mock: simulate a Google OAuth login as a customer.
    await Future.delayed(const Duration(milliseconds: 400));
    _currentUser = const AppUser(
      uid: 'google-mock-001',
      email: 'google.user@gmail.com',
      displayName: 'Google User',
      role: UserRole.customer,
    );
    await _saveSession(_currentUser!);
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }
}
