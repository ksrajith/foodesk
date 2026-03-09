import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_time_utils.dart';
import '../utils/order_utils.dart';
import '../utils/pool_utils.dart';
import '../utils/admin_report_pdf.dart';

class SupplierOrderList extends StatefulWidget {
  const SupplierOrderList({Key? key}) : super(key: key);

  @override
  State<SupplierOrderList> createState() => _SupplierOrderListState();
}

class _SupplierOrderListState extends State<SupplierOrderList> {
  static const List<String> _dateFilterModes = ['All', 'Year', 'Month', 'Week', 'Day'];
  String _dateFilterMode = 'All';
  DateTime _selectedDate = DateTime.now();
  bool _sortByQuantity = false;

  static DateTime? _parseOrderDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSort(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    MapEntry<String, String>? range;
    if (_dateFilterMode != 'All') {
      final poolMode = _dateFilterMode == 'Day'
          ? 'Daily'
          : _dateFilterMode == 'Week'
              ? 'Weekly'
              : _dateFilterMode == 'Month'
                  ? 'Monthly'
                  : 'Yearly';
      range = poolDateRangeForMode(_selectedDate, poolMode);
    }
    var list = docs.where((d) {
      if (range == null) return true;
      final orderDate = _parseOrderDate(d.data()['orderDate']) ?? _parseOrderDate(d.data()['deliveryDate']);
      if (orderDate == null) return false;
      final str = dateToDateString(orderDate);
      return str.compareTo(range.key) >= 0 && str.compareTo(range.value) <= 0;
    }).toList();

    if (_sortByQuantity) {
      list.sort((a, b) {
        final qa = (a.data()['quantity'] is int) ? a.data()['quantity'] as int : (a.data()['quantity'] as num?)?.toInt() ?? 0;
        final qb = (b.data()['quantity'] is int) ? b.data()['quantity'] as int : (b.data()['quantity'] as num?)?.toInt() ?? 0;
        if (qb != qa) return qb.compareTo(qa);
        final da = _parseOrderDate(a.data()['orderDate']);
        final db = _parseOrderDate(b.data()['orderDate']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    } else {
      list.sort((a, b) {
        final da = _parseOrderDate(a.data()['orderDate']);
        final db = _parseOrderDate(b.data()['orderDate']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    }
    return list;
  }

  String _dateRangeLabel() {
    if (_dateFilterMode == 'All') return 'All';
    if (_dateFilterMode == 'Day') return DateTimeUtils.formatAny(_selectedDate);
    if (_dateFilterMode == 'Week' || _dateFilterMode == 'Month' || _dateFilterMode == 'Year') {
      final poolMode = _dateFilterMode == 'Week' ? 'Weekly' : _dateFilterMode == 'Month' ? 'Monthly' : 'Yearly';
      final range = poolDateRangeForMode(_selectedDate, poolMode);
      return '${range.key} to ${range.value}';
    }
    return _dateFilterMode;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _printReport(List<Map<String, dynamic>> orders, double totalCost) async {
    final sortLabel = _sortByQuantity ? 'Sorted by quantity' : 'Sorted by date';
    final reportTitle = 'My Orders · ${_dateRangeLabel()} · $sortLabel';
    await printTotalOrdersPdf(reportTitle: reportTitle, orders: orders, totalCost: totalCost);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          final filtered = _filterAndSort(docs);
          final orderMaps = filtered.map((d) => Map<String, dynamic>.from(d.data())).toList();
          final totalCost = orderMaps.fold<double>(0, (sum, o) => sum + ((o['totalPrice'] as num?)?.toDouble() ?? 0));

          void doPrint() async {
            await _printReport(orderMaps, totalCost);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF ready to print or share')),
              );
            }
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orders for your products will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterSortBar(doPrint),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No orders in selected period',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final order = doc.data();
              return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.receipt_long, size: 20, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Order',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(order['status']).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                order['status'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(order['status']),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.teal.shade100,
                              child: Icon(Icons.person, size: 18, color: Colors.teal.shade700),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  order['customerName'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.green.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order['productName'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quantity: ${order['quantity'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Delivery: ${DateTimeUtils.formatAny(order['deliveryDate'])}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.restaurant, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              order['mealType'] ?? '—',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Ordered: ${DateTimeUtils.formatAny(order['orderDate'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if ((order['status'] as String?)?.toLowerCase() == 'pending')
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel this order?'),
                                      content: const Text(
                                        'Stock will be returned to the product.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: Text('Yes, cancel', style: TextStyle(color: Colors.red.shade700)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await cancelOrderAndRestoreStock(orderId: doc.id, order: order);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Order cancelled.'), backgroundColor: Colors.orange),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade700),
                                label: Text('Cancel order', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                              )
                            else
                              const SizedBox.shrink(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'Rs.${(order['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
            },
          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSortBar(VoidCallback onPrint) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
                DropdownButton<String>(
                  value: _dateFilterMode,
                  items: _dateFilterModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _dateFilterMode = v ?? 'All'),
                ),
                if (_dateFilterMode != 'All') ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dateFilterMode == 'Day'
                          ? DateTimeUtils.formatAny(_selectedDate)
                          : _dateFilterMode == 'Year'
                              ? '${_selectedDate.year}'
                              : _dateFilterMode == 'Month'
                                  ? '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}'
                                  : _dateRangeLabel(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Print',
                  onPressed: onPrint,
                ),
              ],
            ),
            Row(
              children: [
                const Text('Sort: ', style: TextStyle(fontWeight: FontWeight.w500)),
                ChoiceChip(
                  label: const Text('By date'),
                  selected: !_sortByQuantity,
                  onSelected: (v) => setState(() => _sortByQuantity = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('By quantity'),
                  selected: _sortByQuantity,
                  onSelected: (v) => setState(() => _sortByQuantity = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.green.shade300;
      case 'processing':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
