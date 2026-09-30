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

    if (Platform.isAndroid) {
      try {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          return file.path;
        }
      } catch (_) {
        // Fallback to external/app directory if direct public storage write is denied
      }
      final extDir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${extDir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }
}
