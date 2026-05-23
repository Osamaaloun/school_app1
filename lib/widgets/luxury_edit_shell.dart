import 'package:flutter/material.dart';

import '../theme/luxury_report_theme.dart';
import 'luxury_gold_frame.dart';

ThemeData luxuryEditThemeOverlay(BuildContext context) {
  final base = Theme.of(context);
  const gold = LuxuryReportTheme.gold;
  const light = LuxuryReportTheme.textLight;
  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1C1C1C),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF252525),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: gold.withOpacity(0.28)),
      ),
    ),
    dividerColor: gold.withOpacity(0.22),
    listTileTheme: const ListTileThemeData(
      iconColor: gold,
      textColor: light,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: light,
      displayColor: light,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: gold.withOpacity(0.45)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: gold.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: gold, width: 1.2),
      ),
      labelStyle: TextStyle(color: gold.withOpacity(0.92)),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIconColor: gold,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return gold;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: BorderSide(color: gold.withOpacity(0.75)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: gold),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.black,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2C2C2C),
      contentTextStyle: const TextStyle(color: light),
      actionTextColor: gold,
    ),
  );
}

/// وضع التعديل: خلفية سوداء، زوايا ذهبية، إطار داخلي ذهبي، شريط علوي ذهبي.
class LuxuryEditScaffold extends StatelessWidget {
  const LuxuryEditScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: luxuryEditThemeOverlay(context),
      child: Scaffold(
        backgroundColor: LuxuryReportTheme.background,
        appBar: title != null
            ? AppBar(
                backgroundColor: LuxuryReportTheme.background,
                foregroundColor: LuxuryReportTheme.gold,
                surfaceTintColor: Colors.transparent,
                iconTheme: const IconThemeData(color: LuxuryReportTheme.gold),
                title: DefaultTextStyle.merge(
                  style: LuxuryReportTheme.titleLarge(context),
                  child: title!,
                ),
                leading: leading,
                actions: actions,
                elevation: 0,
              )
            : null,
        floatingActionButton: floatingActionButton == null
            ? null
            : Theme(
                data: Theme.of(context).copyWith(
                  floatingActionButtonTheme: FloatingActionButtonThemeData(
                    backgroundColor: const Color(0xFF2A2415),
                    foregroundColor: LuxuryReportTheme.gold,
                    extendedTextStyle: const TextStyle(
                      color: LuxuryReportTheme.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: floatingActionButton!,
              ),
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const LuxuryGoldCorners(opacity: 0.4, size: 58),
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
