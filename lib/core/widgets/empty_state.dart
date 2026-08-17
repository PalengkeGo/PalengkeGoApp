import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Centered empty-state block: optional icon inside a tinted container,
/// a title, and an optional subtitle.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final Color? iconBackground;
  final Color iconColor;
  final double iconSize;
  final double iconContainerSize;
  final double iconContainerRadius;
  final double iconSpacing;
  final String? title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final double subtitleSpacing;
  final EdgeInsets padding;

  const EmptyState({
    super.key,
    this.icon,
    this.iconBackground,
    this.iconColor = AppTheme.muted,
    this.iconSize = 36,
    this.iconContainerSize = 72,
    this.iconContainerRadius = 36,
    this.iconSpacing = 20,
    this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.subtitleSpacing = 8,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(iconContainerRadius),
                ),
                child: Icon(icon, size: iconSize, color: iconColor),
              ),
              SizedBox(height: iconSpacing),
            ],
            if (title != null)
              Text(title!, style: titleStyle, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              SizedBox(height: subtitleSpacing),
              Text(
                subtitle!,
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
