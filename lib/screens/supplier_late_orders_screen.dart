import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';

/// Lists pending late orders for the current supplier. Suppliers can Approve or Reject.
class SupplierLateOrdersScreen extends StatelessWidget {
  const SupplierLateOrdersScreen({Key? key}) : super(key: key);

  static bool _isToday(Map<String, dynamic> order) {
    final raw = order['deliveryDate'] ?? order['orderDate'];
    if (raw == null) return false;
    DateTime? dt;
    if (raw is String) dt = DateTime.tryParse(raw);
    if (raw is Timestamp) dt = (raw as Timestamp).toDate();
    if (dt == null) return false;
    final n = DateTime.now();
    return dt.year == n.year && dt.month == n.month && dt.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Late Orders'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: vendorId)
            .where('lateOrder', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data!.docs
              .where((d) {
                final data = d.data();
                return (data['status'] as String?) == 'LateOrderPending' && _isToday(data);
              })
              .toList();
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No pending late orders for today',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
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
              final data = doc.data();
              return _LateOrderCard(orderId: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _LateOrderCard extends StatelessWidget {
  const _LateOrderCard({required this.orderId, required this.data});

  final String orderId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final customerName = data['customerName'] ?? '—';
    final customerEmail = data['customerEmail'] ?? '';
    final productName = data['productName'] ?? '—';
    final quantity = data['quantity'] ?? 0;
    final mealType = data['mealType'] ?? '—';
    final totalPrice = (data['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0';
    final orderDate = data['orderDate'];
    String timeStr = '—';
    if (orderDate != null) {
      if (orderDate is String) timeStr = DateTimeUtils.formatAny(orderDate);
      else if (orderDate is Timestamp) timeStr = DateTimeUtils.formatAny(orderDate.toDate());
    }
    final customerNotes = data['customerNotes'] as String?;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Late reservation',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Customer: $customerName', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (customerEmail.isNotEmpty) Text(customerEmail, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('$productName · Qty: $quantity · $mealType'),
            Text('Rs.$totalPrice', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Ordered: $timeStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (customerNotes != null && customerNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Text(customerNotes),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Reject'),
                  onPressed: () => _rejectOrder(context, orderId, data),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve'),
                  onPressed: () => _approveOrder(context, orderId, data),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveOrder(BuildContext context, String orderId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve late order'),
        content: const Text(
          'Approve this late reservation? Stock will be decremented and the order will proceed to fulfillment. Customer will be notified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final productId = data['productId'] as String?;
      final quantity = (data['quantity'] is int) ? data['quantity'] as int : (data['quantity'] as num).toInt();
      if (productId == null || productId.isEmpty) throw Exception('Invalid order');
      final mealType = data['mealType'] as String? ?? '';
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final prodRef = FirebaseFirestore.instance.collection('products').doc(productId);
        final snap = await txn.get(prodRef);
        if (!snap.exists) throw Exception('Product not found');
        final prodData = snap.data() as Map<String, dynamic>;
        final stockByMealType = prodData['stockByMealType'];
        if (stockByMealType is Map && mealType.isNotEmpty) {
          final map = Map<String, int>.from(
            (stockByMealType as Map).map((k, v) => MapEntry(k.toString(), (v is int) ? v : (v is num ? (v as num).toInt() : 0))),
          );
          final current = map[mealType] ?? 0;
          if (current < quantity) throw Exception('Insufficient stock');
          map[mealType] = current - quantity;
          final newStock = map.values.fold<int>(0, (a, b) => a + b);
          txn.update(prodRef, {'stockByMealType': map, 'stock': newStock});
        } else {
          final stock = (prodData['stock'] is int) ? prodData['stock'] as int : (prodData['stock'] as num).toInt();
          if (stock < quantity) throw Exception('Insufficient stock');
          txn.update(prodRef, {'stock': stock - quantity});
        }
        txn.update(FirebaseFirestore.instance.collection('orders').doc(orderId), {
          'status': 'Pending',
          'vendorRespondedAt': FieldValue.serverTimestamp(),
          'vendorComment': null,
        });
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Late order approved. Customer notified.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectOrder(BuildContext context, String orderId, Map<String, dynamic> data) async {
    String? comment;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject late order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reject this late reservation? Customer will be notified.'),
              const SizedBox(height: 12),
              const Text('Reason (optional)', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Kitchen closed, out of stock',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {'comment': controller.text.trim()}),
              child: Text('Reject', style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    comment = result['comment'] as String?;
    if (comment != null && comment.isEmpty) comment = null;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'Rejected',
        'vendorRespondedAt': FieldValue.serverTimestamp(),
        'vendorComment': comment,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Late order rejected. Customer notified.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
