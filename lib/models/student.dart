import 'grade_level.dart';

class Student {
  Student({
    this.id,
    required this.name,
    required this.grade,
    this.nationalId = '',
    this.bookTitles = const [],
    this.bookImagePaths = const [],
    this.bookCount = 0,
    this.owedJod = 0,
  });

  final int? id;
  final String name;
  final GradeLevel grade;

  /// الرقم الوطني / الهوية (نص للحفاظ على الأصفار البادئة إن وُجدت).
  final String nationalId;

  /// عند تحميل تفاصيل الطالب يُملأ هذا الحقل.
  final List<String> bookTitles;

  /// مسارات صور اختيارية، بنفس ترتيب وطول [bookTitles] عند التحميل من قاعدة البيانات.
  final List<String?> bookImagePaths;

  /// من استعلام التجميع في قائمة الصف؛ إن وُجدت [bookTitles] نستخدم طولها للعرض.
  final int bookCount;

  /// مجموع أسعار الكتب المسجّلة (من الكتالوج) للصف الثانوي؛ 0 للصفوف المجانية أو غير المحمّل.
  final double owedJod;

  int get effectiveBookCount =>
      bookTitles.isNotEmpty ? bookTitles.length : bookCount;

  Map<String, Object?> toInsertMap() => {
        'name': name,
        'grade': grade.dbValue,
        'national_id': nationalId.trim(),
      };

  Student withBooks(
    List<String> titles, {
    List<String?>? imagePaths,
  }) {
    final paths = imagePaths != null && imagePaths.length == titles.length
        ? List<String?>.from(imagePaths)
        : List<String?>.filled(titles.length, null);
    return Student(
      id: id,
      name: name,
      grade: grade,
      nationalId: nationalId,
      bookTitles: titles,
      bookImagePaths: paths,
      bookCount: titles.length,
      owedJod: owedJod,
    );
  }

  static double _readOwedJod(Map<String, Object?> map) {
    final v = map['owed_jod'];
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _readBookCount(Map<String, Object?> map) {
    final v = map['book_count'];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _readNationalId(Map<String, Object?> map) {
    final v = map['national_id'];
    if (v == null) return '';
    return v.toString().trim();
  }

  static Student fromMap(Map<String, Object?> map) {
    final gradeValue = map['grade'] as int?;
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      grade: GradeLevel.fromDbValue(gradeValue) ?? GradeLevel.grade7,
      nationalId: _readNationalId(map),
      bookTitles: const [],
      bookImagePaths: const [],
      bookCount: _readBookCount(map),
      owedJod: _readOwedJod(map),
    );
  }
}
