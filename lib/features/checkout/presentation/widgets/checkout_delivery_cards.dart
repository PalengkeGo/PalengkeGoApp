import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class CheckoutDeliveryAddressCard extends StatelessWidget {
  const CheckoutDeliveryAddressCard({
    super.key,
    required this.deliveryAddress,
    required this.onChange,
  });

  final DeliveryAddress deliveryAddress;
  final VoidCallback onChange;

  IconData? _getIconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower == 'home') return Icons.home_rounded;
    if (lower == 'work') return Icons.work_rounded;
    if (lower == 'school') return Icons.school_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIconForLabel(deliveryAddress.label);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Header Snippet
          SizedBox(
            height: 90,
            width: double.infinity,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD9FBE6), Color(0xFFE9F7EF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _MapPatternPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.place_rounded,
                    size: 32,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          // Address details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppTheme.textSecondary, size: 20),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deliveryAddress.label.isNotEmpty
                            ? deliveryAddress.label
                            : 'Delivery Address',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deliveryAddress.displayLine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onChange,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height);

    path.moveTo(size.width * 0.2, 0);
    path.lineTo(size.width, size.height * 0.8);

    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
