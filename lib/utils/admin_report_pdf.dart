import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const String _appTitle = 'Food Desk';

/// Builds the standard report header: Food Desk title, report title, and date/time generated.
pw.Widget buildReportHeader({
  required String reportTitle,
  required DateTime generatedAt,
}) {
  final dateTimeStr = DateFormat('yyyy-MM-dd h.mm a').format(generatedAt);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        _appTitle,
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        reportTitle,
        style: const pw.TextStyle(fontSize: 16),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Date and time generated: $dateTimeStr',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 16),
    ],
  );
}

/// Builds PDF for Total Orders report and opens print dialog.
Future<void> printTotalOrdersPdf({
  required String reportTitle,
  required List<Map<String, dynamic>> orders,
  required double totalCost,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: reportTitle, generatedAt: generatedAt);
        final summary = pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total orders: ${orders.length}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Total Cost: Rs.${totalCost.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
        if (orders.isEmpty) {
          return [
            header,
            summary,
            pw.Text('No orders for selected filter.', style: const pw.TextStyle(fontSize: 11)),
          ];
        }
        final table = pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Customer'),
                _cell('Product'),
                _cell('Supplier'),
                _cell('Meal'),
                _cell('Status'),
                _cell('Total'),
              ],
            ),
            ...orders.map((o) {
              return pw.TableRow(
                children: [
                  _cell((o['customerName'] as String?) ?? '—'),
                  _cell((o['productName'] as String?) ?? '—'),
                  _cell((o['vendorName'] as String?) ?? '—'),
                  _cell((o['mealType'] as String?) ?? '—'),
                  _cell((o['status'] as String?) ?? '—'),
                  _cell('Rs.${((o['totalPrice'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                ],
              );
            }),
          ],
        );
        return [header, summary, table];
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'FoodDesk_TotalOrders_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}

/// Builds PDF for Vendor Order Summary and opens print dialog.
Future<void> printOrderSummaryPdf({
  required String reportTitle,
  required String periodLabel,
  required List<Map<String, dynamic>> summaryData,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: '$reportTitle · $periodLabel', generatedAt: generatedAt);
        if (summaryData.isEmpty) {
          return [header, pw.Text('No orders in selected period.', style: const pw.TextStyle(fontSize: 11))];
        }
        int totalOrders = 0;
        int totalQuantity = 0;
        double totalRevenue = 0;
        for (final row in summaryData) {
          totalOrders += (row['orderCount'] as int?) ?? 0;
          totalQuantity += (row['totalQuantity'] as int?) ?? 0;
          totalRevenue += ((row['totalRevenue'] as num?)?.toDouble()) ?? 0;
        }
        final summaryRow = pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total rows: ${summaryData.length}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Orders: $totalOrders · Qty: $totalQuantity · Revenue: Rs.${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
        final table = pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(0.7),
            4: const pw.FlexColumnWidth(0.7),
            5: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Product'),
                _cell('Date'),
                _cell('Meal type'),
                _cell('Orders'),
                _cell('Quantity'),
                _cell('Revenue'),
              ],
            ),
            ...summaryData.map((row) {
              final date = row['date'];
              final dateStr = date is DateTime ? DateFormat('yyyy-MM-dd').format(date) : (row['dateKey'] as String? ?? '—');
              return pw.TableRow(
                children: [
                  _cell((row['productName'] as String?) ?? '—'),
                  _cell(dateStr),
                  _cell((row['mealType'] as String?) ?? '—'),
                  _cell('${(row['orderCount'] as int?) ?? 0}'),
                  _cell('${(row['totalQuantity'] as int?) ?? 0}'),
                  _cell('Rs.${((row['totalRevenue'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                ],
              );
            }),
          ],
        );
        return [header, summaryRow, table];
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'FoodDesk_OrderSummary_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}

pw.Widget _cell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );
}

