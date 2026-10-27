import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'categories.dart';
import 'layout.dart';
import 'models.dart';

pw.ThemeData? _theme;

Future<pw.ThemeData> _loadTheme() async {
  if (_theme != null) return _theme!;
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  _theme = pw.ThemeData.withFont(base: reg, bold: bold);
  return _theme!;
}

/// PDF: одна страница A4 на каждую категорию.
Future<Uint8List> buildBracketsPdf(Tournament t, List<WeightCategory> cats) async {
  final doc = pw.Document(theme: await _loadTheme(), title: t.name);
  final asg = assign(t);
  final byId = t.byId;

  var pages = 0;
  for (final c in cats) {
    final slots = t.brackets[c.key];
    final members = asg.members[c.key] ?? const <Participant>[];
    if (slots == null || members.length < 2) continue;
    doc.addPage(_page(t, c, slots, byId, members.length));
    pages++;
  }

  if (pages == 0) {
    doc.addPage(pw.Page(
        build: (_) => pw.Center(child: pw.Text('Нет сформированных сеток'))));
  }
  return doc.save();
}

pw.Page _page(Tournament t, WeightCategory c, List<String?> slots,
    Map<String, Participant> byId, int count) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(t.name,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.Text([fmtDate(t.date), if (t.place.isNotEmpty) t.place].join('  ·  '),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Text(c.title,
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Spacer(),
          pw.Text('Участников: $count', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.Divider(thickness: 0.6),
        pw.SizedBox(height: 4),
        pw.Expanded(
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: _bracket(slots, byId),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          pw.Text('Главный судья ____________________',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Spacer(),
          pw.Text('Главный секретарь ____________________',
              style: const pw.TextStyle(fontSize: 9)),
        ]),
      ],
    ),
  );
}

pw.Widget _bracket(List<String?> slots, Map<String, Participant> byId) {
  final g = BracketGeometry(slots.length, slots,
      boxW: 150, boxH: 28, colGap: 26, rowGap: 4, pairGap: 12, topPad: 18);
  final children = <pw.Widget>[];

  for (var k = 0; k <= g.rounds; k++) {
    children.add(pw.Positioned(
      left: g.cols[k].first.x,
      top: 0,
      child: pw.SizedBox(
        width: g.boxW,
        child: pw.Text(roundTitle(k, g.rounds),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
    ));
  }

  for (final s in g.lines) {
    children.add(pw.Positioned(
      left: s.x,
      top: s.y,
      child: pw.Container(
        width: s.w == 1 ? 0.8 : s.w,
        height: s.h == 1 ? 0.8 : s.h,
        color: PdfColors.grey700,
      ),
    ));
  }

  for (final l in g.labels) {
    children.add(pw.Positioned(
      left: l.x + 2,
      top: l.y - 10,
      child: pw.Text('№${l.number}',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
    ));
  }

  for (var k = 0; k <= g.rounds; k++) {
    for (var j = 0; j < g.cols[k].length; j++) {
      final pos = g.cols[k][j];
      final id = shownId(k, j, slots);
      final p = id == null ? null : byId[id];
      children.add(pw.Positioned(
        left: pos.x,
        top: pos.y,
        child: pw.Container(
          width: g.boxW,
          height: g.boxH,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey800, width: 0.7),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          alignment: pw.Alignment.centerLeft,
          child: p == null
              ? pw.SizedBox()
              : pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shorten(p.name, 26),
                        style: pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    if (p.team.isNotEmpty)
                      pw.Text(shorten(p.team, 32),
                          style: const pw.TextStyle(
                              fontSize: 6.5, color: PdfColors.grey700)),
                  ],
                ),
        ),
      ));
    }
  }

  return pw.SizedBox(
    width: g.width + 20,
    height: g.height + 4,
    child: pw.Stack(children: children),
  );
}

/// Экран предпросмотра PDF с кнопками «Поделиться» / «Печать» / сохранить.
class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final String fileName;
  final Future<Uint8List> Function() builder;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) => builder(),
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
