import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform keychain-backed storage (iOS Keychain / Android
/// EncryptedSharedPreferences).
///
/// Used for PII (addresses, order history, mock session) instead of
/// [SharedPreferences], which stores data in plaintext.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);
