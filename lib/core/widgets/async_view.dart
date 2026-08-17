import 'package:flutter/material.dart';

/// Centered indeterminate progress indicator for async loading branches.
class AsyncLoadingView extends StatelessWidget {
  final Color? color;

  const AsyncLoadingView({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: color));
  }
}

/// Centered error message for async error branches.
class AsyncErrorView extends StatelessWidget {
  final String message;
  final TextStyle? style;

  const AsyncErrorView({super.key, required this.message, this.style});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, style: style));
  }
}
