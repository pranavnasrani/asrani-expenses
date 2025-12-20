import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Export expenses to CSV format
  Future<void> exportToCSV({DateTime? startDate, DateTime? endDate}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Fetch expenses
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();
    final expenses = snapshot.docs;

    if (expenses.isEmpty) {
      throw Exception('No expenses to export');
    }

    // Create CSV data
    List<List<dynamic>> rows = [
      ['Title', 'Amount', 'Date', 'Category', 'Payment Method', 'Place'],
    ];

    for (var doc in expenses) {
      final data = doc.data() as Map<String, dynamic>;
      final date = _parseDate(data['date']);

      rows.add([
        data['title'] ?? 'Untitled',
        data['amount']?.toString() ?? '0',
        date != null ? DateFormat('yyyy-MM-dd').format(date) : 'N/A',
        data['category'] ?? 'Other',
        data['paymentMethod'] ?? 'Cash',
        data['place'] ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      // For web, use share_plus which handles downloads
      await Share.share(csvString, subject: 'Expenses Export');
    } else {
      // For mobile, save and share file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'expenses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      await Share.shareXFiles([XFile(file.path)], subject: 'Expenses Export');
    }
  }

  /// Export expenses to PDF format
  Future<void> exportToPDF({DateTime? startDate, DateTime? endDate}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Fetch expenses
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();
    final expenses = snapshot.docs;

    if (expenses.isEmpty) {
      throw Exception('No expenses to export');
    }

    // Calculate totals
    double totalAmount = 0;
    Map<String, double> categoryTotals = {};
    Map<String, double> paymentMethodTotals = {};

    for (var doc in expenses) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final category = data['category'] ?? 'Other';
      final paymentMethod = data['paymentMethod'] ?? 'Cash';

      totalAmount += amount;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      paymentMethodTotals[paymentMethod] =
          (paymentMethodTotals[paymentMethod] ?? 0) + amount;
    }

    // Create PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Expense Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated on ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            if (startDate != null || endDate != null)
              pw.Text(
                'Period: ${startDate != null ? DateFormat('MMM d').format(startDate) : 'All'} - ${endDate != null ? DateFormat('MMM d, yyyy').format(endDate) : 'Present'}',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (context) => [
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Expenses:'),
                    pw.Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Number of Transactions:'),
                    pw.Text('${expenses.length}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Category Breakdown
          pw.Text(
            'By Category',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...categoryTotals.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(e.key),
                  pw.Text('\$${e.value.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),

          // Payment Method Breakdown
          pw.Text(
            'By Payment Method',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...paymentMethodTotals.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(e.key),
                  pw.Text('\$${e.value.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),

          // Expense List
          pw.Text(
            'All Expenses',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
            headers: ['Title', 'Amount', 'Date', 'Category'],
            data: expenses.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = _parseDate(data['date']);
              return [
                data['title'] ?? 'Untitled',
                '\$${(data['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                date != null ? DateFormat('MMM d').format(date) : 'N/A',
                data['category'] ?? 'Other',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    // Share or print PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'expense_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  DateTime? _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
