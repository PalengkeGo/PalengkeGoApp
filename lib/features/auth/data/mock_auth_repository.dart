import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/features/auth/data/auth_repository.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository implements AuthRepository {
  AppUser? _currentUser;
  final _authStateController = StreamController<AppUser?>.broadcast();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _uidKey = 'mock_auth_uid';
  static const _roleKey = 'mock_auth_role';
  static const _emailKey = 'mock_auth_email';
  static const _nameKey = 'mock_auth_name';
  static const _photoKey = 'mock_auth_photo';

  MockAuthRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = await _storage.read(key: _uidKey);
      final roleString = await _storage.read(key: _roleKey);
      final savedEmail = await _storage.read(key: _emailKey);
      final savedName = await _storage.read(key: _nameKey);
      final savedPhoto = await _storage.read(key: _photoKey);

      if (uid != null && roleString != null) {
        final role = (roleString == 'stall holder' ||
                roleString == 'vendor' ||
                roleString == 'stallholder')
            ? UserRole.vendor
            : UserRole.customer;
        _currentUser = AppUser(
          uid: uid,
          email: savedEmail ??
              (role == UserRole.vendor
                  ? MockUsers.vendor.email
                  : MockUsers.customer.email),
          displayName: savedName ??
              (role == UserRole.vendor
                  ? MockUsers.vendor.displayName
                  : MockUsers.customer.displayName),
          profilePhoto: savedPhoto,
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
      await _storage.write(key: _emailKey, value: user.email);
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        await _storage.write(key: _nameKey, value: user.displayName!);
      }
      if (user.profilePhoto != null && user.profilePhoto!.isNotEmpty) {
        await _storage.write(key: _photoKey, value: user.profilePhoto!);
      }
    } catch (_) {
      // Session persistence is best-effort for the mock layer.
    }
  }

  Future<void> _clearSession() async {
    try {
      await _storage.delete(key: _uidKey);
      await _storage.delete(key: _roleKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _nameKey);
      await _storage.delete(key: _photoKey);
    } catch (_) {
      // Logging out must still clear the in-memory session when secure storage
      // is unavailable (for example, in a desktop preview or test runtime).
    }
  }

  @override
  Future<AppUser> login(
    String email,
    String password, {
    UserRole role = UserRole.customer,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final cleanEmail = email.trim().toLowerCase();
    final resolvedRole = (role == UserRole.vendor ||
            cleanEmail.contains('vendor') ||
            cleanEmail.contains('stall'))
        ? UserRole.vendor
        : role;

    final isDefaultMock = cleanEmail.isEmpty ||
        cleanEmail == MockUsers.customer.email ||
        cleanEmail == MockUsers.vendor.email;

    String resolvedUid = resolvedRole == UserRole.vendor
        ? 'stall holder-001'
        : (isDefaultMock ? 'customer-001' : 'user-${cleanEmail.hashCode.abs()}');
    String resolvedEmail = cleanEmail.isEmpty
        ? (resolvedRole == UserRole.vendor
              ? MockUsers.vendor.email
              : MockUsers.customer.email)
        : cleanEmail;
    String? resolvedName = resolvedRole == UserRole.vendor
        ? MockUsers.vendor.displayName
        : (isDefaultMock
              ? MockUsers.customer.displayName
              : cleanEmail.split('@').first);
    String? profilePhoto;

    // Check Supabase if client is initialized to load actual user info
    try {
      if (cleanEmail.isNotEmpty) {
        final client = Supabase.instance.client;
        final row = await client
            .from('users')
            .select('*')
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (row != null) {
          if (row['user_id'] != null) {
            resolvedUid = row['user_id'] as String;
          }
          final fullName = row['full_name'] as String?;
          if (fullName != null && fullName.trim().isNotEmpty) {
            resolvedName = fullName.trim();
          }
          final photo = row['profile_photo'] as String?;
          if (photo != null && photo.isNotEmpty) {
            profilePhoto = photo;
          }
        }
      }
    } catch (_) {}

    _currentUser = AppUser(
      uid: resolvedUid,
      email: resolvedEmail,
      displayName: resolvedName,
      profilePhoto: profilePhoto,
      role: resolvedRole,
    );
    await _saveSession(_currentUser!);
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> register(
    String email,
    String password,
    String name, {
    String? phoneNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = AppUser(
      uid: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: name,
      phoneNumber: phoneNumber,
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
  Future<AppUser> signInWithGoogle({bool useAnotherAccount = false}) async {
    // Mock: simulate a Google OAuth login as a customer.
    await Future.delayed(const Duration(milliseconds: 400));
    _currentUser = const AppUser(
      uid: 'google-mock-001',
      email: 'google.user@gmail.com',
      displayName: 'Google User',
      role: UserRole.customer,
      isGoogleUser: true,
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
