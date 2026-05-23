import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows / Linux / macOS: تهيئة SQLite عبر FFI قبل أي استدعاء لـ [openDatabase].
void configureDatabaseFactoryForPlatform() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
