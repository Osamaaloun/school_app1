import 'package:flutter/material.dart';

import '../theme/luxury_report_theme.dart';
import 'luxury_gold_frame.dart';

/// خلفية + زخارف زاوية + شريط علوي اختياري (تقارير).
/// [look] يحدد الوضع الداكن أو الفاتح (مثلاً [LuxuryReportLook.lightMint]).
class LuxuryReportShell extends StatelessWidget {
  const LuxuryReportShell({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.look = LuxuryReportLook.dark,
  });

  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final LuxuryReportLook look;

  @override
  Widget build(BuildContext context) {
    return LuxuryReportLookScope(
      look: look,
      child: Scaffold(
        backgroundColor: look.background,
        appBar: title != null
            ? AppBar(
                backgroundColor: look.background,
                foregroundColor: look.accent,
                iconTheme: IconThemeData(color: look.accent),
                title: DefaultTextStyle.merge(
                  style: LuxuryReportTheme.titleLarge(context),
                  child: title!,
                ),
                leading: leading,
                actions: actions,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              )
            : null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            LuxuryGoldCorners(
              opacity: look.cornerOpacity,
              size: 48,
              accentColor: look.accent,
            ),
            SafeArea(
              child: LuxuryGoldInsetBorder(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر مسار بحدود ذهبية مزدوجة وزوايا مقطّعة تقريبياً.
class LuxuryTrackTile extends StatelessWidget {
  const LuxuryTrackTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Material(
        color: LuxuryReportTheme.background,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: LuxuryReportTheme.gold.withOpacity(0.12),
          highlightColor: LuxuryReportTheme.gold.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: LuxuryReportTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: LuxuryReportTheme.gold, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: LuxuryReportTheme.gold.withOpacity(0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: LuxuryReportTheme.gold.withOpacity(0.65),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: LuxuryReportTheme.gold, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: LuxuryReportTheme.titleLarge(context).copyWith(
                        fontSize: 17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(
                    Icons.chevron_left,
                    color: LuxuryReportTheme.gold.withOpacity(0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فاصل أفقي مع لمعان في المنتصف.
class LuxuryGoldDivider extends StatelessWidget {
  const LuxuryGoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = LuxuryReportTheme.lookOf(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: accent.withOpacity(0.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 8,
              height: 8,
              transform: Matrix4.rotationZ(0.785398),
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 1),
                color: accent.withOpacity(0.25),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: accent.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }
}
