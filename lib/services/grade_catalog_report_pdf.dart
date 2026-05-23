import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/catalog_gap_entry.dart';
import '../models/grade_level.dart';

/// يبني PDF لتقرير الكتالوج (عربي) باستخدام خط مناسب من Google Fonts.
Future<Uint8List> buildGradeCatalogReportPdf({
  required GradeLevel grade,
  required List<String> catalogTitles,
  required List<CatalogGapEntry> rows,
}) async {
  final font = await PdfGoogleFonts.notoNaskhArabicRegular();
  final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
  final base = pw.TextStyle(font: font, fontSize: 8);
  final headerStyle = pw.TextStyle(font: fontBold, fontSize: 8);

  String cell(String s, {int maxLen = 40}) {
    final t = s.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1)}…';
  }

  final headers = <String>[
    'م',
    'اسم الطالب',
    'الرقم الوطني',
    ...catalogTitles.map((t) => cell(t, maxLen: 22)),
    'المجموع',
    'نقص',
  ];

  final data = <List<String>>[];
  for (var i = 0; i < rows.length; i++) {
    final e = rows[i];
    final received =
        catalogTitles.length - e.missingCatalogTitles.length;
    final row = <String>[
      '${i + 1}',
      cell(e.studentName, maxLen: 36),
      e.nationalId.isEmpty ? '—' : cell(e.nationalId, maxLen: 20),
      ...catalogTitles.map((t) => e.missingCatalogTitles.contains(t) ? '✗' : '✓'),
      '$received',
      e.hasGap ? 'نعم' : 'لا',
    ];
    data.add(row);
  }

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      textDirection: pw.TextDirection.rtl,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'تقرير كتب الصف — ${grade.arabicLabel}',
            style: pw.TextStyle(font: fontBold, fontSize: 14),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'عدد الطلاب: ${rows.length}  |  عناوين الكتالوج: ${catalogTitles.length}',
          style: base,
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 12),
        if (data.isEmpty)
          pw.Text(
            'لا توجد بيانات طلاب.',
            style: base,
            textDirection: pw.TextDirection.rtl,
          )
        else
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: headerStyle,
            cellStyle: base,
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
            cellHeight: 22,
            headerHeight: 26,
          ),
      ],
    ),
  );

  return doc.save();
}
