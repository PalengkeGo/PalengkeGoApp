import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';

class DashboardStallCard extends ConsumerWidget {
  final ValueChanged<bool> onToggleStallOpen;

  const DashboardStallCard({super.key, required this.onToggleStallOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stall = ref.watch(vendorStallProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFD5E7DE),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              image: stall.bannerImage != null && stall.bannerImage!.isNotEmpty
                  ? DecorationImage(
                      image: adaptiveImageProvider(stall.bannerImage)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: stall.bannerImage == null || stall.bannerImage!.isEmpty
                ? const ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AdaptiveImage(
                      'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (stall.avatarImage != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border),
                      image: DecorationImage(
                        image: adaptiveImageProvider(stall.avatarImage)!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stall.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stall.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      stall.isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stall.isOpen
                            ? AppTheme.statusOpen
                            : AppTheme.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: stall.isOpen,
                      onChanged: onToggleStallOpen,
                      activeThumbColor: AppTheme.primaryGreen,
                      activeTrackColor: AppTheme.primaryGreen.withValues(
                        alpha: 0.3,
                      ),
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
}
