import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../db/student_database.dart';
import '../models/grade_level.dart';
import '../services/book_image_storage.dart';
import '../services/jod_money_format.dart';
import '../widgets/luxury_edit_shell.dart';
import '../widgets/local_book_thumb.dart';

/// عناوين الكتب المعتمدة للاختيار — خاصة بصف واحد، مع صورة اختيارية لكل عنوان.
class CatalogBooksScreen extends StatefulWidget {
  const CatalogBooksScreen({super.key, required this.grade});

  final GradeLevel grade;

  @override
  State<CatalogBooksScreen> createState() => _CatalogBooksScreenState();
}

class _CatalogBooksScreenState extends State<CatalogBooksScreen> {
  List<CatalogBookEntry> _entries = [];
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
          await StudentDatabase.instance.listCatalogBooksForGrade(widget.grade);
      if (mounted) {
        setState(() {
          _entries = list;
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

  Widget _leadingThumb(String? path) {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: SizedBox(
          width: 48,
          height: 48,
          child: buildLocalBookThumb(path, size: 48),
        ),
      ),
    );
  }

  Future<void> _pickImage(CatalogBookEntry e) async {
    final pick = await FilePicker.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    final src = pick.files.single.path;
    final stored = await BookImageStorage.importFromPath(src);
    if (!mounted) return;
    if (stored == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الصورة')),
      );
      return;
    }
    try {
      await StudentDatabase.instance.updateCatalogBookImage(e.id, stored);
      if (!mounted) return;
      await _reload();
    } catch (err) {
      if (!mounted) return;
      await BookImageStorage.tryDeleteFile(stored);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحديث: $err')),
      );
    }
  }

  Future<void> _removeImage(CatalogBookEntry e) async {
    if (e.imagePath == null || e.imagePath!.isEmpty) return;
    try {
      await StudentDatabase.instance.updateCatalogBookImage(e.id, null);
      await BookImageStorage.tryDeleteFile(e.imagePath);
      if (!mounted) return;
      await _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف: $err')),
      );
    }
  }

  Future<void> _addTitle() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عنوان كتاب جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم الكتاب',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = controller.text.trim();
    controller.dispose();
    if (t.isEmpty) return;
    try {
      await StudentDatabase.instance.insertCatalogBookForGrade(
        widget.grade,
        t,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الإضافة (أو العنوان موجود مسبقاً لهذا الصف)'),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e')),
      );
    }
  }

  Future<void> _editPrice(CatalogBookEntry e) async {
    if (widget.grade.booksDistributedFree) return;
    final controller = TextEditingController(
      text: e.priceJod > 0 ? formatJod(e.priceJod) : '',
    );
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('سعر «${e.title}»'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'السعر بالدينار الأردني (د.أ.)',
              hintText: 'مثال: 3.50',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final parsed = parseJodInput(controller.text);
      final v = parsed ?? 0;
      try {
        await StudentDatabase.instance.updateCatalogBookPrice(e.id, v);
        if (!mounted) return;
        await _reload();
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ السعر: $err')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDelete(CatalogBookEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف من قائمة الصف'),
        content: Text(
          'حذف «${e.title}» من قائمة صف «${widget.grade.arabicLabel}»؟\n'
          '(لا يُحذف من كتب الطلاب المسجّلة.)',
        ),
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
    await StudentDatabase.instance.deleteCatalogBook(e.id);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryEditScaffold(
      title: Text('كتب ${widget.grade.arabicLabel}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا توجد عناوين لصف «${widget.grade.arabicLabel}» بعد.\n\n'
                      'أضف عناوين كتب هذا الصف؛ يمكنك لاحقاً إرفاق صورة (غير إلزامية) لكل عنوان.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        widget.grade.booksDistributedFree
                            ? 'هذا الصف ضمن السابع–العاشر: التوزيع المجاني لا يتطلب تسعيراً هنا.'
                            : 'الأول والثاني ثانوي: حدّد سعر كل كتاب بالدينار الأردني؛ '
                                'يُستخدم لحساب ما يدفعه الطالب عند تسجيل الكتب له.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _entries.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = _entries[i];
                          final hasImg = !kIsWeb &&
                              e.imagePath != null &&
                              e.imagePath!.isNotEmpty;
                          final free = widget.grade.booksDistributedFree;
                          return ListTile(
                            leading: _leadingThumb(e.imagePath),
                            title: Text(e.title),
                            subtitle: Text(
                              free
                                  ? (hasImg
                                      ? 'مع صورة — اختياري'
                                      : 'بدون صورة — اختياري')
                                  : '${hasImg ? 'مع صورة. ' : ''}'
                                      'السعر: ${formatJod(e.priceJod)} د.أ.',
                            ),
                            isThreeLine: false,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!free)
                                  IconButton(
                                    tooltip: 'تعديل السعر',
                                    icon: const Icon(Icons.payments_outlined),
                                    onPressed: () => _editPrice(e),
                                  ),
                                if (!kIsWeb)
                                  IconButton(
                                    tooltip: 'إضافة أو تغيير الصورة',
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    onPressed: () => _pickImage(e),
                                  ),
                                if (!kIsWeb && hasImg)
                                  IconButton(
                                    tooltip: 'إزالة الصورة',
                                    icon: const Icon(Icons.hide_image_outlined),
                                    onPressed: () => _removeImage(e),
                                  ),
                                IconButton(
                                  tooltip: 'حذف العنوان',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _confirmDelete(e),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTitle,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عنوان'),
      ),
    );
  }
}

