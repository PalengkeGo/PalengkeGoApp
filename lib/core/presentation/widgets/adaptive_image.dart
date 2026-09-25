import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';

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
    final resolvedPath = resolveImageUrl(path);
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return _buildPlaceholder();
    }

    if (resolvedPath.startsWith('assets/')) {
      return Image.asset(
        resolvedPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
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
      // On web, local paths picked by image_picker are blob URLs. We can use Image.network
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
  final resolvedPath = resolveImageUrl(path);
  if (resolvedPath == null || resolvedPath.isEmpty) {
    return null;
  }
  if (resolvedPath.startsWith('assets/')) {
    return AssetImage(resolvedPath);
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

