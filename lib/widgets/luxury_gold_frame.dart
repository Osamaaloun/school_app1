import 'package:flutter/material.dart';

import '../theme/luxury_report_theme.dart';

/// زخارف زوايا ذهبية (تُستخدم في التقارير ووضع التعديل).
class LuxuryGoldCorners extends StatelessWidget {
  const LuxuryGoldCorners({
    super.key,
    this.opacity = 0.28,
    this.size = 52,
    this.accentColor,
  });

  final double opacity;
  final double size;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final c = accentColor ?? LuxuryReportTheme.lookOf(context).accent;
    Widget corner(Alignment a, double rot) {
      return Align(
        alignment: a,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rot,
              child: CustomPaint(
                size: Size(size, size),
                painter: LuxuryFiligreePainter(color: c),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          corner(Alignment.topRight, 0),
          corner(Alignment.topLeft, 1.5708),
          corner(Alignment.bottomLeft, 3.14159),
          corner(Alignment.bottomRight, -1.5708),
        ],
      ),
    );
  }
}

/// خطوط إطار ذهبية رفيعة على حواف المنطقة الداخلية.
class LuxuryGoldInsetBorder extends StatelessWidget {
  const LuxuryGoldInsetBorder({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    this.borderRadius = 10,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final look = LuxuryReportTheme.lookOf(context);
    final border = look.accent.withOpacity(0.5);
    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: border, width: 1.25),
          boxShadow: [
            BoxShadow(
              color: look.accent.withOpacity(0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 0.5),
          child: ColoredBox(
            color: look.insetInner,
            child: child,
          ),
        ),
      ),
    );
  }
}

class LuxuryFiligreePainter extends CustomPainter {
  LuxuryFiligreePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.35)
      ..quadraticBezierTo(w * 0.2, 0, w * 0.55, 0)
      ..quadraticBezierTo(w, h * 0.15, w * 0.85, h * 0.45)
      ..quadraticBezierTo(w * 0.7, h, w * 0.25, h * 0.9)
      ..quadraticBezierTo(0, h * 0.75, 0, h * 0.35);
    canvas.drawPath(path, p);
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.2, h * 0.55), 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
