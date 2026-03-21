import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/admin_report_pdf.dart';

class SupplierOrderSummary extends StatefulWidget {
  const SupplierOrderSummary({Key? key}) : super(key: key);

  @override
  State<SupplierOrderSummary> createState() => _SupplierOrderSummaryState();
}

class _SupplierOrderSummaryState extends State<SupplierOrderSummary> {
  String selectedPeriod = 'all';
  List<Map<String, dynamic>> _lastSummaryData = [];
  String _lastPeriodLabel = 'All Time';

  static const Map<String, String> _periodLabels = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'This Week',
    'month': 'This Month',
    'all': 'All Time',
  };

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () async {
              await printOrderSummaryPdf(
                reportTitle: 'Order Summary',
                periodLabel: _lastPeriodLabel,
                summaryData: _lastSummaryData,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF ready to print or share')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Yesterday', 'yesterday'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('This Week', 'week'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('This Month', 'month'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('All Time', 'all'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No orders yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final filteredDocs = _filterOrdersByPeriod(docs);
                final summaryData = _generateSummaryData(filteredDocs);
                // Only update state when summary actually changed to avoid frequent refresh
                final newSignature = summaryData.map((r) => '${r['productName']}|${r['dateKey']}|${r['mealType']}|${r['orderCount']}|${r['totalQuantity']}|${r['totalRevenue']}').toList();
                final oldSignature = _lastSummaryData.map((r) => '${r['productName']}|${r['dateKey']}|${r['mealType']}|${r['orderCount']}|${r['totalQuantity']}|${r['totalRevenue']}').toList();
                if (newSignature.length != oldSignature.length || !listEquals(newSignature, oldSignature) || _lastPeriodLabel != (_periodLabels[selectedPeriod] ?? 'All Time')) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _lastSummaryData = summaryData;
                        _lastPeriodLabel = _periodLabels[selectedPeriod] ?? 'All Time';
                      });
                    }
                  });
                }

                if (summaryData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No orders in selected period',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: summaryData.length,
                  itemBuilder: (context, index) {
                    final entry = summaryData[index];
                    return _buildSummaryCard(entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String period) {
    final isSelected = selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedPeriod = period;
        });
      },
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterOrdersByPeriod(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (selectedPeriod == 'all') return docs;

    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        final endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        return docs.where((doc) {
          final orderDate = _parseOrderDate(doc.data()['orderDate']);
          return orderDate.isAfter(startDate) && orderDate.isBefore(endDate);
        }).toList();
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        return docs;
    }

    return docs.where((doc) {
      final orderDate = _parseOrderDate(doc.data()['orderDate']);
      return orderDate.isAfter(startDate);
    }).toList();
  }

  DateTime _parseOrderDate(dynamic orderDate) {
    if (orderDate == null) return DateTime.now();
    if (orderDate is Timestamp) return orderDate.toDate();
    if (orderDate is DateTime) return orderDate;
    if (orderDate is String) return DateTime.parse(orderDate);
    return DateTime.now();
  }

  List<Map<String, dynamic>> _generateSummaryData(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final doc in docs) {
      final data = doc.data();
      final productName = data['productName'] ?? 'Unknown Product';
      final deliveryDateRaw = data['deliveryDate'];
      final orderDate = _parseOrderDate(data['orderDate']);
      final dateForGroup = deliveryDateRaw != null
          ? _parseOrderDate(deliveryDateRaw)
          : orderDate;
      final dateKey = DateFormat('yyyy-MM-dd').format(dateForGroup);
      final mealType = data['mealType'] ?? '—';
      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;

      final key = '$productName|$dateKey|$mealType';

      if (grouped.containsKey(key)) {
        grouped[key]!['orderCount']++;
        grouped[key]!['totalQuantity'] += quantity;
        grouped[key]!['totalRevenue'] += totalPrice;
      } else {
        grouped[key] = {
          'productName': productName,
          'date': dateForGroup,
          'dateKey': dateKey,
          'mealType': mealType,
          'orderCount': 1,
          'totalQuantity': quantity,
          'totalRevenue': totalPrice,
        };
      }
    }

    final summaryList = grouped.values.toList();
    summaryList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return summaryList;
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    final productName = data['productName'] as String;
    final date = data['date'] as DateTime;
    final mealType = data['mealType'] as String? ?? '—';
    final orderCount = data['orderCount'] as int;
    final totalQuantity = data['totalQuantity'] as int;
    final totalRevenue = data['totalRevenue'] as double;

    final dateLabel = _getDateLabel(date);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.restaurant, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            mealType,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Orders',
                    orderCount.toString(),
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Quantity',
                    totalQuantity.toString(),
                    Icons.inventory_2,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Revenue',
                    'Rs.${totalRevenue.toStringAsFixed(0)}',
                    Icons.money,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today - ${DateFormat('MMM dd, yyyy').format(date)}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday - ${DateFormat('MMM dd, yyyy').format(date)}';
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    }
  }
}
