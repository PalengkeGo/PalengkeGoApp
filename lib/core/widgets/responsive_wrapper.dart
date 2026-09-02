import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  /// Breakpoint above which the app renders as a centered phone-width slab.
  static const double desktopBreakpoint = 480;

  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= desktopBreakpoint) {
          return child;
        }
        return ColoredBox(
          color: Colors.grey.shade900,
          child: Center(
            child: SizedBox(
              width: desktopBreakpoint,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
