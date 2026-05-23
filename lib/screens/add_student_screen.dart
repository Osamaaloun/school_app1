import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/student_database.dart';
import '../models/grade_level.dart';
import '../models/student.dart';
import '../widgets/luxury_edit_shell.dart';

/// إضافة طالب فقط (الكتب تُضاف لاحقاً من صفحة تفاصيل الطالب).
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key, required this.grade});

  final GradeLevel grade;

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final nationalId = _nationalIdController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الطالب')),
      );
      return;
    }
    if (nationalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الرقم الوطني')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await StudentDatabase.instance.insert(
        Student(
          name: name,
          grade: widget.grade,
          nationalId: nationalId,
        ),
      );
      if (!mounted) return;
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
      title: const Text('إضافة طالب'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'اسم الطالب',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            decoration: const InputDecoration(
              labelText: 'الرقم الوطني',
              hintText: 'مثال: 10 أرقام',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'الصف: ${widget.grade.arabicLabel}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'بعد الحفظ يمكنك فتح بطاقة الطالب لإضافة الكتب.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
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

