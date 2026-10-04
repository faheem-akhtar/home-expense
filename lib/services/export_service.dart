import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../models/month_record.dart';
import '../utils/format.dart';

/// Builds yearly reports and hands them to the OS share sheet
/// (email, WhatsApp, Files, ...).
class ExportService {
  ExportService._();
  static final instance = ExportService._();

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  List<String> _monthKeys(int year) =>
      [for (var m = 1; m <= 12; m++) monthKeyOf(DateTime(year, m))];

  Future<void> shareCsv({
    required int year,
    required List<MonthRecord> months,
    required List<Expense> expenses,
  }) async {
    final byKey = {for (final m in months) m.key: m};
    final rows = <List<Object?>>[
      ['Monthly summary $year'],
      ['Month', 'Budget (AED)', 'Spent (AED)', 'Remaining (AED)'],
      for (final key in _monthKeys(year))
        () {
          final budget = byKey[key]?.totalBudget ?? 0;
          final spent = _spent(expenses, key);
          return [monthLabel(key), budget, spent, budget - spent];
        }(),
      [],
      ['Transactions'],
      ['Date', 'Added by', 'Category', 'Amount (AED)', 'Payment', 'Notes / Merchant'],
      for (final e in expenses)
        [
          _dateFmt.format(e.createdAt),
          e.userName,
          e.bucketName,
          e.amount,
          e.paymentMethod.label,
          e.note,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final file = await _tempFile('expenses_$year.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
        subject: 'Expense report $year');
  }

  Future<void> sharePdf({
    required int year,
    required List<MonthRecord> months,
    required List<Expense> expenses,
  }) async {
    final byKey = {for (final m in months) m.key: m};
    final perCategory = <String, double>{};
    for (final e in expenses) {
      perCategory[e.bucketName] = (perCategory[e.bucketName] ?? 0) + e.amount;
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, text: 'Expense report $year'),
        pw.Header(level: 1, text: 'Month by month'),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Budget', 'Spent', 'Remaining'],
          data: [
            for (final key in _monthKeys(year))
              () {
                final budget = byKey[key]?.totalBudget ?? 0;
                final spent = _spent(expenses, key);
                return [monthLabel(key), aed(budget), aed(spent), aed(budget - spent)];
              }(),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'By category'),
        pw.TableHelper.fromTextArray(
          headers: ['Category', 'Spent'],
          data: [
            for (final entry in perCategory.entries) [entry.key, aed(entry.value)],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Transactions'),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'By', 'Category', 'Amount', 'Payment', 'Notes'],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          data: [
            for (final e in expenses)
              [
                _dateFmt.format(e.createdAt),
                e.userName,
                e.bucketName,
                aed(e.amount),
                e.paymentMethod.label,
                e.note,
              ],
          ],
        ),
      ],
    ));
    final file = await _tempFile('expenses_$year.pdf');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Expense report $year');
  }

  double _spent(List<Expense> expenses, String key) =>
      expenses.where((e) => e.monthKey == key).fold(0, (s, e) => s + e.amount);

  Future<File> _tempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }
}
