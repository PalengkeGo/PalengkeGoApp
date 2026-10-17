import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/preferences_provider.dart';

/// Market onboarding screen with a focused image, copy, and primary action.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const Color primaryDarkGreen = Color(0xFF073B2C);
  static const Color buttonGreen = Color(0xFF07503A);
  static const Color buttonGreenHover = Color(0xFF0B634A);
  static const Color freshGreenAccent = Color(0xFF58A83B);
  static const Color supportingText = Color(0xFF667085);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: Image(
                image: AssetImage('assets/images/onboarding-background.png'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isSmall = width < 360;
                final isShort = constraints.maxHeight < 700;
                final imageWidth = isSmall
                    ? (width - 40).clamp(260.0, 320.0).toDouble()
                    : (width * 0.88).clamp(280.0, 350.0).toDouble();
                final imageHeight = isShort
                    ? (imageWidth * 0.86).clamp(210.0, 270.0).toDouble()
                    : imageWidth;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 20 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MarketImage(width: imageWidth, height: imageHeight),
                                SizedBox(height: isShort ? 16 : 24),
                                _Headline(isSmall: isSmall),
                                const SizedBox(height: 12),
                                Text(
                                  'Find fresh produce and local goods from the comfort of your home.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSmall ? 14 : 15,
                                    height: 1.45,
                                    color: supportingText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _GetStartedButton(
                          onPressed: () async {
                            final preferences = ref.read(sharedPreferencesProvider);
                            await preferences.setBool('hasSeenOnboarding', true);
                            if (context.mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.main);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _MarketImage extends StatelessWidget {
  const _MarketImage({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: OnboardingScreen.primaryDarkGreen.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/ncpm-onboarding.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: OnboardingScreen.primaryDarkGreen,
              child: Center(child: Icon(Icons.storefront_outlined, size: 96, color: Colors.white70)),
            ),
          ),
        ),
      );
}

class _Headline extends StatelessWidget {
  const _Headline({required this.isSmall});
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: isSmall ? 22 : 26,
      fontWeight: FontWeight.w700,
      color: OnboardingScreen.primaryDarkGreen,
      height: 1.25,
      letterSpacing: -0.4,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Browse your favorite ', style: style),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: 3),
              child: CustomPaint(size: Size(22, 22), painter: _TwoLeavesPainter(color: OnboardingScreen.freshGreenAccent)),
            ),
          ),
          TextSpan(text: '\nwet market stalls anytime', style: style),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _isPressed ? 0.98 : (_isHovered ? 1.01 : 1),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: OnboardingScreen.buttonGreen.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: _isHovered ? OnboardingScreen.buttonGreenHover : OnboardingScreen.buttonGreen,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              key: const Key('get_started_button'),
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => _isPressed = value),
              onHover: (value) => setState(() => _isHovered = value),
              borderRadius: BorderRadius.circular(28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get Started', style: GoogleFonts.plusJakartaSans(fontSize: 16.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TwoLeavesPainter extends CustomPainter {
  const _TwoLeavesPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final uprightLeaf = Path()
      ..moveTo(size.width * 0.15, size.height * 0.85)
      ..quadraticBezierTo(size.width * 0.05, size.height * 0.35, size.width * 0.40, size.height * 0.15)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.45, size.width * 0.15, size.height * 0.85)
      ..close();
    canvas.drawPath(uprightLeaf, paint);
    final sideLeaf = Path()
      ..moveTo(size.width * 0.30, size.height * 0.85)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.50, size.width * 0.95, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.80, size.width * 0.30, size.height * 0.85)
      ..close();
    canvas.drawPath(sideLeaf, paint);
  }

  @override
  bool shouldRepaint(covariant _TwoLeavesPainter oldDelegate) => oldDelegate.color != color;
}
