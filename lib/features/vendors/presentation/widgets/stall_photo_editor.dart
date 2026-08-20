// import 'dart:io'; (removed)
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';

class StallPhotoEditor extends ConsumerWidget {
  final String? bannerImage;
  final String? avatarImage;
  final String? thumbnailImage;
  final ValueChanged<String?> onBannerChanged;
  final ValueChanged<String?> onAvatarChanged;
  final ValueChanged<String?> onThumbnailChanged;

  const StallPhotoEditor({
    super.key,
    required this.bannerImage,
    required this.avatarImage,
    required this.thumbnailImage,
    required this.onBannerChanged,
    required this.onAvatarChanged,
    required this.onThumbnailChanged,
  });

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    String imageType,
    ValueChanged<String?> onChanged,
  ) async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file == null) return;
    final vendorId = ref.read(currentVendorIdProvider) ?? 'stall holder-001';
    try {
      final url = await ref.read(supabaseStorageServiceProvider).uploadFile(
        bucket: SupabaseStorageService.stallsBucket,
        path: '$vendorId/${SupabaseStorageService.objectName(imageType, file)}',
        file: file,
      );
      onChanged(url ?? file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _pickBanner(BuildContext context, WidgetRef ref) async {
    await _pickAndUpload(context, ref, 'banner', onBannerChanged);
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    await _pickAndUpload(context, ref, 'avatar', onAvatarChanged);
  }

  Future<void> _pickThumbnail(BuildContext context, WidgetRef ref) async {
    await _pickAndUpload(context, ref, 'thumbnail', onThumbnailChanged);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover photo / Background card
              GestureDetector(
                onTap: () => _pickBanner(context, ref),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5E7DE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    image: bannerImage != null && bannerImage!.isNotEmpty
                        ? DecorationImage(
                            image: adaptiveImageProvider(bannerImage)!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (bannerImage == null)
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 32,
                                color: AppTheme.primaryGreen,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add Cover Photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Profile Avatar bubble overlapping
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _pickAvatar(context, ref),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image:
                                avatarImage != null && avatarImage!.isNotEmpty
                                ? DecorationImage(
                                    image: adaptiveImageProvider(avatarImage)!,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: avatarImage == null || avatarImage!.isEmpty
                              ? const Icon(
                                  Icons.storefront_rounded,
                                  size: 38,
                                  color: AppTheme.primaryGreen,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _pickAvatar(context, ref),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Thumbnail Editor
        GestureDetector(
          onTap: () => _pickThumbnail(context, ref),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              image: thumbnailImage != null && thumbnailImage!.isNotEmpty
                  ? DecorationImage(
                      image: adaptiveImageProvider(thumbnailImage)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (thumbnailImage == null)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppTheme.primaryGreen,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add Market Thumbnail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This shows on the market stalls list',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
