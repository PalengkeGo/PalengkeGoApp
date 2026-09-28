import 'package:flutter/foundation.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves raw image strings (Google Drive share links, Supabase storage paths,
/// relative storage URLs, or standard web URLs) into a direct browser/app-loadable URL.
String? resolveImageUrl(
  String? raw, {
  String? supabaseUrl,
  SupabaseClient? client,
}) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // 1. Google Drive view/open/uc/thumbnail links -> direct CDN image endpoint (drive.google.com/thumbnail)
  // Provides direct image rendering with Access-Control-Allow-Origin: * on web and mobile.
  if (trimmed.contains('drive.google.com') ||
      trimmed.contains('docs.google.com') ||
      (trimmed.contains('google.com') && (trimmed.contains('/d/') || trimmed.contains('id=')))) {
    final driveIdMatch = RegExp(r'/d/([a-zA-Z0-9_-]{15,})').firstMatch(trimmed) ??
        RegExp(r'[?&]id=([a-zA-Z0-9_-]{15,})').firstMatch(trimmed);
    if (driveIdMatch != null) {
      final fileId = driveIdMatch.group(1);
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }
  }

  // 2. Already an absolute web or data/blob/asset URL
  if (trimmed.startsWith('blob:')) {
    final cleanBlob = trimmed.contains('#') ? trimmed.split('#').first : trimmed;
    return cleanBlob;
  }
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('assets/')) {
    return trimmed;
  }

  // 3. Supabase Storage relative paths or storage bucket references
  String baseUrl = supabaseUrl ?? '';
  final activeClient = client ??
      () {
        try {
          return Supabase.instance.client;
        } catch (_) {
          return null;
        }
      }();

  if (baseUrl.isEmpty) {
    try {
      baseUrl = AppConfig.load().supabaseUrl;
    } catch (_) {}
    if (baseUrl.isEmpty && activeClient != null) {
      try {
        final storageUrl = activeClient.storage.url;
        if (storageUrl.isNotEmpty) {
          baseUrl = storageUrl.replaceFirst('/storage/v1', '');
        }
      } catch (_) {}
    }
  }
  if (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }

  if (trimmed.startsWith('/storage/v1/object/public/')) {
    return baseUrl.isNotEmpty ? '$baseUrl$trimmed' : trimmed;
  }
  if (trimmed.startsWith('storage/v1/object/public/')) {
    return baseUrl.isNotEmpty ? '$baseUrl/$trimmed' : trimmed;
  }

  // Strip leading slash for relative storage paths like /stalls/... or /products/...
  String normalized = trimmed;
  if (normalized.startsWith('/') &&
      (normalized.startsWith('/stalls/') ||
          normalized.startsWith('/products/') ||
          normalized.startsWith('/recipes/') ||
          normalized.startsWith('/profiles/') ||
          normalized.startsWith('/kyc/'))) {
    normalized = normalized.substring(1);
  }

  // 4. Local filesystem path or file URI (only if not a storage relative path)
  if (normalized.startsWith('file:') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized)) {
    return normalized;
  }
  if (!kIsWeb && normalized.startsWith('/') && !normalized.contains('.')) {
    return normalized;
  }

  const knownBuckets = {
    'stalls',
    'profiles',
    'kyc',
    'license',
    'recipes',
    'products',
    'items',
    'product_images',
  };

  if (normalized.contains('/')) {
    final slashIndex = normalized.indexOf('/');
    final segment = normalized.substring(0, slashIndex);
    final rest = normalized.substring(slashIndex + 1);
    final bucket = knownBuckets.contains(segment) ? segment : 'stalls';
    final path = knownBuckets.contains(segment) ? rest : normalized;

    if (activeClient != null) {
      try {
        return activeClient.storage.from(bucket).getPublicUrl(path);
      } catch (_) {}
    }
    if (baseUrl.isNotEmpty) {
      return '$baseUrl/storage/v1/object/public/$bucket/$path';
    }
  } else {
    // Bare filename e.g. "gabi.jpg" or "tuna_kilawin.png"
    final ext = normalized.toLowerCase();
    final isImageFile = ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp');

    if (isImageFile) {
      final bucket = normalized.contains('stall') ? 'stalls' : 'recipes';
      if (activeClient != null) {
        try {
          return activeClient.storage.from(bucket).getPublicUrl(normalized);
        } catch (_) {}
      }
      if (baseUrl.isNotEmpty) {
        return '$baseUrl/storage/v1/object/public/$bucket/$normalized';
      }
    }
  }

  return normalized;
}

