import 'package:flutter/material.dart';

import '../models/grade_level.dart';
import '../theme/luxury_report_theme.dart';
import '../widgets/luxury_report_shell.dart';
import 'grade_report_detail_screen.dart';

IconData _luxuryIconForGrade(GradeLevel g) {
  final l = g.arabicLabel;
  if (l.contains('تكنولوج')) return Icons.computer_outlined;
  if (l.contains('إدارة') || l.contains('ادارة')) {
    return Icons.business_center_outlined;
  }
  if (l.contains('أكاديم')) return Icons.menu_book_outlined;
  return Icons.layers_outlined;
}

/// قائمة الصفوف — تصميم مسارات بثيم أسود/ذهبي (نفس ترتيب [GradeLevel] في التطبيق).
class GradeReportsScreen extends StatelessWidget {
  const GradeReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryReportShell(
      title: const Text('تقارير الصفوف'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        children: [
          Text(
            'وزارة التربية والتعليم',
            textAlign: TextAlign.center,
            style: LuxuryReportTheme.titleLarge(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'المملكة الأردنية الهاشمية',
            textAlign: TextAlign.center,
            style: LuxuryReportTheme.bodyGold(context),
          ),
          const SizedBox(height: 6),
          Text(
            'تقارير توزيع الكتب — اختر الصف',
            textAlign: TextAlign.center,
            style: LuxuryReportTheme.bodyWhite(context).copyWith(fontSize: 13),
          ),
          const LuxuryGoldDivider(),
          ...GradeLevel.values.map(
            (g) => LuxuryTrackTile(
              label: g.arabicLabel,
              icon: _luxuryIconForGrade(g),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GradeReportDetailScreen(grade: g),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
