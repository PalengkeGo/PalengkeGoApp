import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Disk-cached map [TileProvider] that stores downloaded tiles locally via
/// [CachedNetworkImageProvider] on mobile/desktop while falling back to
/// [NetworkImage] on web.
class CachedNetworkTileProvider extends TileProvider {
  CachedNetworkTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    if (kIsWeb) {
      return NetworkImage(url);
    }
    return CachedNetworkImageProvider(
      url,
      headers: headers.isEmpty ? null : headers,
    );
  }
}
