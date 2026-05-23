import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/student_database.dart';
import '../models/grade_level.dart';
import '../models/student.dart';
import '../services/jod_money_format.dart';
import '../services/student_excel_import.dart';
import '../widgets/luxury_edit_shell.dart';
import 'add_student_screen.dart';
import 'bulk_add_books_screen.dart';
import 'catalog_books_screen.dart';
import 'student_detail_screen.dart';

class GradeStudentsScreen extends StatefulWidget {
  const GradeStudentsScreen({super.key, required this.grade});

  final GradeLevel grade;

  @override
  State<GradeStudentsScreen> createState() => _GradeStudentsScreenState();
}

class _GradeStudentsScreenState extends State<GradeStudentsScreen> {
  List<Student> _students = [];
  double _gradeTotalOwed = 0;
  Set<int> _shortageIds = {};
  int _catalogTitleCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list =
          await StudentDatabase.instance.listByGrade(widget.grade);
      final total = widget.grade.booksDistributedFree
          ? 0.0
          : await StudentDatabase.instance.sumOwedJodForGrade(widget.grade);
      final shortage =
          await StudentDatabase.instance.studentIdsWithCatalogShortage(
        widget.grade,
      );
      final catalogTitles =
          await StudentDatabase.instance.listCatalogBookTitlesForGrade(
        widget.grade,
      );
      if (mounted) {
        setState(() {
          _students = list;
          _gradeTotalOwed = total;
          _shortageIds = shortage;
          _catalogTitleCount = catalogTitles.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل القائمة: $e')),
        );
      }
    }
  }

  Future<void> _importExcel() async {
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;

    final file = pick.files.single;
    List<int>? bytes = file.bytes?.toList();
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم قراءة الملف')),
      );
      return;
    }

    final parsed = StudentExcelImport.parseBytesForGrade(
      bytes,
      widget.grade,
    );
    if (parsed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم يُعثر على صفوف صالحة. تأكد من صف عناوين يحتوي «الاسم» و«الرقم الوطني» '
            '(أو عمود أرقام + عمود أسماء)، ثم بيانات تحتها. الصف المستهدف: «${widget.grade.arabicLabel}».',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستيراد'),
        content: Text(
          'سيتم إضافة ${parsed.length} طالباً في صف «${widget.grade.arabicLabel}» '
          '(الاسم + الرقم الوطني من الملف).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استيراد'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await StudentDatabase.instance.insertMany(parsed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استيراد ${parsed.length} طالباً')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاستيراد: $e')),
      );
    }
  }

  Future<void> _openBulkAddBooks() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BulkAddBooksScreen(grade: widget.grade),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _openAddStudent() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddStudentScreen(grade: widget.grade),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _openStudent(Student s) async {
    final id = s.id;
    if (id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudentDetailScreen(studentId: id),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _confirmDelete(Student s) async {
    final id = s.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطالب'),
        content: Text('حذف «${s.name}» وجميع كتبه؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StudentDatabase.instance.delete(id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDeleteAllInGrade() async {
    if (_students.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب لحذفهم في هذا الصف')),
      );
      return;
    }
    final n = _students.length;
    final label = widget.grade.arabicLabel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف كل الطلاب في الصف'),
        content: Text(
          'سيتم حذف $n طالباً في صف «$label» وجميع كتبهم المسجّلة.\n\n'
          'لن يُحذف كتالوج عناوين الكتب لهذا الصف.\n'
          'لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final deleted =
          await StudentDatabase.instance.deleteAllStudentsInGrade(widget.grade);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف $deleted طالباً')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryEditScaffold(
      title: Text('طلاب ${widget.grade.arabicLabel}'),
      actions: [
        IconButton(
          tooltip: 'حذف كل طلاب هذا الصف',
          onPressed: (_loading || _students.isEmpty)
              ? null
              : _confirmDeleteAllInGrade,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        IconButton(
          tooltip: 'قائمة كتب هذا الصف (للاختيار عند التوزيع)',
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CatalogBooksScreen(grade: widget.grade),
              ),
            );
          },
          icon: const Icon(Icons.menu_book_outlined),
        ),
        IconButton(
          tooltip: 'إضافة كتب لجميع طلاب هذا الصف',
          onPressed: _openBulkAddBooks,
          icon: const Icon(Icons.library_add_check_outlined),
        ),
        IconButton(
          tooltip: 'استيراد من Excel (اسم + رقم وطني)',
          onPressed: _importExcel,
          icon: const Icon(Icons.upload_file),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.grade.booksDistributedFree && _students.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: const Text('إجمالي مستحقات الصف'),
                        subtitle: Text(
                          '${formatJod(_gradeTotalOwed)} دينار أردني — مجموع أسعار الكتب '
                          'المسجّلة للطلاب حسب الكتالوج (الأول والثاني ثانوي).',
                        ),
                      ),
                    ),
                  ),
                if (!widget.grade.booksDistributedFree && _students.isNotEmpty)
                  const SizedBox(height: 4),
                if (!_loading &&
                    _students.isNotEmpty &&
                    _catalogTitleCount > 0 &&
                    _shortageIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Card(
                      color: const Color(0xFF3A1515),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.red.shade400.withOpacity(0.5),
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade200,
                        ),
                        title: Text(
                          'نقص في التوزيع',
                          style: TextStyle(
                            color: Colors.red.shade100,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_shortageIds.length} طالباً باللون الأحمر لا يملكون كل عناوين '
                          'كتالوج الصف ($_catalogTitleCount عنواناً).',
                          style: TextStyle(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _students.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'لا يوجد طلاب في ${widget.grade.arabicLabel} بعد.\n\n'
                              'استيراد Excel: صف عناوين ثم البيانات — مثلاً «الرقم الوطني» و«الاسم» '
                              '(بأي ترتيب أعمدة). يُسجَّل الجميع في هذا الصف.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _students.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = _students[i];
                            final n = s.effectiveBookCount;
                            final booksLine = n == 0
                                ? 'لا كتب مسجّلة — اضغط لإضافة الكتب'
                                : '$n ${n == 1 ? 'كتاب' : 'كتب'}';
                            final idLine = s.nationalId.isEmpty
                                ? 'بدون رقم وطني'
                                : 'الوطني: ${s.nationalId}';
                            final oweLine = widget.grade.booksDistributedFree
                                ? ''
                                : '\nالمستحق: ${formatJod(s.owedJod)} د.أ.';
                            final sid = s.id;
                            final shortage = sid != null &&
                                _shortageIds.contains(sid) &&
                                _catalogTitleCount > 0;
                            final warn = shortage
                                ? '\nتنبيه: نقص في عناوين الكتالوج'
                                : '';
                            return ListTile(
                              tileColor: shortage
                                  ? const Color(0x33FF5252)
                                  : null,
                              title: Text(
                                s.name,
                                style: shortage
                                    ? TextStyle(
                                        color: Colors.red.shade100,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
                              ),
                              subtitle: Text(
                                '$idLine\n$booksLine$oweLine$warn',
                                style: shortage
                                    ? TextStyle(color: Colors.red.shade200)
                                    : null,
                              ),
                              isThreeLine: true,
                              onTap: () => _openStudent(s),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(s),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudent,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة طالب'),
      ),
    );
  }
}

