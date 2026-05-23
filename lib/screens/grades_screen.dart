import 'package:flutter/material.dart';

import '../models/grade_level.dart';
import '../widgets/luxury_edit_shell.dart';
import 'grade_catalog_hub_screen.dart';
import 'grade_students_screen.dart';

/// الصفحة الرئيسية: اختيار صف ثم الانتقال لقائمة طلابه.
class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryEditScaffold(
      title: const Text('توزيع الكتب'),
      actions: [
        IconButton(
          tooltip: 'قوائم الكتب حسب الصف',
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const GradeCatalogHubScreen(),
              ),
            );
          },
          icon: const Icon(Icons.menu_book_outlined),
        ),
      ],
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: GradeLevel.values.length,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final grade = GradeLevel.values[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              title: Text(
                grade.arabicLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('عرض الطلاب وإدارتهم'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GradeStudentsScreen(grade: grade),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

