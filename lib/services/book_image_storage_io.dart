import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BookImageStorage {
  BookImageStorage._();

  static bool _isUnderBookImages(String path) {
    return path.contains('book_images');
  }

  static Future<String?> importFromPath(String? sourcePath) async {
    if (kIsWeb || sourcePath == null || sourcePath.isEmpty) return null;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'book_images'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ext = p.extension(sourcePath);
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final name = 'b_${DateTime.now().millisecondsSinceEpoch}$safeExt';
      final dest = File(p.join(dir.path, name));
      await src.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> tryDeleteFile(String? path) async {
    if (kIsWeb || path == null || path.isEmpty) return;
    if (!_isUnderBookImages(path)) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
