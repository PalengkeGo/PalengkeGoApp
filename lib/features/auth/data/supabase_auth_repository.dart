import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:palengkego/features/auth/data/auth_repository.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Supabase implementation of [AuthRepository].
///
/// Uses Firebase Auth for authentication and Supabase for user profile storage.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required FirebaseAuth auth,
  }) : _auth = auth;

  final FirebaseAuth _auth;
  static bool _googleSignInInitialized = false;

  SupabaseClient _getSupabaseClient() => Supabase.instance.client;

  /// Maps a Supabase user record to [AppUser]
  AppUser _mapToAppUser(Map<String, dynamic> data, String uid) {
    final roleStr = data['role'] as String? ?? 'customer';
    UserRole role;
    switch (roleStr.toLowerCase()) {
      case 'vendor':
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

    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      profilePhoto: data['profilePhoto'] as String?,
      role: role,
      isVerified: data['isVerified'] as bool? ?? false,
      isBlocked: data['isBlocked'] as bool? ?? false,
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
    final roleString =
        role == UserRole.vendor ? 'stall holder' : role.name;

    await _getSupabaseClient().from('users').upsert({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': roleString,
      'phoneNumber': phoneNumber,
      'profilePhoto': null,
      'isVerified': false,
      'isBlocked': false,
      'createdAt': now,
      'updatedAt': now,
    });
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
    return _resolveUser(credential.user!);
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

    await user.updateDisplayName(name);

    return AppUser(
      uid: user.uid,
      email: email,
      displayName: name,
      phoneNumber: phoneNumber,
      role: UserRole.customer,
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      final userCred = await _auth.signInWithPopup(GoogleAuthProvider());
      return await _finalizeGoogleUser(userCred.user!);
    }
    await _ensureGoogleSignInInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return await _finalizeGoogleUser(userCred.user!);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
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
      return _resolveUser(firebaseUser);
    });
  }

  Future<AppUser> _resolveUser(User firebaseUser) async {
    try {
      final response = await _getSupabaseClient()
          .from('users')
          .select('*')
          .eq('uid', firebaseUser.uid)
          .single();

      return _mapToAppUser(response, firebaseUser.uid);
    } catch (e) {
      debugPrint('Could not load user profile from Supabase: $e');
    }

    String? displayName =
        firebaseUser.displayName ?? firebaseUser.email?.split('@').first;
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayName,
      phoneNumber: null,
      profilePhoto: firebaseUser.photoURL,
      role: UserRole.customer,
      isVerified: firebaseUser.emailVerified,
      isBlocked: false,
    );
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  Future<AppUser> _finalizeGoogleUser(User firebaseUser) async {
    return await _resolveUser(firebaseUser);
  }
}