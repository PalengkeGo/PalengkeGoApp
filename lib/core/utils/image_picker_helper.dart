import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palengkego/core/theme/app_theme.dart';

import 'package:path_provider/path_provider.dart';

enum AttachmentSource { camera, gallery }

/// Reusable helper that shows a bottom sheet with Camera / Gallery options
/// and returns the picked [File], or null if cancelled.
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  static final Map<String, Uint8List> _bytesCache = {};

  /// Reads bytes safely across Web and native without triggering UnsupportedError (_Namespace).
  static Future<Uint8List> readBytes(File file) async {
    if (kIsWeb) {
      final cached = _bytesCache[file.path];
      if (cached != null) return cached;
    }
    return file.readAsBytes();
  }

  /// Shows source selection sheet then returns the picked image.
  static Future<File?> pickImage(BuildContext context) async {
    final source = await _showSourceSheet(context);
    if (source == null) return null;

    final XFile? picked = await _picker.pickImage(
      source: source == AttachmentSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
    );

    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;

    if (kIsWeb) {
      final key = '${picked.path}#${picked.name}';
      _bytesCache[key] = bytes;
      _bytesCache[picked.path] = bytes;
      return File(key);
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${docDir.path}/app_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final ext = picked.name.contains('.') ? '.${picked.name.split('.').last}' : '.jpg';
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final persistentFile = File('${imagesDir.path}/$fileName');
      await persistentFile.writeAsBytes(bytes, flush: true);
      return persistentFile;
    } catch (_) {
      return File(picked.path);
    }
  }

  /// Converts a picked image file to a base64 Data URI for robust cross-session persistence.
  static Future<String?> fileToDataUri(File file) async {
    try {
      final bytes = await readBytes(file);
      if (bytes.isEmpty) return null;
      final ext = file.path.toLowerCase();
      final mime = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
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
