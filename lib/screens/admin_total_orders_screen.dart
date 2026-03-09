import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import '../utils/admin_report_pdf.dart';
import 'admin_total_orders_detail_screen.dart';

/// Admin page: Total Orders with filters by Year, Month, Day.
class AdminTotalOrdersScreen extends StatefulWidget {
  const AdminTotalOrdersScreen({Key? key}) : super(key: key);

  @override
  State<AdminTotalOrdersScreen> createState() => _AdminTotalOrdersScreenState();
}

class _AdminTotalOrdersScreenState extends State<AdminTotalOrdersScreen> {
  /// Optional status filter: null = All.
  static const List<String> _statusFilterOptions = [
    'Pending', 'Completed', 'Cancelled', 'MovedToPool', 'LateOrderPending', 'Rejected',
  ];
  final DateTime _now = DateTime.now();

  int? _selectedYear;
  int? _selectedMonth; // 1-12, null = All
  int? _selectedDay;   // 1-31, null = All
  String? _selectedStatus; // null = All
  List<Map<String, dynamic>> _lastFilteredOrders = [];
  double _lastTotalCost = 0;

  @override
  void initState() {
    super.initState();
    _selectedYear = _now.year;
    _selectedMonth = _now.month;
    _selectedDay = _now.day;
  }

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

  List<int> get _yearOptions {
    final years = <int>[];
    for (int y = _now.year; y >= _now.year - 5; y--) years.add(y);
    return years;
  }

  List<int> get _monthOptions => List.generate(12, (i) => i + 1);

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Orders'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Print / PDF',
            onPressed: () async {
              await printTotalOrdersPdf(
                reportTitle: 'Total Orders',
                orders: _lastFilteredOrders,
                totalCost: _lastTotalCost,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF ready to print or share')),
                );
              }
            },
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => AdminTotalOrdersDetailScreen(
                    selectedYear: _selectedYear,
                    selectedMonth: _selectedMonth,
                    selectedDay: _selectedDay,
                    selectedStatus: _selectedStatus,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.view_list, color: Colors.white, size: 20),
            label: const Text('Detail View', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                        d.data(), _selectedYear, _selectedMonth, _selectedDay, _selectedStatus))
                    .toList();
                // Sort by order/delivery date descending (newest first)
                filtered.sort((a, b) {
                  final da = _parseOrderDate(a.data()['orderDate']) ?? _parseOrderDate(a.data()['deliveryDate']);
                  final db = _parseOrderDate(b.data()['orderDate']) ?? _parseOrderDate(b.data()['deliveryDate']);
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return db.compareTo(da);
                });
                final totalCost = filtered.fold<double>(
                  0.0,
                  (sum, d) => sum + ((d.data()['totalPrice'] as num?)?.toDouble() ?? 0),
                );
                final orderMaps = filtered.map((d) => {'id': d.id, ...d.data()}).toList();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final lengthChanged = orderMaps.length != _lastFilteredOrders.length;
                  final costChanged = (totalCost - _lastTotalCost).abs() > 0.001;
                  if (lengthChanged || costChanged) {
                    setState(() {
                      _lastFilteredOrders = orderMaps;
                      _lastTotalCost = totalCost;
                    });
                  }
                });
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No orders for selected filter',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTotalCostLabel(filtered.length, totalCost),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final order = doc.data();
                          return _buildOrderCard(doc.id, order);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final year = _selectedYear ?? _now.year;
    final month = _selectedMonth;
    final day = _selectedDay;
    final maxDay = month != null ? _daysInMonth(year, month) : 31;
    final dayOptions = List.generate(maxDay, (i) => i + 1);

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: _inputDecoration('Year'),
                  items: _yearOptions.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) => setState(() {
                    _selectedYear = v;
                    if (_selectedDay != null && month != null && (_selectedDay! > _daysInMonth(year, month))) {
                      _selectedDay = null;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: month,
                  decoration: _inputDecoration('Month'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
                    ..._monthOptions.map((m) => DropdownMenuItem<int?>(value: m, child: Text('$m'))),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedMonth = v;
                    if (v == null) {
                      _selectedDay = null;
                    } else if (_selectedDay != null && _selectedDay! > _daysInMonth(year, v)) {
                      _selectedDay = null;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: day,
                  decoration: _inputDecoration('Day'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
                    ...dayOptions.map((d) => DropdownMenuItem<int?>(value: d, child: Text('$d'))),
                  ],
                  onChanged: (v) => setState(() => _selectedDay = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedStatus,
                  hint: const Text('All'),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ..._statusFilterOptions.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCostLabel(int orderCount, double totalCost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.teal.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$orderCount order${orderCount == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            'Total Cost: Rs.${totalCost.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildOrderCard(String docId, Map<String, dynamic> order) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${docId.length > 8 ? docId.substring(0, 8) : docId}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status'] ?? '—',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(order['status'])),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(Icons.person, 'Customer: ${order['customerName'] ?? 'N/A'}'),
            _row(Icons.inventory_2, 'Product: ${order['productName'] ?? 'N/A'}'),
            _row(Icons.store, 'Supplier: ${order['vendorName'] ?? 'N/A'}'),
            _row(Icons.calendar_today, 'Ordered: ${DateTimeUtils.formatAny(order['orderDate'])}'),
            _row(Icons.event, 'Delivery: ${DateTimeUtils.formatAny(order['deliveryDate'])}'),
            _row(Icons.restaurant, 'Meal: ${order['mealType'] ?? '—'}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${order['quantity'] ?? 0}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                Text(
                  'Rs.${(order['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.green.shade300;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
