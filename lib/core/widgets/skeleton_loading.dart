import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';

/// Sweeping gradient shimmer wrapper for skeleton placeholder widgets.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
      (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (!_isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTest) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Generic skeleton rectangle / pill block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final Color color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(8)),
      ),
    );
  }
}

/// Skeleton loading placeholder that matches the geometry and styling of [StallCard].
class VendorCardSkeleton extends StatelessWidget {
  const VendorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image Block with Status Chips
          Expanded(
            flex: 163,
            child: Stack(
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: SkeletonBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                // Top-right rating pill skeleton
                Positioned(
                  top: 8,
                  right: 8,
                  child: SkeletonBox(
                    width: 44,
                    height: 22,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                // Bottom-left status badge skeleton
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: SkeletonBox(
                    width: 52,
                    height: 22,
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Details Block
          Expanded(
            flex: 115,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category
                      SkeletonBox(
                        width: 56,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      // Stall Name
                      SkeletonBox(
                        width: 110,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      // Review row
                      SkeletonBox(
                        width: 70,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  // Location row
                  Row(
                    children: [
                      const SkeletonBox(
                        width: 12,
                        height: 12,
                        shape: BoxShape.circle,
                      ),
                      const SizedBox(width: 4),
                      SkeletonBox(
                        width: 60,
                        height: 9,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading placeholder for products. Supports both horizontal (Special Offers)
/// and vertical grid (Stall profile catalog) presentations.
class ProductCardSkeleton extends StatelessWidget {
  final bool isHorizontal;

  const ProductCardSkeleton({
    super.key,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return Container(
        width: 160,
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image
            Stack(
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: SkeletonBox(
                    width: 160,
                    height: 120,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: SkeletonBox(
                    width: 40,
                    height: 18,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            // Bottom Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 110,
                    height: 13,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  SkeletonBox(
                    width: 60,
                    height: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SkeletonBox(
                        width: 50,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(width: 6),
                      SkeletonBox(
                        width: 35,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Grid Product Card Skeleton
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          const Expanded(
            flex: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          // Info
          Expanded(
            flex: 80,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonBox(
                        width: 90,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      SkeletonBox(
                        width: 50,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(
                        width: 44,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SkeletonBox(
                        width: 26,
                        height: 26,
                        shape: BoxShape.circle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of [VendorCardSkeleton] wrapped in [SkeletonShimmer].
class VendorCardSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  const VendorCardSkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }
          return GridView.builder(
            padding: padding,
            shrinkWrap: true,
            physics: physics,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) => const VendorCardSkeleton(),
          );
        },
      ),
    );
  }
}

/// Horizontal scrollable row of [ProductCardSkeleton] wrapped in [SkeletonShimmer].
class ProductCardSkeletonRow extends StatelessWidget {
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const ProductCardSkeletonRow({
    super.key,
    this.itemCount = 4,
    this.height = 230,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          padding: padding,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) =>
              const ProductCardSkeleton(isHorizontal: true),
        ),
      ),
    );
  }
}

/// 2-column grid of [ProductCardSkeleton] wrapped in [SkeletonShimmer].
class ProductCardSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  const ProductCardSkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }
          return GridView.builder(
            padding: padding,
            shrinkWrap: true,
            physics: physics,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) => const ProductCardSkeleton(),
          );
        },
      ),
    );
  }
}
