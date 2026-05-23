import 'package:flutter/material.dart';

/// مظهر شاشة التقرير: الوضع الداكن (أسود/ذهبي) أو الفاتح (أخضر/نعناعي).
@immutable
class LuxuryReportLook {
  const LuxuryReportLook({
    required this.background,
    required this.insetInner,
    required this.surfaceCard,
    required this.accent,
    required this.accentSecondary,
    required this.titleColor,
    required this.bodyMutedColor,
    required this.bodyPrimaryColor,
    required this.tableHeaderColor,
    required this.tableCellColor,
    required this.cornerOpacity,
  });

  final Color background;
  final Color insetInner;
  final Color surfaceCard;
  final Color accent;
  final Color accentSecondary;
  final Color titleColor;
  final Color bodyMutedColor;
  final Color bodyPrimaryColor;
  final Color tableHeaderColor;
  final Color tableCellColor;
  final double cornerOpacity;

  /// الوضع الداكن الافتراضي (ذهبي/أسود).
  static const LuxuryReportLook dark = LuxuryReportLook(
    background: Color(0xFF000000),
    insetInner: Color(0xFF0D0D0D),
    surfaceCard: Color(0xFF141414),
    accent: Color(0xFFD4AF37),
    accentSecondary: Color(0xFFB8860B),
    titleColor: Color(0xFFD4AF37),
    bodyMutedColor: Color(0xFFD4AF37),
    bodyPrimaryColor: Color(0xFFF5F5F5),
    tableHeaderColor: Color(0xFFD4AF37),
    tableCellColor: Color(0xFFF5F5F5),
    cornerOpacity: 0.22,
  );

  /// وضع فاتح بلوحة الأخضر المحددة: #0B1614، #2D5A4E، #4A917E، #ADE0CB.
  static const LuxuryReportLook lightMint = LuxuryReportLook(
    background: Color(0xFFADE0CB),
    insetInner: Color(0xFFE8F8F1),
    surfaceCard: Color(0xFFF4FCF8),
    accent: Color(0xFF4A917E),
    accentSecondary: Color(0xFF2D5A4E),
    titleColor: Color(0xFF2D5A4E),
    bodyMutedColor: Color(0xFF4A917E),
    bodyPrimaryColor: Color(0xFF0B1614),
    tableHeaderColor: Color(0xFF2D5A4E),
    tableCellColor: Color(0xFF0B1614),
    cornerOpacity: 0.38,
  );
}

/// يمرّر [LuxuryReportLook] ل descendants (عادة من [LuxuryReportShell]).
class LuxuryReportLookScope extends InheritedWidget {
  const LuxuryReportLookScope({
    super.key,
    required this.look,
    required super.child,
  });

  final LuxuryReportLook look;

  static LuxuryReportLook of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LuxuryReportLookScope>();
    assert(scope != null, 'LuxuryReportLookScope not found');
    return scope!.look;
  }

  static LuxuryReportLook? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LuxuryReportLookScope>()?.look;

  @override
  bool updateShouldNotify(covariant LuxuryReportLookScope oldWidget) =>
      look != oldWidget.look;
}

/// ألوان وتنسيقات تقارير «الثيم الفاخر» — تتأثر بـ [LuxuryReportLookScope] عند توفره.
abstract final class LuxuryReportTheme {
  /// للتوافق مع الشيفرة القديمة خارج نطاق المظهر.
  static const Color background = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFB8860B);
  static const Color textLight = Color(0xFFF5F5F5);
  static const Color deficitRed = Color(0xFFFF5252);

  static LuxuryReportLook lookOf(BuildContext context) =>
      LuxuryReportLookScope.maybeOf(context) ?? LuxuryReportLook.dark;

  static TextStyle titleLarge(BuildContext context) {
    final look = lookOf(context);
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          color: look.titleColor,
          fontWeight: FontWeight.bold,
          height: 1.3,
        );
  }

  static TextStyle bodyGold(BuildContext context) {
    final look = lookOf(context);
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: look.bodyMutedColor,
          height: 1.35,
        );
  }

  static TextStyle bodyWhite(BuildContext context) {
    final look = lookOf(context);
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: look.bodyPrimaryColor,
          height: 1.35,
        );
  }

  static TextStyle tableHeader(BuildContext context) {
    final look = lookOf(context);
    return Theme.of(context).textTheme.labelLarge!.copyWith(
          color: look.tableHeaderColor,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
  }

  static TextStyle tableCellWhite(BuildContext context) {
    final look = lookOf(context);
    return Theme.of(context).textTheme.bodySmall!.copyWith(
          color: look.tableCellColor,
          height: 1.2,
        );
  }

  /// لون «موافق» في خلايا الجدول (علامة صح).
  static Color tablePositiveColor(BuildContext context) =>
      lookOf(context).tableCellColor;

  /// لون التمييز الثانوي (مثل «لا» بدون نقص في الوضع الفاتح).
  static Color tableAccentColor(BuildContext context) =>
      lookOf(context).accent;
}
