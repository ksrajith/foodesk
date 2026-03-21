import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_report_pdf.dart';
import 'registration_stats.dart' show kRegistrationRoleLabels;

/// Summary matrix: role -> pending, approved, rejected counts.
Future<void> printRegistrationSummaryPdf({
  required int totalUsers,
  required Map<String, int> usersByRole,
  required Map<String, int> pendingByRole,
  required Map<String, int> approvedByRole,
  required Map<String, int> rejectedByRole,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();
  final df = DateFormat('yyyy-MM-dd h:mm a');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) {
        return [
          buildReportHeader(reportTitle: 'Registration history summary', generatedAt: generatedAt),
          pw.Text('Total users in system: $totalUsers', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Users by role', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ...kRegistrationRoleLabels.map(
            (r) => pw.Text('$r: ${usersByRole[r] ?? 0}', style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Registration requests by role', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfCell('Role', bold: true),
                  _pdfCell('Pending', bold: true),
                  _pdfCell('Approved', bold: true),
                  _pdfCell('Rejected', bold: true),
                ],
              ),
              for (final r in kRegistrationRoleLabels)
                pw.TableRow(
                  children: [
                    _pdfCell(r),
                    _pdfCell('${pendingByRole[r] ?? 0}'),
                    _pdfCell('${approvedByRole[r] ?? 0}'),
                    _pdfCell('${rejectedByRole[r] ?? 0}'),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Total', bold: true),
                  _pdfCell('${pendingByRole.values.fold<int>(0, (a, b) => a + b)}', bold: true),
                  _pdfCell('${approvedByRole.values.fold<int>(0, (a, b) => a + b)}', bold: true),
                  _pdfCell('${rejectedByRole.values.fold<int>(0, (a, b) => a + b)}', bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Printed: ${df.format(generatedAt)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

pw.Widget _pdfCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );
}

Future<void> printRegistrationDetailsPdf({
  required String title,
  required List<Map<String, String>> rows,
  required String filterSummary,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();
  final df = DateFormat('yyyy-MM-dd h:mm a');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) {
        return [
          buildReportHeader(reportTitle: title, generatedAt: generatedAt),
          pw.Text(filterSummary, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('No records match the current filters.', style: const pw.TextStyle(fontSize: 11))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(0.9),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(0.9),
                5: const pw.FlexColumnWidth(1.1),
                6: const pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfCell('Name', bold: true),
                    _pdfCell('Email', bold: true),
                    _pdfCell('Role', bold: true),
                    _pdfCell('Status', bold: true),
                    _pdfCell('Date', bold: true),
                    _pdfCell('By', bold: true),
                    _pdfCell('Comment', bold: true),
                  ],
                ),
                for (final r in rows)
                  pw.TableRow(
                    children: [
                      _pdfCell(r['name'] ?? ''),
                      _pdfCell(r['email'] ?? ''),
                      _pdfCell(r['role'] ?? ''),
                      _pdfCell(r['status'] ?? ''),
                      _pdfCell(r['date'] ?? ''),
                      _pdfCell(r['by'] ?? ''),
                      _pdfCell(r['comment'] ?? ''),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 12),
          pw.Text('Rows: ${rows.length} · Printed: ${df.format(generatedAt)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
