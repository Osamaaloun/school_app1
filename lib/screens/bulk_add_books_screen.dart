import 'package:flutter/material.dart';

import '../db/student_database.dart';
import '../models/grade_level.dart';
import '../models/student.dart';
import '../widgets/luxury_edit_shell.dart';

/// إضافة الكتب المحددة (checkbox) لكل طالب في الصف.
class BulkAddBooksScreen extends StatefulWidget {
  const BulkAddBooksScreen({super.key, required this.grade});

  final GradeLevel grade;

  @override
  State<BulkAddBooksScreen> createState() => _BulkAddBooksScreenState();
}

class _BulkAddBooksScreenState extends State<BulkAddBooksScreen> {
  int _studentCount = 0;
  List<String> _catalogTitles = [];
  final Set<String> _selectedBooks = {};
  final TextEditingController _bookSearch = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bookSearch.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _bookSearch.dispose();
    super.dispose();
  }

  List<String> get _filteredCatalog {
    final q = _bookSearch.text.trim();
    if (q.isEmpty) return _catalogTitles;
    return _catalogTitles.where((t) => t.contains(q)).toList();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        StudentDatabase.instance.listByGrade(widget.grade),
        StudentDatabase.instance.listCatalogBookTitlesForGrade(widget.grade),
      ]);
      final students = results[0] as List<Student>;
      final catalog = results[1] as List<String>;
      if (mounted) {
        setState(() {
          _studentCount = students.length;
          _catalogTitles = catalog;
          _selectedBooks.clear();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التحميل: $e')),
        );
      }
    }
  }

  void _selectAllFiltered() {
    setState(() {
      for (final t in _filteredCatalog) {
        _selectedBooks.add(t);
      }
    });
  }

  void _clearFiltered() {
    setState(() {
      for (final t in _filteredCatalog) {
        _selectedBooks.remove(t);
      }
    });
  }

  List<String> _orderedSelectedBooks() {
    final out = <String>[];
    for (final t in _catalogTitles) {
      if (_selectedBooks.contains(t)) out.add(t);
    }
    return out;
  }

  Future<void> _save() async {
    if (_studentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب في هذا الصف')),
      );
      return;
    }
    final titles = _orderedSelectedBooks();
    if (titles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد كتاباً واحداً على الأقل من القائمة')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(
          'سيتم إضافة ${titles.length} ${titles.length == 1 ? 'كتاب' : 'كتب'} '
          'لكل من $_studentCount طالباً في صف «${widget.grade.arabicLabel}» '
          '(تُلحق بالقائمة الحالية لكل طالب).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تنفيذ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final result =
          await StudentDatabase.instance.appendBooksToAllStudentsInGrade(
        grade: widget.grade,
        bookTitles: titles,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة ${titles.length} ${titles.length == 1 ? 'كتاب' : 'كتب'} '
            'لكل من ${result.studentCount} طالباً',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryEditScaffold(
      title: const Text('كتب لجميع طلاب الصف'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'صف «${widget.grade.arabicLabel}» — $_studentCount طالباً',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _studentCount == 0
                      ? 'لا يمكن الإضافة حتى يوجد طلاب في هذا الصف.'
                      : 'حدد الكتب من القائمة ثم «إضافة للجميع». تُلحق بالكتب الحالية لكل طالب.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (_catalogTitles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'قائمة كتب صف «${widget.grade.arabicLabel}» فارغة. '
                      'أضف العناوين من أيقونة الكتب هنا أعلاه أو من الشاشة الرئيسية.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                else if (_studentCount > 0) ...[
                  Text(
                    'اختيار الكتب',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: true,
                    controller: _bookSearch,
                    decoration: const InputDecoration(
                      hintText: 'بحث…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            _filteredCatalog.isEmpty ? null : _selectAllFiltered,
                        child: const Text('تحديد الظاهر'),
                      ),
                      TextButton(
                        onPressed:
                            _filteredCatalog.isEmpty ? null : _clearFiltered,
                        child: const Text('إلغاء الظاهر'),
                      ),
                    ],
                  ),
                  ..._filteredCatalog.map((title) {
                    return CheckboxListTile(
                      value: _selectedBooks.contains(title),
                      onChanged: _studentCount == 0
                          ? null
                          : (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedBooks.add(title);
                                } else {
                                  _selectedBooks.remove(title);
                                }
                              });
                            },
                      title: Text(title),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _studentCount == 0 ||
                          _catalogTitles.isEmpty ||
                          _saving
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إضافة للجميع'),
                ),
              ],
            ),
    );
  }
}

