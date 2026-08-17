import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Bottom cancel button with live countdown, shown while the order
/// can still be cancelled.
class OrderDetailsCancelBar extends StatelessWidget {
  final Duration timeRemaining;
  final VoidCallback onPressed;

  const OrderDetailsCancelBar({
    super.key,
    required this.timeRemaining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              'Cancel Order (${timeRemaining.inMinutes.toString().padLeft(2, '0')}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
