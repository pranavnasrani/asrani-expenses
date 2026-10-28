import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../utils/money.dart';

class ExportService {
  static final _stamp = DateFormat('yyyyMMdd_HHmm');

  Future<void> _shareBytes(Uint8List bytes, String name, String mime) async {
    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(bytes, name: name, mimeType: mime),
      ], subject: 'Asrani Expenses export');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([
      XFile(file.path, mimeType: mime),
    ], subject: 'Asrani Expenses export');
  }

  Future<void> exportCsv(List<Expense> expenses, {required String label}) async {
    if (expenses.isEmpty) throw StateError('There are no expenses to export.');
    final rows = <List<dynamic>>[
      ['Date', 'Title', 'Amount (SGD)', 'Category', 'Payment method', 'Place'],
      for (final e in expenses)
        [
          DateFormat('yyyy-MM-dd').format(e.date),
          e.title,
          e.amount.toStringAsFixed(2),
          e.category,
          e.paymentMethod,
          e.place,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await _shareBytes(
      Uint8List.fromList(utf8.encode(csv)),
      'expenses_${_slug(label)}_${_stamp.format(DateTime.now())}.csv',
      'text/csv',
    );
  }

  Future<void> exportPdf(List<Expense> expenses, {required String label}) async {
    if (expenses.isEmpty) throw StateError('There are no expenses to export.');
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final byCategory = <String, double>{};
    final byMethod = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      byMethod[e.paymentMethod] = (byMethod[e.paymentMethod] ?? 0) + e.amount;
    }
    final jade = PdfColor.fromInt(0xFF1E6F66);

    pw.Widget totals(String title, Map<String, double> map) {
      final entries = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final e in entries)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(e.key), pw.Text(Money.format(e.value))],
              ),
            ),
        ],
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Asrani Expenses: $label',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: jade),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generated ${DateFormat('d MMMM y').format(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE6F2EF),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${expenses.length} expenses'),
                pw.Text(
                  Money.format(total),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: totals('By category', byCategory)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: totals('By payment method', byMethod)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: jade),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            headers: ['Date', 'Title', 'Category', 'Method', 'Amount'],
            data: [
              for (final e in expenses)
                [
                  DateFormat('d MMM').format(e.date),
                  e.title,
                  e.category,
                  e.paymentMethod,
                  Money.format(e.amount),
                ],
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'expenses_${_slug(label)}_${_stamp.format(DateTime.now())}.pdf',
    );
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}
