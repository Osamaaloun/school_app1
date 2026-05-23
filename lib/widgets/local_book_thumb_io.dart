import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalBookThumb(String? path, {double size = 44}) {
  if (path == null || path.isEmpty) {
    return Icon(Icons.menu_book_outlined, size: size * 0.65);
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image_outlined, size: size * 0.65),
    ),
  );
}
