import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/data/firebase_auth_repository.dart';

void main() {
  group('friendlyAuthMessage', () {
    test('maps common auth codes to user-friendly text', () {
      expect(
        friendlyAuthMessage(FirebaseAuthException(code: 'wrong-password')),
        'Current password is incorrect.',
      );
      expect(
        friendlyAuthMessage(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        'Current password is incorrect.',
      );
      expect(
        friendlyAuthMessage(FirebaseAuthException(code: 'weak-password')),
        'New password is too weak.',
      );
      expect(
        friendlyAuthMessage(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        'No account found with this email.',
      );
      expect(
        friendlyAuthMessage(
          FirebaseAuthException(code: 'invalid-login-credentials'),
        ),
        'Incorrect email or password.',
      );
      expect(
        friendlyAuthMessage(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        'An account with this email already exists.',
      );
    });

    test('falls back to the raw message for unknown codes', () {
      expect(
        friendlyAuthMessage(FirebaseAuthException(code: 'x', message: 'boom')),
        'boom',
      );
      expect(friendlyAuthMessage('just a string'), 'just a string');
    });
  });
}