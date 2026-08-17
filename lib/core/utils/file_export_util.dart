import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileExportUtil {
  /// Saves a file directly to the public Download directory on Android,
  /// or the application documents directory on iOS.
  static Future<String> saveFileToPublicDirectory({
    required String filename,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Use FileSaver for web.');
    }

    String path;
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        path = dir.path;
      } else {
        final extDir = await getExternalStorageDirectory();
        path = extDir?.path ?? '';
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    if (path.isEmpty) {
      throw Exception('Could not determine save directory.');
    }

    final file = File('$path/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
