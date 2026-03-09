import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import '../utils/app_settings.dart';
import '../utils/pool_utils.dart';
import '../utils/admin_report_pdf.dart';
import 'customer_order_detail_screen.dart';

/// Order History page: filter by All/Year/Month/Week/Day, sort by date or quantity, print.
class CustomerOrderHistoryScreen extends StatefulWidget {
  const CustomerOrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CustomerOrderHistoryScreen> createState() => _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState extends State<CustomerOrderHistoryScreen> {
  static const List<String> _dateFilterModes = ['All', 'Year', 'Month', 'Week', 'Day'];
  String _dateFilterMode = 'All';
  DateTime _selectedDate = DateTime.now();
  bool _sortByQuantity = false;

  static String _statusDisplay(String? status) {
    if (status == null || status.isEmpty) return '—';
    final s = status.toLowerCase();
    if (s == 'lateorderpending') return 'Late - Pending approval';
    if (s == 'rejected') return 'Rejected';
    if (s == 'movedtopool') return 'Moved to pool';
    if (s == 'cancelled') return 'Cancelled';
    if (s == 'completed') return 'Completed';
    return status;
  }

  static DateTime? _parseOrderDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static void _autoCompleteIfNeeded(String orderId, Map<String, dynamic> order) {
    final status = (order['status'] as String?)?.toLowerCase();
    if (status != 'pending') return;
    if (!CustomerOrderDetailScreen.isAllocationDatePast(order)) return;
    FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Completed'});
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

  Future<void> _printReport(List<Map<String, dynamic>> orders, bool showPrices) async {
    final sortLabel = _sortByQuantity ? 'Sorted by quantity' : 'Sorted by date';
    final reportTitle = 'My Orders · ${_dateRangeLabel()} · $sortLabel';
    await printMyOrdersPdf(reportTitle: reportTitle, orders: orders, showPrices: showPrices);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appSettingsStream(),
        builder: (context, settingsSnap) {
          final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? false;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('customerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              var docs = snapshot.data?.docs ?? [];
              final filtered = _filterAndSort(docs);
              final orderMaps = filtered.map((d) => Map<String, dynamic>.from(d.data())).toList();

              void doPrint() => _printReport(orderMaps, showPrices);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterSortBar(doPrint),
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final order = doc.data();
                              final orderId = doc.id;
                              final productName = order['productName'] ?? 'N/A';
                              final mealType = order['mealType'] ?? '—';
                              final status = order['status'] as String?;
                              final statusStr = _statusDisplay(status);
                              final orderDate = _parseOrderDate(order['orderDate']) ?? _parseOrderDate(order['deliveryDate']);
                              final dateStr = orderDate != null ? DateTimeUtils.formatAny(orderDate) : '—';
                              final isPending = (status ?? '').toLowerCase() == 'pending';
                              final totalPrice = (order['totalPrice'] is num) ? (order['totalPrice'] as num).toDouble() : 0.0;

                              if (isPending && CustomerOrderDetailScreen.isAllocationDatePast(order)) {
                                WidgetsBinding.instance.addPostFrameCallback((_) => _autoCompleteIfNeeded(orderId, order));
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Date: $dateStr', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                      Text('Meal type: $mealType', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                      Text(
                                        'Status: $statusStr',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: statusStr.toLowerCase().contains('pending')
                                              ? Colors.orange.shade700
                                              : statusStr == 'Rejected' || statusStr == 'Cancelled'
                                                  ? Colors.red.shade700
                                                  : statusStr == 'Completed'
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    showPrices ? 'Rs.${totalPrice.toStringAsFixed(2)}' : 'Price hidden',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => CustomerOrderDetailScreen(orderId: orderId, order: order),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
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
                                  : '${_dateRangeLabel()}',
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _dateFilterMode == 'All' ? 'No orders yet' : 'No orders in selected period',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
