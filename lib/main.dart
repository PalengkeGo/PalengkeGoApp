import 'core/services/data_refresh_signal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:riverpod/src/framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/messages/data/shared_messaging_store.dart';
import 'core/config/app_config.dart';
import 'core/config/app_environment.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_wrapper.dart';
import 'core/services/app_services.dart';
import 'core/services/preferences_provider.dart';
import 'core/presentation/pages/startup_error_screen.dart';
import 'core/infrastructure/firebase_service.dart';
import 'core/infrastructure/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.load();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Debug builds keep the full exception for development; release builds
    // must not render raw exception text to end users.
    final message = kReleaseMode
        ? 'Something went wrong. Please restart the app.'
        : details.exceptionAsString();
    return Material(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Color(0xFFB42318),
              ),
              const SizedBox(height: 12),
              const Text(
                'The app hit a widget error.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: Color(0xFF475467),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Production builds must be explicitly configured — never silently fall
  // back to mock repositories when the backend is required.
  final configError = config.validate();
  if (config.environment == AppEnvironment.production && configError != null) {
    runApp(StartupErrorScreen(message: configError));
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  Object? startupError;
  if (config.firebaseEnabled) {
    try {
      await FirebaseService.initialize();
    } catch (e) {
      startupError = e;
      if (kDebugMode) {
        debugPrint('[Startup] Firebase init failed: $e');
      }
    }
  }
  if (config.supabaseUrl.isNotEmpty && config.supabaseAnonKey.isNotEmpty) {
    try {
      await SupabaseService.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
      );
    } catch (e) {
      startupError ??= e;
      if (kDebugMode) {
        debugPrint('[Startup] Supabase init failed: $e');
      }
    }
  }

  if (config.environment == AppEnvironment.production && startupError != null) {
    runApp(
      StartupErrorScreen(message: 'Backend failed to start: $startupError'),
    );
    return;
  }

  // Pre-load the order store so the mock order book survives restarts, then
  // inject it through Riverpod instead of a global static.
  final orderStore = SharedOrderStore();
  await orderStore.load();

  final messagingStore = SharedMessagingStore();
  await messagingStore.load();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      orderStoreProvider.overrideWithValue(orderStore),
      sharedMessagingStoreProvider.overrideWithValue(messagingStore),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SafeVsyncProviderScope(
        child: PalengkeGoApp(),
      ),
    ),
  );
}

/// Prevents Riverpod 3.3.2 upstream bug (Issue #4805, PR #4816) where
/// `UncontrolledProviderScopeState` calls `setState()` during descendant
/// route transitions / `TickerMode` updates, throwing
/// `setState() or markNeedsBuild() called during build`.
///
/// Clearing `flutterVsyncs` causes Riverpod to safely fall back to its internal
/// `_DefaultVsync` (`Timer(Duration.zero)`), which safely schedules provider
/// refreshes outside of Flutter's active build phase.
class SafeVsyncProviderScope extends StatefulWidget {
  final Widget child;
  const SafeVsyncProviderScope({super.key, required this.child});

  @override
  State<SafeVsyncProviderScope> createState() => _SafeVsyncProviderScopeState();
}

class _SafeVsyncProviderScopeState extends State<SafeVsyncProviderScope> {
  @override
  void initState() {
    super.initState();
    _clearVsyncs();
  }

  @override
  void reassemble() {
    super.reassemble();
    _clearVsyncs();
  }

  void _clearVsyncs() {
    ProviderScope.containerOf(context, listen: false)
        .scheduler
        .flutterVsyncs
        .clear();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class PalengkeGoApp extends ConsumerWidget {
  const PalengkeGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(backendRefreshProvider, (previous, next) {});
    return MaterialApp(
      title: 'PalengkeGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        return ResponsiveWrapper(child: child!);
      },
    );
  }
}
