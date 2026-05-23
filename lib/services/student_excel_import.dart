import 'package:excel/excel.dart';

import '../models/grade_level.dart';
import '../models/student.dart';

String _doubleToDigitsString(double value) {
  final r = value.roundToDouble();
  if ((value - r).abs() < 1e-9 && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// تحويل قيمة الخلية إلى نص (Excel 4 يستخدم [CellValue]).
String? _cellText(Data? cell) {
  final cv = cell?.value;
  if (cv == null) return null;
  final raw = switch (cv) {
    TextCellValue(:final value) => value.text ?? '',
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => _doubleToDigitsString(value),
    FormulaCellValue(:final formula) => formula,
    BoolCellValue(:final value) => value ? '1' : '0',
    DateCellValue() => cv.toString(),
    TimeCellValue() => cv.toString(),
    DateTimeCellValue() => cv.toString(),
  };
  final s = raw.trim();
  return s.isEmpty ? null : s;
}

bool _isNameHeader(String t) {
  final x = t.toLowerCase();
  if (t.contains('اسم')) return true;
  if (x.contains('name') && !x.contains('national')) return true;
  if (t.contains('طالب') && !t.contains('رقم')) return true;
  return false;
}

bool _isNationalIdHeader(String t) {
  final compact = t.replaceAll(RegExp(r'\s'), '');
  final x = t.toLowerCase();
  if (compact.contains('وطني')) return true;
  if (compact.contains('هوية') || compact.contains('هويه')) return true;
  if (x.contains('national') && x.contains('id')) return true;
  if (x == 'nid' || x.contains('national_id')) return true;
  if (t.contains('رقمهوية') || t.contains('رقم الهوية')) return true;
  return false;
}

bool _rowLooksLikeHeader(List<Data?> row) {
  final texts = row.map(_cellText).whereType<String>().join(' ');
  return _isNameHeader(texts) ||
      _isNationalIdHeader(texts) ||
      texts.contains('طالب');
}

bool _isMostlyDigits(String s) {
  final t = s.replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return false;
  return RegExp(r'^[0-9]+$').hasMatch(t);
}

/// استيراد من Excel: **الاسم** + **الرقم الوطني** بأي ترتيب أعمدة.
///
/// يطابق شكل الملف الشائع (صف عناوين):
/// | **الرقم الوطني** | **الاسم** |  ← كما في Excel العربي (العمود A يميناً = الرقم الوطني).
///
/// - يُكتشف صف العناوين تلقائياً من كلمات «اسم» و«وطني» / «هوية».
/// - بدون عناوين: يُستنتج من أول صف بيانات إن كان عموداً أرقاماً والآخر نص الاسم.
///
/// الجميع يُسجَّل في [targetGrade].
class StudentExcelImport {
  static List<Student> parseBytesForGrade(
    List<int> bytes,
    GradeLevel targetGrade,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sheetName =
        excel.tables.keys.isEmpty ? null : excel.tables.keys.first;
    if (sheetName == null) {
      return const [];
    }
    final table = excel.tables[sheetName];
    if (table == null || table.rows.isEmpty) {
      return const [];
    }

    final rows = table.rows;
    var startIndex = 0;
    var nameCol = 0;
    var idCol = 1;

    final firstRow = rows.first;
    final hasHeader = _rowLooksLikeHeader(firstRow);

    if (hasHeader) {
      final header = firstRow;
      for (var i = 0; i < header.length; i++) {
        final t = _cellText(header[i]) ?? '';
        if (_isNameHeader(t)) {
          nameCol = i;
        }
        if (_isNationalIdHeader(t)) {
          idCol = i;
        }
      }
      startIndex = 1;
    } else {
      final inferred = _inferColumnsFromFirstDataRows(rows);
      nameCol = inferred.$1;
      idCol = inferred.$2;
    }

    final out = <Student>[];
    for (var r = startIndex; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      final name = nameCol < row.length ? _cellText(row[nameCol]) : null;
      final idRaw = idCol < row.length ? _cellText(row[idCol]) : null;
      if (name == null || idRaw == null) continue;
      final nationalId = idRaw.trim();
      if (nationalId.isEmpty) continue;
      out.add(
        Student(
          name: name,
          grade: targetGrade,
          nationalId: nationalId,
          bookTitles: const [],
        ),
      );
    }
    return out;
  }

  /// (nameCol, idCol) الافتراضي 0 و1 إن لم يُستنتج شيء.
  static (int, int) _inferColumnsFromFirstDataRows(
    List<List<Data?>> rows,
  ) {
    var nameCol = 0;
    var idCol = 1;

    for (var r = 0; r < rows.length && r < 20; r++) {
      final row = rows[r];
      final filled = <(int, String)>[];
      for (var c = 0; c < row.length; c++) {
        final t = _cellText(row[c]);
        if (t != null && t.isNotEmpty) {
          filled.add((c, t));
        }
        if (filled.length >= 2) {
          break;
        }
      }
      if (filled.length < 2) continue;

      final (i0, v0) = filled[0];
      final (i1, v1) = filled[1];
      final d0 = _isMostlyDigits(v0);
      final d1 = _isMostlyDigits(v1);
      if (d0 && !d1) {
        return (i1, i0);
      }
      if (d1 && !d0) {
        return (i0, i1);
      }
    }

    return (nameCol, idCol);
  }
}
