import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Placeholder map background with a grid + road pattern.
class DeliveryAddressMapBackground extends StatelessWidget {
  final double width;
  final double height;

  const DeliveryAddressMapBackground({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Color(0xFFE8F4F8)),
      child: CustomPaint(painter: _MapGridPainter(), size: Size(width, height)),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1E7DD)
      ..strokeWidth = 1;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw some "roads" as thicker lines
    final roadPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 3;

    // Main roads
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.7, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.6),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
