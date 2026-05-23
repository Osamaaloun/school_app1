import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/student_database.dart';
import '../models/student.dart';
import '../services/jod_money_format.dart';
import '../widgets/luxury_edit_shell.dart';
import '../widgets/local_book_thumb.dart';

/// تعديل الرقم الوطني واختيار كتب الطالب من القائمة (checkboxes).
class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Student? _student;
  late TextEditingController _nationalIdController;
  final TextEditingController _bookSearch = TextEditingController();

  List<String> _catalogTitles = [];
  final Map<String, String?> _catalogImageByTitle = {};
  final Map<String, double> _catalogPriceByTitle = {};
  List<String> _orphanTitles = [];
  final Map<String, String?> _orphanImageByTitle = {};
  final Set<String> _selectedBooks = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nationalIdController = TextEditingController();
    _bookSearch.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _nationalIdController.dispose();
    _bookSearch.dispose();
    super.dispose();
  }

  List<String> get _filteredCatalog {
    final q = _bookSearch.text.trim();
    if (q.isEmpty) return _catalogTitles;
    return _catalogTitles.where((t) => t.contains(q)).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await StudentDatabase.instance.getStudentById(widget.studentId);
      final catalogEntries = s != null
          ? await StudentDatabase.instance.listCatalogBooksForGrade(s.grade)
          : <CatalogBookEntry>[];

      if (!mounted) return;

      if (s == null) {
        setState(() {
          _student = null;
          _nationalIdController.text = '';
          _catalogTitles = [];
          _catalogImageByTitle.clear();
          _catalogPriceByTitle.clear();
          _orphanTitles = [];
          _orphanImageByTitle.clear();
          _selectedBooks.clear();
          _loading = false;
        });
        return;
      }

      final catalogSet = catalogEntries.map((e) => e.title).toSet();
      _catalogImageByTitle
        ..clear()
        ..addEntries(catalogEntries.map((e) => MapEntry(e.title, e.imagePath)));
      _catalogPriceByTitle
        ..clear()
        ..addEntries(
          catalogEntries.map((e) => MapEntry(e.title, e.priceJod)),
        );
      final catalogTitles = catalogEntries.map((e) => e.title).toList();

      final orphans = <String>[];
      final seen = <String>{};
      final orphanImages = <String, String?>{};
      for (var i = 0; i < s.bookTitles.length; i++) {
        final t = s.bookTitles[i];
        if (catalogSet.contains(t)) continue;
        if (!seen.add(t)) continue;
        orphans.add(t);
        final img = i < s.bookImagePaths.length ? s.bookImagePaths[i] : null;
        orphanImages[t] = img;
      }

      setState(() {
        _student = s;
        _nationalIdController.text = s.nationalId;
        _catalogTitles = catalogTitles;
        _orphanTitles = orphans;
        _orphanImageByTitle
          ..clear()
          ..addAll(orphanImages);
        _selectedBooks
          ..clear()
          ..addAll(s.bookTitles);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحميل: $e')),
      );
    }
  }

  double _owedForCurrentSelection() {
    final st = _student;
    if (st == null || st.grade.booksDistributedFree) return 0;
    var t = 0.0;
    for (final title in _selectedBooks) {
      t += _catalogPriceByTitle[title] ?? 0;
    }
    return t;
  }

  List<String> _orderedSelectedBooks() {
    final out = <String>[];
    for (final t in _catalogTitles) {
      if (_selectedBooks.contains(t)) out.add(t);
    }
    for (final t in _orphanTitles) {
      if (_selectedBooks.contains(t)) out.add(t);
    }
    return out;
  }

  Future<void> _save() async {
    if (_student == null) return;
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرقم الوطني مطلوب')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await StudentDatabase.instance.updateStudentNationalIdAndBooks(
        studentId: widget.studentId,
        nationalId: nationalId,
        bookTitles: _orderedSelectedBooks(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ')),
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
    if (_loading) {
      return const LuxuryEditScaffold(
        title: Text('تفاصيل الطالب'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_student == null) {
      return const LuxuryEditScaffold(
        title: Text('تفاصيل الطالب'),
        body: Center(child: Text('الطالب غير موجود')),
      );
    }

    final s = _student!;
    return LuxuryEditScaffold(
      title: Text(s.name),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'البيانات',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الصف'),
            subtitle: Text(s.grade.arabicLabel),
          ),
          TextField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            decoration: const InputDecoration(
              labelText: 'الرقم الوطني',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (s.grade.booksDistributedFree)
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.volunteer_activism_outlined),
                title: Text('الكتب المدرسية'),
                subtitle: Text(
                  'الصفوف من السابع حتى العاشر (بما فيها كل مسارات العاشر): '
                  'التعليمات المعتادة في الأردن أن تكون مجانية؛ لا يُحسب مبلغ هنا.',
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('المستحق (الأول / الثاني ثانوي)'),
                subtitle: Text(
                  'الكتب المحددة حالياً: ${formatJod(_owedForCurrentSelection())} دينار أردني\n'
                  'يُحسب من أسعار «قائمة كتب الصف» لكل عنوان مطابق؛ '
                  'العناوين خارج القائمة لا تُسعّر تلقائياً.',
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Divider(),
          Text(
            'الكتب',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'حدد الكتب من القائمة (صورة الغلاف اختيارية وتظهر من قائمة كتب الصف).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (_catalogTitles.isEmpty && _orphanTitles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'لا توجد كتب في قائمة صف «${s.grade.arabicLabel}». '
                'أضف عناوين من أيقونة الكتب في الشاشة الرئيسية أو من شاشة طلاب هذا الصف.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            if (_catalogTitles.isNotEmpty) ...[
              TextField(
                controller: _bookSearch,
                decoration: const InputDecoration(
                  hintText: 'بحث في أسماء الكتب…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              ..._filteredCatalog.map((title) {
                return CheckboxListTile(
                  value: _selectedBooks.contains(title),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedBooks.add(title);
                      } else {
                        _selectedBooks.remove(title);
                      }
                    });
                  },
                  secondary: buildLocalBookThumb(_catalogImageByTitle[title], size: 44),
                  title: Text(title),
                  subtitle: s.grade.booksDistributedFree
                      ? null
                      : Text(
                          (_catalogPriceByTitle[title] ?? 0) > 0
                              ? '${formatJod(_catalogPriceByTitle[title]!)} د.أ. لكل نسخة'
                              : 'لم يُحدَّد سعر في كتالوج الصف',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
            if (_catalogTitles.isEmpty && _orphanTitles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'قائمة الكتب المركزية فارغة؛ يظهر أدناه ما هو مسجّل للطالب فقط.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_orphanTitles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'كتب مسجّلة خارج القائمة',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                'يمكن الإبقاء عليها أو إلغاء التحديد لحذفها من الطالب.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ..._orphanTitles.map((title) {
                return CheckboxListTile(
                  value: _selectedBooks.contains(title),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedBooks.add(title);
                      } else {
                        _selectedBooks.remove(title);
                      }
                    });
                  },
                  secondary: buildLocalBookThumb(_orphanImageByTitle[title], size: 44),
                  title: Text(title),
                  subtitle: s.grade.booksDistributedFree
                      ? null
                      : Text(
                          'ليس في كتالوج الصف — أضفه للقائمة وحدد السعر ليُحتسب',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