/// Builds PDF for Detail View report (grouped by meal type and product) and opens print dialog.
Future<void> printDetailViewPdf({
  required String reportTitle,
  required Map<String, Map<String, List<Map<String, dynamic>>>> grouped,
  required List<String> mealTypeOrder,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: reportTitle, generatedAt: generatedAt);
        final mealTypes = <String>[];
        for (final m in mealTypeOrder) {
          if (grouped.containsKey(m)) mealTypes.add(m);
        }
        for (final k in grouped.keys) {
          if (!mealTypeOrder.contains(k)) mealTypes.add(k);
        }
        final sections = <pw.Widget>[header];
        for (final mealType in mealTypes) {
          final byProduct = grouped[mealType]!;
          int sectionQty = 0;
          double sectionRevenue = 0;
          for (final list in byProduct.values) {
            for (final o in list) {
              sectionQty += (o['quantity'] is int) ? o['quantity'] as int : (o['quantity'] as num?)?.toInt() ?? 0;
              sectionRevenue += (o['totalPrice'] is num) ? (o['totalPrice'] as num).toDouble() : 0;
            }
          }
          sections.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(mealType, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('$sectionQty orders · Rs.${sectionRevenue.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  ...(byProduct.keys.toList()..sort()).map((productName) {
                    final orders = byProduct[productName]!;
                    int qty = 0;
                    double rev = 0;
                    for (final o in orders) {
                      qty += (o['quantity'] is int) ? o['quantity'] as int : (o['quantity'] as num?)?.toInt() ?? 0;
                      rev += (o['totalPrice'] is num) ? (o['totalPrice'] as num).toDouble() : 0;
                    }
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, top: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text(productName, style: const pw.TextStyle(fontSize: 10))),
                          pw.Text('${orders.length} order(s) · Qty: $qty', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Rs.${rev.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }
        return sections;
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'FoodDesk_DetailView_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}

/// Builds PDF for My Meals (supplier product list) and opens print dialog.
Future<void> printMyMealsPdf({
  required List<Map<String, dynamic>> products,
  String? mealTypeFilter,
  String? statusFilter,
}) async {
  final generatedAt = DateTime.now();
  String reportTitle = 'My Meals';
  if (mealTypeFilter != null || statusFilter != null) {
    final parts = <String>[];
    if (mealTypeFilter != null) parts.add(mealTypeFilter);
    if (statusFilter != null) parts.add(statusFilter);
    reportTitle = 'My Meals (${parts.join(', ')})';
  }
  final pdf = pw.Document();

  bool isActive(Map<String, dynamic> p) => p['active'] != false;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: reportTitle, generatedAt: generatedAt);
        if (products.isEmpty) {
          return [header, pw.Text('No meals to display.', style: const pw.TextStyle(fontSize: 11))];
        }
        final table = pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(0.8),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Meal'),
                _cell('Meal types'),
                _cell('Price'),
                _cell('Stock'),
                _cell('Status'),
              ],
            ),
            ...products.map((p) {
              final name = (p['name'] as String?) ?? '—';
              final types = p['mealTypes'];
              final typesStr = types is List ? (types as List).whereType<String>().join(', ') : '—';
              final price = (p['price'] is num) ? (p['price'] as num).toDouble() : 0.0;
              final stock = (p['stock'] is int) ? p['stock'] as int : (p['stock'] is num ? (p['stock'] as num).toInt() : 0);
              final status = isActive(p) ? 'Available' : 'Unavailable';
              return pw.TableRow(
                children: [
                  _cell(name),
                  _cell(typesStr),
                  _cell('Rs.${price.toStringAsFixed(2)}'),
                  _cell('$stock'),
                  _cell(status),
                ],
              );
            }),
          ],
        );
        return [header, pw.SizedBox(height: 8), pw.Text('${products.length} meal(s)', style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 8), table];
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'FoodDesk_MyMeals_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}

/// Builds PDF for My Orders (customer order history) and opens print dialog.
Future<void> printMyOrdersPdf({
  required String reportTitle,
  required List<Map<String, dynamic>> orders,
  required bool showPrices,
}) async {
  final generatedAt = DateTime.now();
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        final header = buildReportHeader(reportTitle: reportTitle, generatedAt: generatedAt);
        if (orders.isEmpty) {
          return [header, pw.Text('No orders for selected filter.', style: const pw.TextStyle(fontSize: 11))];
        }
        final table = pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(0.6),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Product'),
                _cell('Meal type'),
                _cell('Date'),
                _cell('Qty'),
                _cell(showPrices ? 'Total' : '—'),
                _cell('Status'),
              ],
            ),
            ...orders.map((o) {
              final productName = (o['productName'] as String?) ?? '—';
              final mealType = (o['mealType'] as String?) ?? '—';
              final dateRaw = o['orderDate'] ?? o['deliveryDate'];
              String dateStr = '—';
              if (dateRaw != null) {
                if (dateRaw is DateTime) dateStr = DateFormat('yyyy-MM-dd').format(dateRaw);
                else if (dateRaw is Timestamp) dateStr = DateFormat('yyyy-MM-dd').format(dateRaw.toDate());
                else if (dateRaw is String) dateStr = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
              }
              final qty = (o['quantity'] is int) ? o['quantity'] as int : (o['quantity'] as num?)?.toInt() ?? 0;
              final total = (o['totalPrice'] is num) ? (o['totalPrice'] as num).toDouble() : 0.0;
              final status = (o['status'] as String?) ?? '—';
              return pw.TableRow(
                children: [
                  _cell(productName),
                  _cell(mealType),
                  _cell(dateStr),
                  _cell('$qty'),
                  _cell(showPrices ? 'Rs.${total.toStringAsFixed(2)}' : '—'),
                  _cell(status),
                ],
              );
            }),
          ],
        );
        return [header, pw.Text('${orders.length} order(s)', style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 8), table];
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'FoodDesk_MyOrders_${DateFormat('yyyyMMdd_Hm').format(generatedAt)}',
    onLayout: (_) async => pdf.save(),
  );
}
