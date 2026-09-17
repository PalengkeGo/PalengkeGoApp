import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Converts Google Drive share links to direct image URLs.
/// Handles:
/// - https://drive.google.com/file/d/FILE_ID/view
/// - https://drive.google.com/uc?export=view&id=FILE_ID
/// - https://drive.google.com/uc?id=FILE_ID
/// - https://lh3.googleusercontent.com/... (pass-through)
String? _convertGoogleDriveUrl(String? url) {
  if (url == null || url.isEmpty) return null;

  // drive.google.com/file/d/FILE_ID/view
  final fileMatch = RegExp(r'drive\.google\.com/file/d/([^/]+)').firstMatch(url);
  if (fileMatch != null) {
    return 'https://drive.google.com/uc?export=view&id=${fileMatch.group(1)}';
  }

  // drive.google.com/uc?...id=FILE_ID
  final ucMatch = RegExp(r'drive\.google\.com/uc\?.*id=([^&]+)').firstMatch(url);
  if (ucMatch != null) {
    return 'https://drive.google.com/uc?export=view&id=${ucMatch.group(1)}';
  }

  // lh3.googleusercontent.com - already direct
  if (url.contains('lh3.googleusercontent.com')) {
    return url;
  }

  return url;
}

class AdaptiveImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;

  const AdaptiveImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _buildPlaceholder();
    }

    final resolvedPath = _convertGoogleDriveUrl(path!);

    if (resolvedPath == null || resolvedPath.isEmpty) {
      return _buildPlaceholder();
    }

    if (resolvedPath.startsWith('http://') || resolvedPath.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: resolvedPath,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (kIsWeb) {
      return Image.network(
        resolvedPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      return Image.file(
        File(resolvedPath),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.person, color: Colors.grey),
      ),
    );
  }
}

/// Helper for DecorationImage usage
ImageProvider? adaptiveImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  final resolvedPath = _convertGoogleDriveUrl(path);
  if (resolvedPath == null || resolvedPath.isEmpty) {
    return null;
  }
  if (resolvedPath.startsWith('http://') || resolvedPath.startsWith('https://')) {
    return CachedNetworkImageProvider(resolvedPath);
  }
  if (kIsWeb) {
    return NetworkImage(resolvedPath);
  } else {
    return FileImage(File(resolvedPath));
  }
}
