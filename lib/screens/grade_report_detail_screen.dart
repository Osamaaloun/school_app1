import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../db/student_database.dart';
import '../models/catalog_gap_entry.dart';
import '../models/grade_level.dart';
import '../services/grade_catalog_report_pdf.dart';
import '../theme/luxury_report_theme.dart';
import '../widgets/luxury_report_shell.dart';
import 'student_detail_screen.dart';

/// تقرير جدولي: نفس بيانات الكتالوج والطلاب؛ تصميم أسود/ذهبي.
class GradeReportDetailScreen extends StatefulWidget {
  const GradeReportDetailScreen({super.key, required this.grade});

  final GradeLevel grade;

  @override
  State<GradeReportDetailScreen> createState() =>
      _GradeReportDetailScreenState();
}

class _GradeReportDetailScreenState extends State<GradeReportDetailScreen> {
  static const double _kTableStrokeWidth = 1.4;

  List<CatalogGapEntry>? _rows;
  List<String> _catalogTitles = [];
  bool _loading = true;
  String? _error;

  final ScrollController _verticalScroll = ScrollController();

  /// وضع فاتح بلوحة الأخضر أو الوضع الداكن الافتراضي.
  bool _lightMode = false;

  /// أعمدة مرنة حسب عرض المنطقة (يشمل عمود الرقم الوطني).
  ({
    double wi,
    double wn,
    double wid,
    double wt,
    double wto,
    double wd,
    double textScale
  }) _tableWidths(
    double viewportWidth,
    int titleCount,
  ) {
    final vw = viewportWidth.clamp(120.0, double.infinity);
    final baseScale = (vw / 760).clamp(0.55, 1.32);
    final textScale = baseScale.clamp(0.72, 1.22);

    double wi = (36 * baseScale).clamp(30.0, 52.0);
    double wto = (48 * baseScale).clamp(40.0, 62.0);
    double wd = (60 * baseScale).clamp(50.0, 80.0);
    double wid = (78 * baseScale).clamp(64.0, 96.0);

    if (titleCount <= 0) {
      final pool = vw - wi - wto - wd - wid;
      return (
        wi: wi,
        wn: math.max(96, pool * 0.52),
        wid: wid,
        wt: 56,
        wto: wto,
        wd: wd,
        textScale: textScale,
      );
    }

    const wtMin = 26.0;
    const wtMax = 66.0;
    const wnMin = 100.0;

    double pool = vw - wi - wto - wd - wid;
    if (pool < wnMin + titleCount * wtMin) {
      final factor = pool / (wnMin + titleCount * wtMin);
      wi *= math.max(0.75, factor);
      wto *= math.max(0.75, factor);
      wd *= math.max(0.75, factor);
      wid *= math.max(0.82, factor);
      pool = vw - wi - wto - wd - wid;
    }

    double wt = ((pool - wnMin) / titleCount).clamp(wtMin, wtMax);
    double wn = pool - titleCount * wt;

    if (wn < wnMin) {
      wn = wnMin;
      wt = ((pool - wn) / titleCount).clamp(wtMin, wtMax);
      wn = pool - titleCount * wt;
    }

    if (wn > 280) {
      wn = 280;
      wt = ((pool - wn) / titleCount).clamp(wtMin, wtMax);
      wn = pool - titleCount * wt;
    }

    var total = wi + wn + wid + titleCount * wt + wto + wd;
    wn += vw - total;
    if (wn < wnMin) {
      wn = wnMin;
      wt = ((pool - wn) / titleCount).clamp(wtMin, wtMax);
      wn = pool - titleCount * wt;
      total = wi + wn + wid + titleCount * wt + wto + wd;
      wn += vw - total;
    }

    return (
      wi: wi,
      wn: wn,
      wid: wid,
      wt: wt,
      wto: wto,
      wd: wd,
      textScale: textScale,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog =
          await StudentDatabase.instance.listCatalogBookTitlesForGrade(
        widget.grade,
      );
      final list =
          await StudentDatabase.instance.listCatalogGapsForGrade(widget.grade);
      if (mounted) {
        setState(() {
          _catalogTitles = List<String>.from(catalog);
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openStudent(int id) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudentDetailScreen(studentId: id),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _exportPdf(BuildContext context) async {
    final rows = _rows;
    final titles = _catalogTitles;
    if (rows == null || rows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد بيانات للتصدير')),
        );
      }
      return;
    }
    try {
      final bytes = await buildGradeCatalogReportPdf(
        grade: widget.grade,
        catalogTitles: titles,
        rows: rows,
      );
      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء PDF: $e')),
        );
      }
    }
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildReceiptPieChart(BuildContext context, List<CatalogGapEntry> rows) {
    final look = LuxuryReportTheme.lookOf(context);
    final complete = rows.where((e) => !e.hasGap).length;
    final withGap = rows.where((e) => e.hasGap).length;
    final total = complete + withGap;
    if (total == 0) return const SizedBox.shrink();

    final okColor = const Color(0xFF2E7D32);
    final gapColor = LuxuryReportTheme.deficitRed;

    List<PieChartSectionData> sections;
    if (complete == 0) {
      sections = [
        PieChartSectionData(
          color: gapColor,
          value: withGap.toDouble(),
          title: '$withGap',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ];
    } else if (withGap == 0) {
      sections = [
        PieChartSectionData(
          color: okColor,
          value: complete.toDouble(),
          title: '$complete',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ];
    } else {
      final pC = ((complete / total) * 100).round();
      final pG = ((withGap / total) * 100).round();
      sections = [
        PieChartSectionData(
          color: okColor,
          value: complete.toDouble(),
          title: '$pC%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        PieChartSectionData(
          color: gapColor,
          value: withGap.toDouble(),
          title: '$pG%',
          radius: 46,
          titleStyle: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: look.accent.withOpacity(0.42)),
          borderRadius: BorderRadius.circular(10),
          color: look.surfaceCard,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 1.5,
                    centerSpaceRadius: 34,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استلام الكتالوج',
                      style: LuxuryReportTheme.titleLarge(context)
                          .copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _legendDot(okColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'مستلمون بالكامل: $complete',
                            style: LuxuryReportTheme.bodyWhite(context)
                                .copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _legendDot(gapColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لديهم نقص: $withGap',
                            style: LuxuryReportTheme.bodyWhite(context)
                                .copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _th(
    BuildContext context,
    double textScale, {
    double? capFontByWidth,
  }) {
    var fs = (12.5 * textScale).clamp(10.0, 14.5);
    if (capFontByWidth != null) {
      fs = math.min(fs, capFontByWidth * 0.36).clamp(8.0, 14.5);
    }
    return LuxuryReportTheme.tableHeader(context).copyWith(
      fontSize: fs,
      height: 1.28,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  TextStyle _tw(BuildContext context, double textScale) =>
      LuxuryReportTheme.tableCellWhite(context).copyWith(
        fontSize: (12 * textScale).clamp(10.0, 14.5),
        height: 1.28,
        leadingDistribution: TextLeadingDistribution.even,
      );

  Widget _hCell(
    BuildContext context,
    String text,
    double w,
    double textScale, {
    bool compactBookHeader = false,
  }) {
    final hPad = compactBookHeader
        ? math.min(3.5 * textScale, w * 0.12).clamp(1.0, 6.0)
        : math.min(5 * textScale, w * 0.16).clamp(2.0, 10.0);
    final innerW = math.max(1.0, w - 2 * hPad);
    final style = _th(
      context,
      textScale,
      capFontByWidth: compactBookHeader ? w : null,
    );
    final normalText = Text(
      text,
      style: style,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    final fittedBookTitle = Text(
      text,
      style: style,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
    return SizedBox(
      width: w,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: compactBookHeader ? 6 : 8,
        ),
        child: Center(
          child: compactBookHeader
              ? SizedBox(
                  width: innerW,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: fittedBookTitle,
                  ),
                )
              : SizedBox(width: innerW, child: normalText),
        ),
      ),
    );
  }

  Widget _rowLine({
    required BuildContext context,
    required List<Widget> cells,
    Color? rowTint,
  }) {
    final accent = LuxuryReportTheme.lookOf(context).accent;
    return Container(
      decoration: BoxDecoration(
        color: rowTint,
        border: Border(
          bottom: BorderSide(
            color: accent.withOpacity(0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: cells,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look =
        _lightMode ? LuxuryReportLook.lightMint : LuxuryReportLook.dark;
    return LuxuryReportShell(
      look: look,
      title: Text(widget.grade.arabicLabel),
      actions: [
        IconButton(
          tooltip: 'تصدير PDF',
          onPressed: _loading ? null : () => _exportPdf(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          color: look.accent,
        ),
        IconButton(
          tooltip: _lightMode ? 'الوضع الداكن' : 'الوضع الفاتح',
          onPressed: () => setState(() => _lightMode = !_lightMode),
          icon: Icon(_lightMode ? Icons.dark_mode : Icons.light_mode),
          color: look.accent,
        ),
        IconButton(
          tooltip: 'تحديث',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          color: look.accent,
        ),
      ],
      body: Builder(
        builder: (innerContext) => _buildBody(innerContext),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: LuxuryReportTheme.lookOf(context).accent,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'تعذر التحميل: $_error',
          style: LuxuryReportTheme.bodyGold(context),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_rows == null || _rows!.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد طلاب في هذا الصف',
          style: LuxuryReportTheme.bodyGold(context),
        ),
      );
    }

    final gaps = _rows!.where((e) => e.hasGap).length;
    final titles = _catalogTitles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Builder(
            builder: (context) {
              final accent = LuxuryReportTheme.lookOf(context).accent;
              return Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2.2),
                  color: accent.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: accent,
                  size: 42,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'وزارة التربية والتعليم',
          textAlign: TextAlign.center,
          style: LuxuryReportTheme.titleLarge(context).copyWith(fontSize: 18),
        ),
        Text(
          'المملكة الأردنية الهاشمية',
          textAlign: TextAlign.center,
          style: LuxuryReportTheme.bodyGold(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          widget.grade.arabicLabel,
          textAlign: TextAlign.center,
          style: LuxuryReportTheme.titleLarge(context).copyWith(fontSize: 22),
        ),
        const LuxuryGoldDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'عدد الطلاب: ${_rows!.length}  |  عناوين الكتالوج: ${titles.length}  |  '
            'من لديهم نقص: $gaps',
            textAlign: TextAlign.center,
            style: LuxuryReportTheme.bodyWhite(context).copyWith(fontSize: 14),
          ),
        ),
        _buildReceiptPieChart(context, _rows!),
        const SizedBox(height: 8),
        Expanded(
          child: titles.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد كتالوج لهذا الصف — أضف عناوين الكتب من شاشة التعديل.',
                    textAlign: TextAlign.center,
                    style: LuxuryReportTheme.bodyGold(context),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, inner) {
                    final tableInnerW = math.max(
                      60.0,
                      inner.maxWidth - 2 * _kTableStrokeWidth,
                    );
                    final cw = _tableWidths(
                      tableInnerW,
                      titles.length,
                    );
                    final ts = cw.textScale;
                    final markSize = math
                        .min(16 * ts, cw.wt * 0.4)
                        .clamp(11.0, 20.0);
                    final barSide =
                        Directionality.of(context) == TextDirection.rtl
                            ? ScrollbarOrientation.left
                            : ScrollbarOrientation.right;
                    return Scrollbar(
                      controller: _verticalScroll,
                      thumbVisibility: true,
                      thickness: 8,
                      radius: const Radius.circular(8),
                      scrollbarOrientation: barSide,
                      child: SingleChildScrollView(
                        controller: _verticalScroll,
                        scrollDirection: Axis.vertical,
                        clipBehavior: Clip.hardEdge,
                        physics: const ClampingScrollPhysics(),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: inner.maxWidth,
                            child: Container(
                                              decoration: BoxDecoration(
                                                color: LuxuryReportTheme.lookOf(
                                                        context)
                                                    .surfaceCard,
                                                border: Border.all(
                                                  color: LuxuryReportTheme
                                                      .lookOf(context)
                                                      .accent
                                                      .withOpacity(0.55),
                                                  width: _kTableStrokeWidth,
                                                ),
                                              ),
                                              child: SizedBox(
                                                width: tableInnerW,
                                                child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _rowLine(
                                                    context: context,
                                                    cells: [
                                                      _hCell(
                                                          context, 'م', cw.wi, ts),
                                                      _hCell(
                                                        context,
                                                        'اسم الطالب',
                                                        cw.wn,
                                                        ts,
                                                      ),
                                                      _hCell(
                                                        context,
                                                        'الرقم الوطني',
                                                        cw.wid,
                                                        ts,
                                                      ),
                                                      ...titles.map(
                                                        (t) => _hCell(
                                                          context,
                                                          t,
                                                          cw.wt,
                                                          ts,
                                                          compactBookHeader:
                                                              true,
                                                        ),
                                                      ),
                                                      _hCell(context, 'المجموع',
                                                          cw.wto, ts),
                                                      _hCell(context, 'يوجد نقص',
                                                          cw.wd, ts),
                                                    ],
                                                  ),
                                                  ...List.generate(
                                                      _rows!.length, (i) {
                                                    final e = _rows![i];
                                                    final gap = e.hasGap;
                                                    final received = titles
                                                            .length -
                                                        e.missingCatalogTitles
                                                            .length;
                                                    final cells = <Widget>[
                                                      SizedBox(
                                                        width: cw.wi,
                                                        child: Padding(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            vertical: 10 *
                                                                ts.clamp(
                                                                    1.0, 1.15),
                                                          ),
                                                          child: Text(
                                                            '${i + 1}',
                                                            style: _tw(
                                                                context, ts),
                                                            textAlign:
                                                                TextAlign.center,
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: cw.wn,
                                                        child: Padding(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal: 6 * ts,
                                                            vertical: 10 *
                                                                ts.clamp(
                                                                    1.0, 1.15),
                                                          ),
                                                          child: Text(
                                                            e.studentName,
                                                            style: _tw(
                                                                    context, ts)
                                                                .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: cw.wid,
                                                        child: Padding(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal: 4 * ts,
                                                            vertical: 10 *
                                                                ts.clamp(
                                                                    1.0, 1.15),
                                                          ),
                                                          child: Text(
                                                            e.nationalId
                                                                    .isEmpty
                                                                ? '—'
                                                                : e.nationalId,
                                                            style: _tw(
                                                                context, ts),
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                            textAlign:
                                                                TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                      ...titles.map((t) {
                                                        final ok = !e
                                                            .missingCatalogTitles
                                                            .contains(t);
                                                        return SizedBox(
                                                          width: cw.wt,
                                                          child: Center(
                                                            child: Text(
                                                              ok ? '✓' : '✗',
                                                              style: TextStyle(
                                                                color: ok
                                                                    ? LuxuryReportTheme
                                                                        .tablePositiveColor(
                                                                            context)
                                                                    : LuxuryReportTheme
                                                                        .deficitRed,
                                                                fontSize:
                                                                    markSize,
                                                                height: 1.1,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              maxLines: 1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                      SizedBox(
                                                        width: cw.wto,
                                                        child: Center(
                                                          child: Text(
                                                            '$received',
                                                            style: _tw(
                                                                context, ts),
                                                            maxLines: 1,
                                                            textAlign:
                                                                TextAlign.center,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: cw.wd,
                                                        child: Center(
                                                          child: Text(
                                                            gap ? 'نعم' : 'لا',
                                                            style: _tw(
                                                                    context, ts)
                                                                .copyWith(
                                                              color: gap
                                                                  ? LuxuryReportTheme
                                                                      .deficitRed
                                                                  : LuxuryReportTheme
                                                                      .tableAccentColor(
                                                                          context),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                            maxLines: 1,
                                                            textAlign:
                                                                TextAlign.center,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                    ];
                                                    return Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () =>
                                                            _openStudent(
                                                                e.studentId),
                                                        hoverColor:
                                                            LuxuryReportTheme
                                                                .lookOf(context)
                                                                .accent
                                                                .withOpacity(
                                                                    0.12),
                                                        splashColor:
                                                            LuxuryReportTheme
                                                                .lookOf(context)
                                                                .accent
                                                                .withOpacity(
                                                                    0.18),
                                                        child: _rowLine(
                                                          context: context,
                                                          rowTint: gap
                                                              ? const Color(
                                                                  0x22FF5252)
                                                              : null,
                                                          cells: cells,
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                              ),
                                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: Text(
            'اضغط على صف لعرض بطاقة الطالب وتعديل كتبه.',
            textAlign: TextAlign.center,
            style: LuxuryReportTheme.bodyGold(context).copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
