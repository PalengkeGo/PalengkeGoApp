import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<AppUser> register(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    // Write initial user document to Firestore.
    await _writeUserDoc(
      uid: user.uid,
      email: email,
      displayName: name,
      role: UserRole.customer, // New registrations are always customers.
    );

    // Update Firebase Auth display name.
    await user.updateDisplayName(name);

    return AppUser(
      uid: user.uid,
      email: email,
      displayName: name,
      role: UserRole.customer,
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
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
    final user = userCred.user!;
    // Ensure Firestore doc exists for new Google users.
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _writeUserDoc(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? googleUser.displayName ?? 'User',
        role: UserRole.customer,
      );
    }
    return _resolveUser(user);
  }

  @override
  Future<void> logout() async {
    await _ensureGoogleSignInInitialized();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
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
  }) async {
    final now = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name, // 'customer' or 'stall holder'
      'phoneNumber': null,
      'profilePhoto': null,
      'isVerified': false,
      'isBlocked': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  /// Maps the Firestore role string to a typed [UserRole].
  UserRole _roleFromString(String value) {
    switch (value.toLowerCase()) {
      case 'stall holder':
        return UserRole.vendor;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}
