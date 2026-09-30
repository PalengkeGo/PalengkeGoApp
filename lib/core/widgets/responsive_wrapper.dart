import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  /// Maximum content width on larger screens.
  static const double desktopBreakpoint = 960;

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
