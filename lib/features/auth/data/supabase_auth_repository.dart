import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/auth/data/auth_repository.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Supabase implementation of [AuthRepository].
///
/// Uses Firebase Auth for authentication and Supabase for user profile storage.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;
  static bool _googleSignInInitialized = false;

  SupabaseClient _getSupabaseClient() => Supabase.instance.client;

  /// Maps a Supabase user record to [AppUser]
  AppUser _mapToAppUser(Map<String, dynamic> data, String uid) {
    final roleStr = data['role'] as String? ?? 'customer';
    UserRole role;
    switch (roleStr.toLowerCase()) {
      case 'vendor':
      case 'stallholder':
      case 'stall holder':
        role = UserRole.vendor;
        break;
      case 'admin':
        role = UserRole.admin;
        break;
      case 'customer':
      default:
        role = UserRole.customer;
        break;
    }

    final displayName =
        data['full_name'] as String? ?? data['displayName'] as String?;
    final phoneNumber =
        data['phone_number'] as String? ?? data['phoneNumber'] as String?;
    final profilePhoto =
        data['profile_photo'] as String? ?? data['profilePhoto'] as String?;
    final isVerified =
        data['is_verified'] as bool? ?? data['isVerified'] as bool? ?? false;
    final isBlocked =
        data['is_blocked'] as bool? ?? data['isBlocked'] as bool? ?? false;

    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: displayName,
      phoneNumber: phoneNumber,
      profilePhoto: profilePhoto,
      role: role,
      isVerified: isVerified,
      isBlocked: isBlocked,
    );
  }

  /// Writes the initial user document to Supabase on first registration.
  Future<void> _writeUserDoc({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    final now = DateTime.now().toIso8601String();
    final roleString = role == UserRole.vendor ? 'vendor' : role.name;

    try {
      await _getSupabaseClient().from('users').upsert({
        'user_id': uid,
        'email': email,
        'full_name': displayName,
        'role': roleString,
        'phone_number': phoneNumber,
        'profile_photo': null,
        'is_verified': false,
        'is_blocked': false,
        'created_at': now,
      }, onConflict: 'email');
    } catch (e) {
      debugPrint('Could not write user record to Supabase: $e');
      rethrow;
    }
  }

  @override
  Future<AppUser> login(
    String email,
    String password, {
    UserRole role = UserRole.customer,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return resolveUser(credential.user!);
  }

  @override
  Future<AppUser> register(
    String email,
    String password,
    String name, {
    String? phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('sendEmailVerification failed: $e');
    }

    await _writeUserDoc(
      uid: user.uid,
      email: email,
      displayName: name,
      phoneNumber: phoneNumber,
      role: UserRole.customer,
    );

    try {
      await user.updateDisplayName(name);
    } catch (_) {}

    return AppUser(
      uid: user.uid,
      email: email,
      displayName: name,
      phoneNumber: phoneNumber,
      role: UserRole.customer,
      isVerified: user.emailVerified,
    );
  }

  @override
  Future<AppUser> signInWithGoogle({bool useAnotherAccount = false}) async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      if (useAnotherAccount) {
        googleProvider.setCustomParameters({'prompt': 'select_account'});
      }
      final userCred = await _auth.signInWithPopup(googleProvider);
      return await _finalizeGoogleUser(userCred.user!);
    }

    if (useAnotherAccount) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      final userCred = await _auth.signInWithProvider(googleProvider);
      return await _finalizeGoogleUser(userCred.user!);
    }

    await _ensureGoogleSignInInitialized();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message:
            'Google Sign-In could not retrieve an ID token. Please verify your internet connection and Firebase configuration.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await _auth.signInWithCredential(credential);
    return await _finalizeGoogleUser(userCred.user!);
  }

  @override
  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No user is currently signed in');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ),
    );
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      return resolveUser(firebaseUser);
    });
  }

  Future<AppUser> resolveUser(User firebaseUser) async {
    final isGoogle = firebaseUser.providerData.any(
      (p) => p.providerId == 'google.com',
    );
    final email = firebaseUser.email?.trim() ?? '';
    try {
      final client = _getSupabaseClient();
      Map<String, dynamic>? response;
      try {
        response = await client
            .from('users')
            .select('*')
            .or('user_id.eq.${firebaseUser.uid},email.ilike.$email')
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[resolveUser] users query failed: $e');
      }

      bool hasApprovedStall = false;
      try {
        final stall = await client
            .from('stall_holders')
            .select('is_kyc_approved, kyc_status')
            .or(
              'user_id.eq.${firebaseUser.uid},stall_holder_id.eq.${firebaseUser.uid}',
            )
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (stall != null &&
            (stall['is_kyc_approved'] == true ||
                stall['kyc_status'] == 'approved')) {
          hasApprovedStall = true;
        }
      } catch (e) {
        debugPrint('[resolveUser] stall_holders query failed: $e');
      }

      if (response != null) {
        var user = _mapToAppUser(
          response,
          firebaseUser.uid,
        ).copyWith(isGoogleUser: isGoogle);
        if (hasApprovedStall || response['role'] == 'vendor') {
          user = user.copyWith(role: UserRole.vendor);
        }
        return user;
      }

      final determinedRole = hasApprovedStall
          ? UserRole.vendor
          : UserRole.customer;
      String? displayName =
          firebaseUser.displayName ??
          (email.isNotEmpty ? email.split('@').first : 'Customer');

      try {
        await client
            .from('users')
            .upsert({
              'user_id': firebaseUser.uid,
              'email': email,
              'full_name': displayName,
              'role': hasApprovedStall ? 'vendor' : 'customer',
              'phone_number': firebaseUser.phoneNumber,
              'profile_photo': firebaseUser.photoURL,
              'is_verified': firebaseUser.emailVerified,
              'is_blocked': false,
              'created_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id')
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[resolveUser] auto-upsert user failed: $e');
      }

      return AppUser(
        uid: firebaseUser.uid,
        email: email,
        displayName: displayName,
        phoneNumber: firebaseUser.phoneNumber,
        profilePhoto: firebaseUser.photoURL,
        role: determinedRole,
        isVerified: firebaseUser.emailVerified,
        isBlocked: false,
        isGoogleUser: isGoogle,
      );
    } catch (e) {
      debugPrint('Could not load user profile from Supabase: $e');
    }

    String? displayName =
        firebaseUser.displayName ??
        (email.isNotEmpty ? email.split('@').first : null);
    return AppUser(
      uid: firebaseUser.uid,
      email: email,
      displayName: displayName,
      phoneNumber: firebaseUser.phoneNumber,
      profilePhoto: firebaseUser.photoURL,
      role: UserRole.customer,
      isVerified: firebaseUser.emailVerified,
      isBlocked: false,
      isGoogleUser: isGoogle,
    );
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    final serverClientId = AppConfig.load().googleServerClientId;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    );
    _googleSignInInitialized = true;
  }

  Future<AppUser> _finalizeGoogleUser(User firebaseUser) async {
    final now = DateTime.now().toIso8601String();
    final email = firebaseUser.email?.trim() ?? '';
    try {
      final client = _getSupabaseClient();

      Map<String, dynamic>? existing;
      try {
        existing = await client
            .from('users')
            .select()
            .or('user_id.eq.${firebaseUser.uid},email.ilike.$email')
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      bool isVendorUser = false;
      try {
        final stall = await client
            .from('stall_holders')
            .select('is_kyc_approved, kyc_status')
            .or(
              'user_id.eq.${firebaseUser.uid},stall_holder_id.eq.${firebaseUser.uid}',
            )
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (stall != null &&
            (stall['is_kyc_approved'] == true ||
                stall['kyc_status'] == 'approved')) {
          isVendorUser = true;
        }
      } catch (_) {}

      if (existing == null) {
        // First-time Google user: create user row
        await client
            .from('users')
            .insert({
              'user_id': firebaseUser.uid,
              'email': email,
              'full_name':
                  firebaseUser.displayName ??
                  (email.split('@').first.isNotEmpty
                      ? email.split('@').first
                      : 'Customer'),
              'role': isVendorUser ? 'vendor' : 'customer',
              'phone_number': firebaseUser.phoneNumber,
              'profile_photo': firebaseUser.photoURL,
              'is_verified': firebaseUser.emailVerified,
              'is_blocked': false,
              'created_at': now,
            })
            .timeout(const Duration(seconds: 10));
      } else {
        // Returning Google user: ONLY update verified status and missing fields,
        // NEVER overwrite existing phone_number with null, and NEVER downgrade vendor role!
        final existingRole = (existing['role'] as String? ?? '').toLowerCase();
        final Map<String, dynamic> updates = {
          'is_verified': firebaseUser.emailVerified,
        };
        if (existing['user_id'] == null ||
            existing['user_id'] != firebaseUser.uid) {
          updates['user_id'] = firebaseUser.uid;
        }
        if ((existing['profile_photo'] == null ||
                (existing['profile_photo'] as String).isEmpty) &&
            firebaseUser.photoURL != null) {
          updates['profile_photo'] = firebaseUser.photoURL;
        }
        if ((existing['phone_number'] == null ||
                (existing['phone_number'] as String).isEmpty) &&
            firebaseUser.phoneNumber != null) {
          updates['phone_number'] = firebaseUser.phoneNumber;
        }
        if (isVendorUser && existingRole != 'vendor') {
          updates['role'] = 'vendor';
        }
        if (updates.isNotEmpty) {
          await client
              .from('users')
              .update(updates)
              .or('user_id.eq.${firebaseUser.uid},email.ilike.$email')
              .timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Could not finalize Google user in Supabase: $e');
    }
    return await resolveUser(firebaseUser);
  }
}
