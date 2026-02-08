import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import 'customer_order_detail_screen.dart';

/// Order History page: shows completed and pending orders, newest first.
/// Tap an order to view details. Pending orders: Cancel/Move to Pool/Complete on detail screen.
class CustomerOrderHistoryScreen extends StatelessWidget {
  const CustomerOrderHistoryScreen({Key? key}) : super(key: key);

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

  /// FR-7: If allocation/delivery date has passed and status is Pending, auto-update to Completed.
  static void _autoCompleteIfNeeded(String orderId, Map<String, dynamic> order) {
    final status = (order['status'] as String?)?.toLowerCase();
    if (status != 'pending') return;
    if (!CustomerOrderDetailScreen.isAllocationDatePast(order)) return;
    FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Completed'});
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          // Sort newest first by order date
          docs = List.from(docs)
            ..sort((a, b) {
              final da = _parseOrderDate(a.data()['orderDate']);
              final db = _parseOrderDate(b.data()['orderDate']);
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return db.compareTo(da);
            });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
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

              // FR-7: Auto-complete when allocation date has passed (fire once per build)
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
                    'Rs.${totalPrice.toStringAsFixed(2)}',
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
          );
        },
      ),
    );
  }

}
