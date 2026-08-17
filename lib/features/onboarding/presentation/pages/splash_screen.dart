import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/core/services/preferences_provider.dart';

/// Splash screen — always visible for at least [_minDuration].
/// Animates the logo (scale + fade), tagline (slide + fade), and
/// a pulsing dot-row loading indicator in sequence.
/// Navigation fires only after BOTH the animation AND the minimum
/// duration have elapsed, so the splash is never skipped.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDuration = Duration(milliseconds: 2800);

  late final AnimationController _ctrl;

  // Logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // App name
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;

  // Tagline
  late final Animation<double> _tagFade;

  // Dots loader
  late final Animation<double> _dotsFade;

  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ── Logo: scale 0.6→1 + fade in (0–40% of timeline) ────────────────
    _logoScale = Tween<double>(begin: 0.60, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.40, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // ── App name: slide up + fade in (25–55%) ───────────────────────────
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _nameSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
          ),
        );

    // ── Tagline: fade in (45–70%) ────────────────────────────────────────
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 0.70, curve: Curves.easeOut),
      ),
    );

    // ── Dots: fade in (70–100%) ──────────────────────────────────────────
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();

    // Minimum display timer
    Future.delayed(_minDuration, () {
      if (!mounted) return;
      setState(() => _minElapsed = true);
      _maybeNavigate();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeNavigate() {
    if (!_minElapsed || !mounted) return;
    _navigate();
  }

  void _navigate() {
    final user = ref.read(authProvider);
    if (user != null) {
      if (user.isVendor) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.vendorDashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.main);
      }
    } else {
      final prefs = ref.read(sharedPreferencesProvider);
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      if (hasSeenOnboarding) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.main);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ── Logo ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/images/logonobg.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // ── App name ─────────────────────────────────────────────
                  FadeTransition(
                    opacity: _nameFade,
                    child: SlideTransition(
                      position: _nameSlide,
                      child: const Center(
                        child: Text(
                          'PalengkeGo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Tagline ───────────────────────────────────────────────
                  FadeTransition(
                    opacity: _tagFade,
                    child: Center(
                      child: Text(
                        'SKIP THE ROAM, ORDER FROM HOME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Animated dot loader ───────────────────────────────────
                  FadeTransition(
                    opacity: _dotsFade,
                    child: const _PulsingDots(),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Pulsing three-dot loader ──────────────────────────────────────────────────

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _dotAnim(int index) {
    final start = index * 0.20;
    return Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          start,
          (start + 0.5).clamp(0, 1),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: _dotAnim(i).value,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
