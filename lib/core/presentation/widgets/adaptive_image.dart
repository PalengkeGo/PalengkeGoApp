import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';

class AdaptiveImage extends StatelessWidget {
  final String? path;
  final String? fallbackPath;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;

  const AdaptiveImage(
    this.path, {
    super.key,
    this.fallbackPath,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPath = resolveImageUrl(path);
    if (resolvedPath == null || resolvedPath.isEmpty) {
      if (fallbackPath != null && fallbackPath!.isNotEmpty) {
        return AdaptiveImage(
          fallbackPath,
          fit: fit,
          width: width,
          height: height,
          placeholder: placeholder,
        );
      }
      return _buildPlaceholder();
    }

    if (resolvedPath.startsWith('data:image/')) {
      try {
        final commaIndex = resolvedPath.indexOf(',');
        if (commaIndex != -1) {
          final bytes = base64Decode(resolvedPath.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      } catch (_) {}
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
      if (kIsWeb) {
        return Image.network(
          resolvedPath,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder(isLoading: true);
          },
          errorBuilder: (context, error, stackTrace) {
            if (resolvedPath.contains('drive.google.com') ||
                resolvedPath.contains('googleusercontent.com')) {
              final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(resolvedPath) ??
                  RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedPath);
              if (idMatch != null) {
                final fileId = idMatch.group(1);
                final altUrl = resolvedPath.contains('thumbnail')
                    ? 'https://lh3.googleusercontent.com/d/$fileId'
                    : 'https://drive.google.com/thumbnail?sz=w1000&id=$fileId';
                if (altUrl != resolvedPath) {
                  return AdaptiveImage(
                    altUrl,
                    fallbackPath: fallbackPath,
                    fit: fit,
                    width: width,
                    height: height,
                    placeholder: placeholder,
                  );
                }
              }
            }
            if (fallbackPath != null &&
                fallbackPath!.isNotEmpty &&
                fallbackPath != resolvedPath) {
              return AdaptiveImage(
                fallbackPath,
                fit: fit,
                width: width,
                height: height,
                placeholder: placeholder,
              );
            }
            return _buildPlaceholder();
          },
        );
      }
      return CachedNetworkImage(
        imageUrl: resolvedPath,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) {
          // If this was a Google Drive URL, try alternative drive CDN endpoints
          if (resolvedPath.contains('drive.google.com') ||
              resolvedPath.contains('googleusercontent.com')) {
            final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(resolvedPath) ??
                RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedPath);
            if (idMatch != null) {
              final fileId = idMatch.group(1);
              final altUrl = resolvedPath.contains('thumbnail')
                  ? 'https://lh3.googleusercontent.com/d/$fileId'
                  : 'https://drive.google.com/thumbnail?sz=w1000&id=$fileId';
              return CachedNetworkImage(
                imageUrl: altUrl,
                fit: fit,
                width: width,
                height: height,
                placeholder: (context, url) => _buildPlaceholder(isLoading: true),
                errorWidget: (context, url, error) {
                  final ucUrl = 'https://drive.google.com/uc?export=view&id=$fileId';
                  return CachedNetworkImage(
                    imageUrl: ucUrl,
                    fit: fit,
                    width: width,
                    height: height,
                    placeholder: (context, url) => _buildPlaceholder(isLoading: true),
                    errorWidget: (context, url, error) {
                      if (fallbackPath != null && fallbackPath!.isNotEmpty && fallbackPath != resolvedPath) {
                        return AdaptiveImage(
                          fallbackPath,
                          fit: fit,
                          width: width,
                          height: height,
                          placeholder: placeholder,
                        );
                      }
                      return _buildPlaceholder();
                    },
                  );
                },
              );
            }
          }
          if (fallbackPath != null && fallbackPath!.isNotEmpty && fallbackPath != resolvedPath) {
            return AdaptiveImage(
              fallbackPath,
              fit: fit,
              width: width,
              height: height,
              placeholder: placeholder,
            );
          }
          return _buildPlaceholder();
        },
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
      final file = resolvedPath.startsWith('file://')
          ? File.fromUri(Uri.parse(resolvedPath))
          : File(resolvedPath);
      bool fileValid = false;
      try {
        fileValid = file.existsSync() && file.lengthSync() > 0;
      } catch (_) {
        fileValid = false;
      }
      if (!fileValid) {
        if (fallbackPath != null && fallbackPath!.isNotEmpty && fallbackPath != resolvedPath) {
          return AdaptiveImage(
            fallbackPath,
            fit: fit,
            width: width,
            height: height,
            placeholder: placeholder,
          );
        }
        return _buildPlaceholder();
      }
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          if (fallbackPath != null && fallbackPath!.isNotEmpty && fallbackPath != resolvedPath) {
            return AdaptiveImage(
              fallbackPath,
              fit: fit,
              width: width,
              height: height,
              placeholder: placeholder,
            );
          }
          return _buildPlaceholder();
        },
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
            : const Icon(Icons.image_outlined, color: Colors.grey),
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
  if (resolvedPath.startsWith('data:image/')) {
    try {
      final commaIndex = resolvedPath.indexOf(',');
      if (commaIndex != -1) {
        final bytes = base64Decode(resolvedPath.substring(commaIndex + 1));
        return MemoryImage(bytes);
      }
    } catch (_) {}
  }
  if (resolvedPath.startsWith('assets/')) {
    return AssetImage(resolvedPath);
  }
  if (resolvedPath.startsWith('http://') || resolvedPath.startsWith('https://')) {
    if (kIsWeb) {
      return NetworkImage(resolvedPath);
    }
    return CachedNetworkImageProvider(resolvedPath);
  }
  if (kIsWeb) {
    return NetworkImage(resolvedPath);
  } else {
    final file = resolvedPath.startsWith('file://')
        ? File.fromUri(Uri.parse(resolvedPath))
        : File(resolvedPath);
    try {
      if (file.existsSync() && file.lengthSync() > 0) {
        return FileImage(file);
      }
    } catch (_) {}
    return null;
  }
}

