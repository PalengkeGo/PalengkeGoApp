import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:palengkego/features/auth/data/auth_repository.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';

/// Firebase implementation of [AuthRepository].
///
/// Connects to Firebase Auth for sign-in/register/logout and reads the
/// user's `role` field from the Firestore `users/{uid}` document to
/// construct a typed [AppUser].
///
/// Firestore schema (from docs/BACKEND_ARCHITECTURE.md):
/// ```
/// users/{uid}
///   uid          : String
///   email        : String
///   displayName  : String
///   role         : 'customer' | 'vendor' | 'admin'
///   createdAt    : Timestamp
///   updatedAt    : Timestamp
/// ```
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

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

    // Lightweight email-verification gate: does not block registration or
    // browsing, only checkout (enforced client-side in checkout + server-side
    // in the place-order edge function). Best-effort — a failed send must
    // not fail registration.
    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('sendEmailVerification failed: $e');
    }

    // Write initial user document to Firestore.
    await _writeUserDoc(
      uid: user.uid,
      email: email,
      displayName: name,
      phoneNumber: phoneNumber,
      role: UserRole.customer, // New registrations are always customers.
    );

    // Update Firebase Auth display name.
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
      // Web has no native Google session, so the google_sign_in host API
      // cannot show an account picker. Firebase's own popup flow uses the
      // project's web OAuth config and always shows the picker.
      final userCred = await _auth.signInWithPopup(GoogleAuthProvider());
      return _finalizeGoogleUser(userCred.user!);
    }

    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google Sign-In cancelled.');
      }
      rethrow;
    }
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return _finalizeGoogleUser(userCred.user!);
  }

  /// Ensures a Firestore doc exists for a new Google user, then resolves
  /// the typed [AppUser]. Shared by the web popup and native flows.
  Future<AppUser> _finalizeGoogleUser(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _writeUserDoc(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        phoneNumber: user.phoneNumber,
        role: UserRole.customer,
      );
    }
    return _resolveUser(user);
  }

  @override
  Future<void> logout() async {
    // Signing out of Google is best-effort: on the web it can throw when the
    // user signed in with email/password only (no Google session exists).
    // Firebase sign-out is the authoritative action and must always run.
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped (best-effort): $e');
    }
    await _auth.signOut();
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('You must be logged in to change your password.');
    }
    // Re-authenticate first so a wrong current password is rejected by
    // Firebase instead of being silently accepted.
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
      if (firebaseUser == null) return null;
      return _resolveUser(firebaseUser);
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fetches the Firestore `users/{uid}` doc and maps it to an [AppUser].
  /// Falls back to [UserRole.customer] if the doc doesn't exist yet.
  Future<AppUser> _resolveUser(User firebaseUser) async {
    final doc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    UserRole role = UserRole.customer;
    String? displayName =
        firebaseUser.displayName ?? firebaseUser.email?.split('@').first;
    String? phoneNumber;
    String? profilePhoto = firebaseUser.photoURL;
    bool isVerified = false;
    bool isBlocked = false;

    if (doc.exists) {
      final data = doc.data()!;
      role = _roleFromString(data['role'] as String? ?? 'customer');
      displayName = data['displayName'] as String? ?? displayName;
      phoneNumber = data['phoneNumber'] as String?;
      profilePhoto = data['profilePhoto'] as String? ?? profilePhoto;
      isVerified = data['isVerified'] as bool? ?? false;
      isBlocked = data['isBlocked'] as bool? ?? false;
    }

    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayName,
      role: role,
      phoneNumber: phoneNumber,
      profilePhoto: profilePhoto,
      isVerified: isVerified,
      isBlocked: isBlocked,
    );
  }

  /// Writes the initial `users/{uid}` document on first registration.
  Future<void> _writeUserDoc({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': _roleToString(role),
      'phoneNumber': phoneNumber,
      'profilePhoto': null,
      'isVerified': false,
      'isBlocked': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }
/// Maps a [UserRole] to the canonical Firestore string.
  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.vendor:
        return 'stall holder';
      case UserRole.admin:
        return 'admin';
      case UserRole.customer:
        return 'customer';
    }
  }

  /// Maps the Firestore role string to a typed [UserRole].
  UserRole _roleFromString(String value) {
    switch (value.toLowerCase()) {
      case 'stall holder':
        return UserRole.vendor;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}

/// Maps Firebase Auth error codes to user-friendly messages.
String friendlyAuthMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      case 'requires-recent-login':
        return 'Please log in again and try again.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
    }
    return error.message ?? error.code;
  }
  return error.toString();
}