/// Returns a high-quality fallback image URL for products based on name and category.
String productFallbackImage(String name, [String? category]) {
  final lower = '${name.toLowerCase()} ${(category ?? '').toLowerCase()}';
  if (lower.contains('gabi') ||
      lower.contains('taro') ||
      lower.contains('kamote') ||
      lower.contains('cassava') ||
      lower.contains('root')) {
    return 'https://images.unsplash.com/photo-1590736969955-71cc94801759?w=400&h=400&fit=crop';
  }
  if (lower.contains('mango') || lower.contains('mangga')) {
    return 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=400&h=400&fit=crop';
  }
  if (lower.contains('banana') || lower.contains('saging')) {
    return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&h=400&fit=crop';
  }
  if (lower.contains('pork') ||
      lower.contains('beef') ||
      lower.contains('meat') ||
      lower.contains('liempo') ||
      lower.contains('baboy') ||
      lower.contains('baka')) {
    return 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=400&h=400&fit=crop';
  }
  if (lower.contains('chicken') || lower.contains('manok')) {
    return 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=400&h=400&fit=crop';
  }
  if (lower.contains('fish') ||
      lower.contains('isda') ||
      lower.contains('bangus') ||
      lower.contains('tilapia') ||
      lower.contains('tuyo') ||
      lower.contains('daing') ||
      lower.contains('seafood') ||
      lower.contains('hipon') ||
      lower.contains('shrimp')) {
    return 'https://images.unsplash.com/photo-1599084993091-1cb5c0721cc6?w=400&h=400&fit=crop';
  }
  if (lower.contains('egg') || lower.contains('itlog')) {
    return 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400&h=400&fit=crop';
  }
  if (lower.contains('rice') || lower.contains('bigas')) {
    return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&h=400&fit=crop';
  }
  if (lower.contains('fruit') ||
      lower.contains('prutas') ||
      lower.contains('apple') ||
      lower.contains('orange') ||
      lower.contains('papaya')) {
    return 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400&h=400&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&h=400&fit=crop';
}

/// Returns a high-quality fallback image URL for Filipino recipes based on title and category.
String recipeFallbackImage(String title, [String? category]) {
  final lower = '${title.toLowerCase()} ${(category ?? '').toLowerCase()}';
  if (lower.contains('kare') || lower.contains('karekare')) {
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&fit=crop';
  }
  if (lower.contains('pinangat') ||
      lower.contains('paksiw') ||
      lower.contains('isda') ||
      lower.contains('fish') ||
      lower.contains('bangus') ||
      lower.contains('tilapia')) {
    return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&fit=crop';
  }
  if (lower.contains('gabi') ||
      lower.contains('laing') ||
      lower.contains('bicol') ||
      lower.contains('taro')) {
    return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&fit=crop';
  }
  if (lower.contains('adobo')) {
    return 'https://images.unsplash.com/photo-1547496502-affa22d38842?w=400&fit=crop';
  }
  if (lower.contains('sinigang') ||
      lower.contains('bulalo') ||
      lower.contains('nilaga') ||
      lower.contains('soup')) {
    return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400&fit=crop';
  }
  if (lower.contains('chicken') ||
      lower.contains('manok') ||
      lower.contains('tinola') ||
      lower.contains('afritada')) {
    return 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=400&fit=crop';
  }
  if (lower.contains('pork') ||
      lower.contains('baboy') ||
      lower.contains('lechon') ||
      lower.contains('sisig')) {
    return 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=400&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&fit=crop';
}
