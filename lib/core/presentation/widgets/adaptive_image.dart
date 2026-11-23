import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';

const int _maxBase64CacheEntries = 32;
final LinkedHashMap<String, Uint8List> _base64Cache =
    LinkedHashMap<String, Uint8List>();

Uint8List? _decodeBase64Cached(String dataUri) {
  final existing = _base64Cache.remove(dataUri);
  if (existing != null) {
    _base64Cache[dataUri] = existing;
    return existing;
  }
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    final bytes = base64Decode(dataUri.substring(commaIndex + 1));
    _base64Cache[dataUri] = bytes;
    if (_base64Cache.length > _maxBase64CacheEntries) {
      _base64Cache.remove(_base64Cache.keys.first);
    }
    return bytes;
  } catch (_) {
    return null;
  }
}

class AdaptiveImage extends StatelessWidget {
  final String? path;
  final String? fallbackPath;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final int? maxCacheWidth;

  const AdaptiveImage(
    this.path, {
    super.key,
    this.fallbackPath,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
    this.maxCacheWidth,
  });

  static String? _stableCacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('/storage/v1/object/sign/')) {
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      ).toString();
    }
    return null;
  }

  (int?, int?) _resolveDecodeDimensions(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (maxCacheWidth != null && maxCacheWidth! > 0) {
      return (maxCacheWidth!.clamp(1, 2048), null);
    }
    if (width != null && width!.isFinite && width! > 0) {
      return ((width! * dpr).round().clamp(1, 2048), null);
    }
    if (height != null && height!.isFinite && height! > 0) {
      return (null, (height! * dpr).round().clamp(1, 2048));
    }
    return (null, null);
  }

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
          maxCacheWidth: maxCacheWidth,
          placeholder: placeholder,
        );
      }
      return _buildPlaceholder();
    }

    final (cacheWidth, cacheHeight) = _resolveDecodeDimensions(context);

    if (resolvedPath.startsWith('data:image/')) {
      final bytes = _decodeBase64Cached(resolvedPath);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }

    if (resolvedPath.startsWith('assets/')) {
      return Image.asset(
        resolvedPath,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    if (resolvedPath.startsWith('http://') ||
        resolvedPath.startsWith('https://')) {
      if (kIsWeb) {
        return Image.network(
          resolvedPath,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder(isLoading: true);
          },
          errorBuilder: (context, error, stackTrace) {
            if (resolvedPath.contains('drive.google.com') ||
                resolvedPath.contains('googleusercontent.com')) {
              final idMatch =
                  RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(resolvedPath) ??
                  RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedPath);
              if (idMatch != null) {
                final fileId = idMatch.group(1);
                final altUrl = resolvedPath.contains('thumbnail')
                    ? 'https://lh3.googleusercontent.com/d/$fileId'
                    : 'https://drive.google.com/thumbnail?sz=w1000&id=$fileId';
                if (altUrl != resolvedPath) {
                  return Image.network(
                    altUrl,
                    fit: fit,
                    width: width,
                    height: height,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    errorBuilder: (context, error, stackTrace) {
                      final ucUrl =
                          'https://drive.google.com/uc?export=view&id=$fileId';
                      return Image.network(
                        ucUrl,
                        fit: fit,
                        width: width,
                        height: height,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                        errorBuilder: (context, error, stackTrace) {
                          if (fallbackPath != null &&
                              fallbackPath!.isNotEmpty &&
                              fallbackPath != resolvedPath) {
                            return AdaptiveImage(
                              fallbackPath,
                              fit: fit,
                              width: width,
                              height: height,
                              maxCacheWidth: maxCacheWidth,
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
            }
            if (fallbackPath != null &&
                fallbackPath!.isNotEmpty &&
                fallbackPath != resolvedPath) {
              return AdaptiveImage(
                fallbackPath,
                fit: fit,
                width: width,
                height: height,
                maxCacheWidth: maxCacheWidth,
                placeholder: placeholder,
              );
            }
            return _buildPlaceholder();
          },
        );
      }
      return CachedNetworkImage(
        imageUrl: resolvedPath,
        cacheKey: _stableCacheKey(resolvedPath),
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) {
          // If this was a Google Drive URL, try alternative drive CDN endpoints
          if (resolvedPath.contains('drive.google.com') ||
              resolvedPath.contains('googleusercontent.com')) {
            final idMatch =
                RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(resolvedPath) ??
                RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedPath);
            if (idMatch != null) {
              final fileId = idMatch.group(1);
              final altUrl = resolvedPath.contains('thumbnail')
                  ? 'https://lh3.googleusercontent.com/d/$fileId'
                  : 'https://drive.google.com/thumbnail?sz=w1000&id=$fileId';
              return CachedNetworkImage(
                imageUrl: altUrl,
                cacheKey: _stableCacheKey(altUrl),
                memCacheWidth: cacheWidth,
                memCacheHeight: cacheHeight,
                fit: fit,
                width: width,
                height: height,
                placeholder: (context, url) =>
                    _buildPlaceholder(isLoading: true),
                errorWidget: (context, url, error) {
                  final ucUrl =
                      'https://drive.google.com/uc?export=view&id=$fileId';
                  return CachedNetworkImage(
                    imageUrl: ucUrl,
                    cacheKey: _stableCacheKey(ucUrl),
                    memCacheWidth: cacheWidth,
                    memCacheHeight: cacheHeight,
                    fit: fit,
                    width: width,
                    height: height,
                    placeholder: (context, url) =>
                        _buildPlaceholder(isLoading: true),
                    errorWidget: (context, url, error) {
                      if (fallbackPath != null &&
                          fallbackPath!.isNotEmpty &&
                          fallbackPath != resolvedPath) {
                        return AdaptiveImage(
                          fallbackPath,
                          fit: fit,
                          width: width,
                          height: height,
                          maxCacheWidth: maxCacheWidth,
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
          if (fallbackPath != null &&
              fallbackPath!.isNotEmpty &&
              fallbackPath != resolvedPath) {
            return AdaptiveImage(
              fallbackPath,
              fit: fit,
              width: width,
              height: height,
              maxCacheWidth: maxCacheWidth,
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
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      File file;
      try {
        file = resolvedPath.startsWith('file:')
            ? (resolvedPath.startsWith('file://')
                  ? File.fromUri(Uri.parse(resolvedPath))
                  : File(resolvedPath.substring(5)))
            : File(resolvedPath);
      } catch (_) {
        if (fallbackPath != null &&
            fallbackPath!.isNotEmpty &&
            fallbackPath != resolvedPath) {
          return AdaptiveImage(
            fallbackPath,
            fit: fit,
            width: width,
            height: height,
            maxCacheWidth: maxCacheWidth,
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
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          if (fallbackPath != null &&
              fallbackPath!.isNotEmpty &&
              fallbackPath != resolvedPath) {
            return AdaptiveImage(
              fallbackPath,
              fit: fit,
              width: width,
              height: height,
              maxCacheWidth: maxCacheWidth,
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
    final bytes = _decodeBase64Cached(resolvedPath);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
  }
  if (resolvedPath.startsWith('assets/')) {
    return AssetImage(resolvedPath);
  }
  if (resolvedPath.startsWith('http://') ||
      resolvedPath.startsWith('https://')) {
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
