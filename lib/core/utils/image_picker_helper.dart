import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

enum AttachmentSource { camera, gallery, file }

/// Reusable helper that shows a bottom sheet with Camera / Gallery / File options
/// and returns the picked [File], or null if cancelled.
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Shows source selection sheet then returns the picked file.
  static Future<File?> pickImage(BuildContext context) async {
    final source = await _showSourceSheet(context);
    if (source == null) return null;

    if (source == AttachmentSource.file) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      );
      if (result != null) {
        final platformFile = result.files.single;
        if (kIsWeb) {
          if (platformFile.bytes != null) {
            final xFile = XFile.fromData(platformFile.bytes!);
            return File('${xFile.path}#${platformFile.name}');
          }
          return File(platformFile.name);
        } else if (platformFile.path != null) {
          return File(platformFile.path!);
        }
        return File(platformFile.name);
      }
      return null;
    }

    final XFile? picked = await _picker.pickImage(
      source: source == AttachmentSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );

    if (picked == null) return null;
    if (kIsWeb) {
      return File('${picked.path}#${picked.name}');
    }
    return File(picked.path);
  }

  static Future<AttachmentSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Attachment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take a Photo',
                onTap: () => Navigator.pop(context, AttachmentSource.camera),
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () => Navigator.pop(context, AttachmentSource.gallery),
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.folder_rounded,
                label: 'Choose a Document/File',
                onTap: () => Navigator.pop(context, AttachmentSource.file),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.close_rounded,
                label: 'Cancel',
                isDestructive: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFECACA)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
