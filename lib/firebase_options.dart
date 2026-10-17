import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Generated or placeholder Firebase options for PalengkeGo.
/// Replace by running `flutterfire configure` for production credentials.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC8bEf_eTNv9lIWwk3MOk0PZ8f5_SKNkUo',
    appId: '1:817586589237:web:81b342a0df17aa55132b7c',
    messagingSenderId: '817586589237',
    projectId: 'palengkegodb',
    authDomain: 'palengkegodb.firebaseapp.com',
    storageBucket: 'palengkegodb.firebasestorage.app',
    measurementId: 'G-S0CDKZQPD6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgWf-iNxlmpnH03yl8GalPhzdzq3hsieE',
    appId: '1:817586589237:android:cee5422d2f7e85d2132b7c',
    messagingSenderId: '817586589237',
    projectId: 'palengkegodb',
    storageBucket: 'palengkegodb.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
    iosBundleId: 'com.example.palengkego',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: 'placeholder',
    messagingSenderId: 'placeholder',
    projectId: 'placeholder',
  );

  static bool get isPlaceholder =>
      web.apiKey == 'placeholder-run-flutterfire-configure';
}
