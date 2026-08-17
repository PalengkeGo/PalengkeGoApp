import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    if (path!.startsWith('http://') || path!.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path!,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (kIsWeb) {
      // On web, local paths picked by image_picker are blob URLs. We can use Image.network
      return Image.network(
        path!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      return Image.file(
        File(path!),
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
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return CachedNetworkImageProvider(path);
  }
  if (kIsWeb) {
    return NetworkImage(path);
  } else {
    return FileImage(File(path));
  }
}
