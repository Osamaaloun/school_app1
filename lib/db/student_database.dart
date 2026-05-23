import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/catalog_gap_entry.dart';
import '../models/grade_level.dart';
import '../models/grade_snapshot.dart';
import '../models/student.dart';
import '../models/student_search_result.dart';
import '../services/book_image_storage.dart';

class StudentDatabase {
  StudentDatabase._();
  static final StudentDatabase instance = StudentDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'edubooks.db');
    return openDatabase(
      path,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            grade INTEGER NOT NULL,
            national_id TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE student_books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            image_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE grade_catalog_books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grade INTEGER NOT NULL,
            title TEXT NOT NULL,
            image_path TEXT,
            price_jod REAL NOT NULL DEFAULT 0,
            UNIQUE(grade, title)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE student_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              student_id INTEGER NOT NULL,
              title TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE students ADD COLUMN national_id TEXT NOT NULL DEFAULT ''
          ''');
        }
        if (oldVersion < 4) {
          await db.rawUpdate(
            'UPDATE students SET grade = grade + 1 WHERE grade >= ?',
            [3],
          );
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE catalog_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL UNIQUE
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE grade_catalog_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              grade INTEGER NOT NULL,
              title TEXT NOT NULL,
              UNIQUE(grade, title)
            )
          ''');
          try {
            final oldRows = await db.query('catalog_books');
            if (oldRows.isNotEmpty) {
              final batch = db.batch();
              for (final g in GradeLevel.values) {
                for (final row in oldRows) {
                  batch.insert(
                    'grade_catalog_books',
                    {
                      'grade': g.dbValue,
                      'title': row['title'] as String,
                    },
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
              await batch.commit(noResult: true);
            }
          } catch (_) {}
          await db.execute('DROP TABLE IF EXISTS catalog_books');
        }
        if (oldVersion < 7) {
          try {
            await db.execute(
              'ALTER TABLE grade_catalog_books ADD COLUMN image_path TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE student_books ADD COLUMN image_path TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 8) {
          // كان 3=عاشر عام، 4=أول ثانوي عام، 5=ثاني ثانوي عام.
          // صار مسارات: 3=عاشر تكنولوجيا، 4=عاشر إدارة، …
          // نربط البيانات القديمة: العاشر يبقى 3 (تكنولوجيا)، الأول 4→5، الثاني 5→7.
          await db.rawUpdate('''
            UPDATE students SET grade = CASE grade
              WHEN 4 THEN 5
              WHEN 5 THEN 7
              ELSE grade
            END
            WHERE grade IN (4, 5)
          ''');
          // كتالوج الصف: UNIQUE(grade, title) — التحديث الأحادي 4→5 و5→7 دفعة واحدة
          // يُسبّب تعارضاً إن وُجد نفس العنوان في 4 و5. ننقل 5 أولاً لدرجة مؤقتة.
          const tempGrade = -88888;
          await db.update(
            'grade_catalog_books',
            {'grade': tempGrade},
            where: 'grade = ?',
            whereArgs: const [5],
          );
          await db.update(
            'grade_catalog_books',
            {'grade': 5},
            where: 'grade = ?',
            whereArgs: const [4],
          );
          await db.update(
            'grade_catalog_books',
            {'grade': 7},
            where: 'grade = ?',
            whereArgs: const [tempGrade],
          );
        }
        if (oldVersion < 10) {
          try {
            await db.execute(
              'ALTER TABLE grade_catalog_books ADD COLUMN price_jod REAL NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
      },
    );
  }

  static Future<String?> _catalogImageForTitle(
    DatabaseExecutor ex,
    int gradeDb,
    String title,
  ) async {
    final rows = await ex.query(
      'grade_catalog_books',
      columns: ['image_path'],
      where: 'grade = ? AND title = ?',
      whereArgs: [gradeDb, title],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['image_path'] as String?;
  }

  Future<List<String>> listCatalogBookTitlesForGrade(GradeLevel grade) async {
    final db = await database;
    final rows = await db.query(
      'grade_catalog_books',
      columns: ['title'],
      where: 'grade = ?',
      whereArgs: [grade.dbValue],
      orderBy: 'title',
    );
    return rows.map((r) => r['title'] as String).toList();
  }

  Future<List<CatalogBookEntry>> listCatalogBooksForGrade(
    GradeLevel grade,
  ) async {
    final db = await database;
    final rows = await db.query(
      'grade_catalog_books',
      where: 'grade = ?',
      whereArgs: [grade.dbValue],
      orderBy: 'title',
    );
    return rows
        .map(
          (r) => CatalogBookEntry(
            id: r['id'] as int,
            title: r['title'] as String,
            imagePath: r['image_path'] as String?,
            priceJod: (r['price_jod'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> insertCatalogBookForGrade(GradeLevel grade, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    final db = await database;
    await db.insert(
      'grade_catalog_books',
      {'grade': grade.dbValue, 'title': t, 'price_jod': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateCatalogBookPrice(int id, double priceJod) async {
    final db = await database;
    final v = priceJod.isFinite && priceJod > 0 ? priceJod : 0.0;
    await db.update(
      'grade_catalog_books',
      {'price_jod': v},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCatalogBookImage(int id, String? imagePath) async {
    final db = await database;
    final prev = await db.query(
      'grade_catalog_books',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (prev.isNotEmpty) {
      await BookImageStorage.tryDeleteFile(prev.first['image_path'] as String?);
    }
    await db.update(
      'grade_catalog_books',
      {'image_path': imagePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCatalogBook(int id) async {
    final db = await database;
    final prev = await db.query(
      'grade_catalog_books',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (prev.isNotEmpty) {
      await BookImageStorage.tryDeleteFile(prev.first['image_path'] as String?);
    }
    return db.delete('grade_catalog_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insert(Student student) async {
    final db = await database;
    return db.insert('students', student.toInsertMap());
  }

  Future<void> insertMany(List<Student> students) async {
    if (students.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final s in students) {
      batch.insert('students', s.toInsertMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Student>> listByGrade(GradeLevel grade) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT s.id, s.name, s.national_id, s.grade, COUNT(b.id) AS book_count,
        CASE WHEN s.grade IN (0, 1, 2, 3, 4, 9) THEN 0
        ELSE COALESCE(
          (SELECT SUM(c.price_jod)
           FROM student_books b2
           INNER JOIN grade_catalog_books c
             ON c.grade = s.grade AND c.title = b2.title
           WHERE b2.student_id = s.id),
          0
        ) END AS owed_jod
      FROM students s
      LEFT JOIN student_books b ON b.student_id = s.id
      WHERE s.grade = ?
      GROUP BY s.id, s.name, s.national_id, s.grade
      ORDER BY s.name
      ''',
      [grade.dbValue],
    );
    return rows.map(Student.fromMap).toList();
  }

  /// مجموع المستحق لجميع طلاب الصف (كتب مسجّلة لها سعر في الكتالوج).
  Future<double> sumOwedJodForGrade(GradeLevel grade) async {
    if (grade.booksDistributedFree) return 0;
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(c.price_jod), 0) AS t
      FROM students s
      INNER JOIN student_books b ON b.student_id = s.id
      INNER JOIN grade_catalog_books c
        ON c.grade = s.grade AND c.title = b.title
      WHERE s.grade = ?
      ''',
      [grade.dbValue],
    );
    return (rows.first['t'] as num?)?.toDouble() ?? 0;
  }

  /// مجموع المستحق لكتب طالب واحد (حسب كتالوج صفه).
  Future<double> sumOwedJodForStudent(int studentId) async {
    final s = await getStudentById(studentId);
    if (s == null || s.grade.booksDistributedFree) return 0;
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(c.price_jod), 0) AS t
      FROM student_books b
      INNER JOIN grade_catalog_books c
        ON c.grade = ? AND c.title = b.title
      WHERE b.student_id = ?
      ''',
      [s.grade.dbValue, studentId],
    );
    return (rows.first['t'] as num?)?.toDouble() ?? 0;
  }

  /// طلاب الصف الذين لا يملكون عنواناً واحداً على الأقل من كتالوج الصف.
  Future<Set<int>> studentIdsWithCatalogShortage(GradeLevel grade) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT s.id
      FROM students s
      WHERE s.grade = ?
      AND EXISTS (
        SELECT 1 FROM grade_catalog_books c
        WHERE c.grade = s.grade
        AND NOT EXISTS (
          SELECT 1 FROM student_books b
          WHERE b.student_id = s.id AND b.title = c.title
        )
      )
      ''',
      [grade.dbValue],
    );
    return rows.map((r) => r['id'] as int).toSet();
  }

  Future<GradeSnapshot> getGradeSnapshot(GradeLevel grade) async {
    final db = await database;
    final g = grade.dbValue;
    final sc = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) AS c FROM students WHERE grade = ?',
            [g],
          ),
        ) ??
        0;
    final cc = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) AS c FROM grade_catalog_books WHERE grade = ?',
            [g],
          ),
        ) ??
        0;
    final shortage = await studentIdsWithCatalogShortage(grade);
    return GradeSnapshot(
      grade: grade,
      studentCount: sc,
      catalogTitleCount: cc,
      studentsWithShortageCount: shortage.length,
    );
  }

  Future<List<StudentSearchResult>> searchStudentsByName(
    String query, {
    int limit = 80,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT id, name, grade FROM students
      WHERE name LIKE ?
      ORDER BY name COLLATE NOCASE
      LIMIT ?
      ''',
      ['%$q%', limit],
    );
    return rows
        .map(
          (r) => StudentSearchResult(
            id: r['id'] as int,
            name: r['name'] as String,
            grade: GradeLevel.fromDbValue(r['grade'] as int?) ??
                GradeLevel.grade7,
          ),
        )
        .toList();
  }

  /// لكل طالب في الصف: عناوين الكتالوج الناقصة لديه (فارغ إن اكتمل).
  Future<List<CatalogGapEntry>> listCatalogGapsForGrade(
    GradeLevel grade,
  ) async {
    final catalog = await listCatalogBookTitlesForGrade(grade);
    final db = await database;
    final studs = await db.query(
      'students',
      columns: ['id', 'name', 'national_id'],
      where: 'grade = ?',
      whereArgs: [grade.dbValue],
      orderBy: 'name COLLATE NOCASE',
    );
    final out = <CatalogGapEntry>[];
    for (final row in studs) {
      final id = row['id'] as int;
      final bookRows = await db.query(
        'student_books',
        columns: ['title'],
        where: 'student_id = ?',
        whereArgs: [id],
      );
      final have = bookRows.map((r) => r['title'] as String).toSet();
      final missing = catalog.where((t) => !have.contains(t)).toList();
      out.add(
        CatalogGapEntry(
          studentId: id,
          studentName: row['name'] as String,
          nationalId: (row['national_id'] as String?)?.trim() ?? '',
          missingCatalogTitles: missing,
        ),
      );
    }
    return out;
  }

  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final rows = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final bookRows = await db.query(
      'student_books',
      columns: ['title', 'image_path'],
      where: 'student_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    final titles = bookRows.map((r) => r['title'] as String).toList();
    final paths = bookRows
        .map((r) => r['image_path'] as String?)
        .toList();
    return Student.fromMap(rows.first).withBooks(titles, imagePaths: paths);
  }

  Future<void> replaceStudentBooks(int studentId, List<String> titles) async {
    final db = await database;
    final gradeRow = await db.query(
      'students',
      columns: ['grade'],
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    final gradeVal = gradeRow.first['grade'] as int;
    await db.transaction((txn) async {
      await txn.delete(
        'student_books',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      for (final raw in titles) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final img = await _catalogImageForTitle(txn, gradeVal, t);
        await txn.insert('student_books', {
          'student_id': studentId,
          'title': t,
          'image_path': img,
        });
      }
    });
  }

  Future<void> updateStudentNationalIdAndBooks({
    required int studentId,
    required String nationalId,
    required List<String> bookTitles,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'students',
        {'national_id': nationalId.trim()},
        where: 'id = ?',
        whereArgs: [studentId],
      );
      final oldBooks = await txn.query(
        'student_books',
        columns: ['title', 'image_path'],
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      final preserved = <String, String?>{};
      for (final row in oldBooks) {
        preserved[row['title'] as String] = row['image_path'] as String?;
      }
      final gradeRow = await txn.query(
        'students',
        columns: ['grade'],
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      final gradeVal = gradeRow.first['grade'] as int;

      await txn.delete(
        'student_books',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      for (final raw in bookTitles) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final img =
            preserved[t] ?? await _catalogImageForTitle(txn, gradeVal, t);
        await txn.insert('student_books', {
          'student_id': studentId,
          'title': t,
          'image_path': img,
        });
      }
    });
  }

  Future<int> delete(int id) async {
    final db = await database;
    final imgs = await db.query(
      'student_books',
      columns: ['image_path'],
      where: 'student_id = ?',
      whereArgs: [id],
    );
    for (final row in imgs) {
      await BookImageStorage.tryDeleteFile(row['image_path'] as String?);
    }
    await db.delete(
      'student_books',
      where: 'student_id = ?',
      whereArgs: [id],
    );
    return db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  /// حذف جميع طلاب الصف وجميع كتبهم (مع ملفات صور الكتب المحلية إن وُجدت).
  /// لا يمس كتالوج عناوين الصف.
  Future<int> deleteAllStudentsInGrade(GradeLevel grade) async {
    final db = await database;
    final g = grade.dbValue;
    final studentRows = await db.query(
      'students',
      columns: ['id'],
      where: 'grade = ?',
      whereArgs: [g],
    );
    if (studentRows.isEmpty) return 0;
    final ids = studentRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    final bookRows = await db.rawQuery(
      'SELECT image_path FROM student_books WHERE student_id IN ($placeholders)',
      ids,
    );
    for (final row in bookRows) {
      await BookImageStorage.tryDeleteFile(row['image_path'] as String?);
    }

    await db.transaction((txn) async {
      await txn.delete(
        'student_books',
        where: 'student_id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete(
        'students',
        where: 'grade = ?',
        whereArgs: [g],
      );
    });

    return ids.length;
  }

  Future<BulkAppendBooksResult> appendBooksToAllStudentsInGrade({
    required GradeLevel grade,
    required List<String> bookTitles,
  }) async {
    final titles = bookTitles.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (titles.isEmpty) {
      return const BulkAppendBooksResult(studentCount: 0, booksInserted: 0);
    }

    final db = await database;
    final g = grade.dbValue;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'students',
        columns: ['id'],
        where: 'grade = ?',
        whereArgs: [g],
      );
      final studentCount = rows.length;
      var booksInserted = 0;
      final imageByTitle = <String, String?>{};
      for (final t in titles) {
        imageByTitle[t] = await _catalogImageForTitle(txn, g, t);
      }
      for (final row in rows) {
        final sid = row['id'] as int;
        for (final t in titles) {
          await txn.insert('student_books', {
            'student_id': sid,
            'title': t,
            'image_path': imageByTitle[t],
          });
          booksInserted++;
        }
      }
      return BulkAppendBooksResult(
        studentCount: studentCount,
        booksInserted: booksInserted,
      );
    });
  }
}

class BulkAppendBooksResult {
  const BulkAppendBooksResult({
    required this.studentCount,
    required this.booksInserted,
  });

  final int studentCount;
  final int booksInserted;
}

class CatalogBookEntry {
  const CatalogBookEntry({
    required this.id,
    required this.title,
    this.imagePath,
    this.priceJod = 0,
  });

  final int id;
  final String title;
  final String? imagePath;

  /// سعر الغلاف بالدينار الأردني (للصف الثانوي؛ الصفوف المجانية يُتجاهل عرضها).
  final double priceJod;
}
