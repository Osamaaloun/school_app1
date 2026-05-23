import 'package:flutter/material.dart';

import '../models/grade_level.dart';
import '../widgets/luxury_edit_shell.dart';
import 'catalog_books_screen.dart';

/// اختيار صف لتعديل قائمة كتبه المعتمدة للاختيار عند التوزيع.
class GradeCatalogHubScreen extends StatelessWidget {
  const GradeCatalogHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryEditScaffold(
      title: const Text('قوائم الكتب حسب الصف'),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: GradeLevel.values.length,
        separatorBuilder: (context, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final grade = GradeLevel.values[index];
          return Card(
            child: ListTile(
              title: Text(grade.arabicLabel),
              subtitle: const Text('تعديل عناوين الكتب لهذا الصف فقط'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CatalogBooksScreen(grade: grade),
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

