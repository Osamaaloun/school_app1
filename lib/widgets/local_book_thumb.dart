import 'package:flutter/material.dart';

import 'local_book_thumb_io.dart' if (dart.library.html) 'local_book_thumb_web.dart'
    as impl;

/// معاينة صورة محفوظة محلياً (غير متاحة على الويب).
Widget buildLocalBookThumb(String? path, {double size = 44}) {
  return impl.buildLocalBookThumb(path, size: size);
}
