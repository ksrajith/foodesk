import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_report_pdf.dart';

/// Detail view of Total Orders: grouped by Meal Type (Breakfast, Lunch, Dinner) and by food/product category.
class AdminTotalOrdersDetailScreen extends StatelessWidget {
  const AdminTotalOrdersDetailScreen({
    Key? key,
    required this.selectedYear,
    this.selectedMonth,
    this.selectedDay,
    this.selectedStatus,
  }) : super(key: key);

  final int? selectedYear;
  final int? selectedMonth;
  final int? selectedDay;
  final String? selectedStatus;

  static DateTime? _parseOrderDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  static bool _orderMatchesFilter(
    Map<String, dynamic> order,
    int? year,
    int? month,
    int? day,
    String? status,
  ) {
    final dt = _parseOrderDate(order['deliveryDate']) ?? _parseOrderDate(order['orderDate']);
    if (dt == null) return false;
    if (year != null && dt.year != year) return false;
    if (month != null && dt.month != month) return false;
    if (day != null && dt.day != day) return false;
    if (status != null && (order['status'] as String? ?? '').toLowerCase() != status.toLowerCase()) {
      return false;
    }
    return true;
  }

  static const List<String> _mealTypeOrder = ['Breakfast', 'Lunch', 'Dinner'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail View'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          final filtered = docs
              .where((d) => _orderMatchesFilter(
                  d.data(), selectedYear, selectedMonth, selectedDay, selectedStatus))
              .toList();

          // Group by meal type, then by product name (food category)
          // Map<mealType, Map<productName, List<order data>>>
          final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
          for (final doc in filtered) {
            final order = doc.data();
            final mealType = (order['mealType'] as String?)?.trim().isNotEmpty == true
                ? (order['mealType'] as String)
                : 'Other';
            final productName = (order['productName'] as String?)?.trim().isNotEmpty == true
                ? (order['productName'] as String)
                : 'Unknown';
            grouped.putIfAbsent(mealType, () => {});
            grouped[mealType]!.putIfAbsent(productName, () => []);
            grouped[mealType]![productName]!.add(order);
          }

          if (grouped.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No orders for selected filter',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final mealTypes = <String>[];
          for (final m in _mealTypeOrder) {
            if (grouped.containsKey(m)) mealTypes.add(m);
          }
          for (final k in grouped.keys) {
            if (!_mealTypeOrder.contains(k)) mealTypes.add(k);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPrintButton(context, grouped, mealTypes),
              const SizedBox(height: 12),
              _buildFilterSummary(),
              const SizedBox(height: 16),
              ...mealTypes.map((mealType) => _buildMealTypeSection(mealType, grouped[mealType]!)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrintButton(
    BuildContext context,
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped,
    List<String> mealTypes,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: () async {
          await printDetailViewPdf(
            reportTitle: 'Detail View',
            grouped: grouped,
            mealTypeOrder: _mealTypeOrder,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF ready to print or share')),
            );
          }
        },
        icon: const Icon(Icons.print, size: 20),
        label: const Text('Print'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterSummary() {
    final parts = <String>[];
    if (selectedYear != null) parts.add('$selectedYear');
    if (selectedMonth != null) parts.add(selectedMonth! < 10 ? '0$selectedMonth' : '$selectedMonth');
    if (selectedDay != null) parts.add(selectedDay! < 10 ? '0$selectedDay' : '$selectedDay');
    if (parts.isEmpty) parts.add('All dates');
    String label = parts.join('-');
    if (selectedStatus != null) label += ' · $selectedStatus';
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.filter_list, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Text('Filter: $label', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal.shade900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSection(String mealType, Map<String, List<Map<String, dynamic>>> byProduct) {
    final productNames = byProduct.keys.toList()..sort();
    int totalQty = 0;
    double totalRevenue = 0;
    for (final list in byProduct.values) {
      for (final o in list) {
        totalQty += (o['quantity'] is int) ? o['quantity'] as int : (o['quantity'] as num?)?.toInt() ?? 0;
        totalRevenue += (o['totalPrice'] is num) ? (o['totalPrice'] as num).toDouble() : 0;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _mealTypeColor(mealType).withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_mealTypeIcon(mealType), color: _mealTypeColor(mealType), size: 24),
                const SizedBox(width: 10),
                Text(
                  mealType,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _mealTypeColor(mealType)),
                ),
                const Spacer(),
                Text(
                  '$totalQty orders · Rs.${totalRevenue.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ...productNames.map((productName) {
            final orders = byProduct[productName]!;
            int qty = 0;
            double rev = 0;
            for (final o in orders) {
              qty += (o['quantity'] is int) ? o['quantity'] as int : (o['quantity'] as num?)?.toInt() ?? 0;
              rev += (o['totalPrice'] is num) ? (o['totalPrice'] as num).toDouble() : 0;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${orders.length} order${orders.length == 1 ? '' : 's'} · Qty: $qty',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs.${rev.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _mealTypeColor(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Colors.orange;
      case 'Lunch':
        return Colors.blue;
      case 'Dinner':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _mealTypeIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.free_breakfast;
      case 'Lunch':
        return Icons.lunch_dining;
      case 'Dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }
}
