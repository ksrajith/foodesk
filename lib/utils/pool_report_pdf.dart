import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'admin_report_pdf.dart';

/// Prints Food Pool report (summary or detail) for the given date range and data.
Future<void> printFoodPoolPdf({
  required String startDate,
  required String endDate,
  required String rangeLabel,
  required int totalCount,
  required bool isDetailView,
  String? detailBreakdown,
  Map<String, int>? byCategory,
  Map<String, int>? byType,
  Map<String, int>? byUser,
}) async {
  final generatedAt = DateTime.now();
  final isSummary = !isDetailView;
  final reportTitle = isSummary
      ? 'Food Pool – Summary ($rangeLabel)'
      : 'Food Pool – Detail by $detailBreakdown ($rangeLabel)';

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: reportTitle, generatedAt: generatedAt);
        final rangeText = startDate == endDate
            ? 'Date: $startDate'
            : 'Range: $startDate to $endDate';
        final summaryBlock = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(rangeText, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Total count: $totalCount',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
          ],
        );
        final content = <pw.Widget>[header, summaryBlock];
        if (isDetailView && detailBreakdown != null) {
          if (detailBreakdown == 'Food category' && byCategory != null && byCategory.isNotEmpty) {
            content.add(pw.Text('By category', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 6));
            for (final e in byCategory.entries) {
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Text('${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 10)),
              ));
            }
          } else if (detailBreakdown == 'Food type' && byType != null && byType.isNotEmpty) {
            content.add(pw.Text('By type', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 6));
            for (final e in byType.entries) {
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Text('${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 10)),
              ));
            }
          } else if (detailBreakdown == 'User' && byUser != null && byUser.isNotEmpty) {
            content.add(pw.Text('By user', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 6));
            for (final e in byUser.entries) {
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Text('${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 10)),
              ));
            }
          }
        }
        return content;
      },
    ),
  );
  await Printing.layoutPdf(
    name: 'FoodDesk_FoodPool_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}
