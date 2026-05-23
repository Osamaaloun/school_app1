import 'package:flutter/material.dart';

import '../theme/luxury_report_theme.dart';
import 'grade_reports_screen.dart';
import 'grades_screen.dart';

/// شريط تنقل سفلي: تعديل البيانات، تقارير (تصميم التقرير الفاخر).
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  /// يبدأ من «تعديل» (قائمة الصفوف).
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          GradesScreen(),
          GradeReportsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: const Color(0xFF121212),
        indicatorColor: LuxuryReportTheme.gold.withOpacity(0.22),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.5)),
            selectedIcon: const Icon(Icons.edit, color: LuxuryReportTheme.gold),
            label: 'تعديل البيانات',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.summarize_outlined,
              color: Colors.white.withOpacity(0.5),
            ),
            selectedIcon:
                const Icon(Icons.summarize, color: LuxuryReportTheme.gold),
            label: 'تقارير',
          ),
        ],
      ),
    );
  }
}
