import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shown instead of the app when startup configuration is invalid for the
/// requested environment (e.g. a production build started without
/// `--dart-define=FIREBASE_ENABLED=true`). Never falls back silently.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: const Color(0xFFFCFCFD),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Startup configuration error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF475467),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
