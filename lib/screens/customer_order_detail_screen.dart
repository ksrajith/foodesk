import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import '../utils/order_utils.dart';
import '../utils/pool_utils.dart';
import '../utils/app_settings.dart';

/// Order item detail screen. Shows Back, Move to Pool, Cancel Order, Complete.
/// Deadline-based: after deadline show Move to Pool only; before deadline show Cancel only.
/// Completed items: no Cancel/Move to Pool; can move back to Pending only if delivery date is today or future.
class CustomerOrderDetailScreen extends StatelessWidget {
  const CustomerOrderDetailScreen({
    Key? key,
    required this.orderId,
    required this.order,
  }) : super(key: key);

  final String orderId;
  final Map<String, dynamic> order;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }

  /// True if allocation/delivery date is today or in the future (date part).
  static bool isAllocationDateTodayOrFuture(Map<String, dynamic> order) {
    final d = _parseDate(order['deliveryDate']) ?? _parseDate(order['orderDate']);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allocationDate = DateTime(d.year, d.month, d.day);
    return !allocationDate.isBefore(today);
  }

  /// True if allocation/delivery date has passed (strictly before today).
  static bool isAllocationDatePast(Map<String, dynamic> order) {
    final d = _parseDate(order['deliveryDate']) ?? _parseDate(order['orderDate']);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allocationDate = DateTime(d.year, d.month, d.day);
    return allocationDate.isBefore(today);
  }

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

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] as String?) ?? 'Pending';
    final statusLower = status.toLowerCase();
    final isPending = statusLower == 'pending';
    final isCompleted = statusLower == 'completed';
    final productName = order['productName'] ?? 'N/A';
    final mealType = order['mealType'] ?? '—';
    final qty = (order['quantity'] is int) ? order['quantity'] as int : (order['quantity'] as num?)?.toInt() ?? 0;
    final totalPrice = (order['totalPrice'] is num) ? (order['totalPrice'] as num).toDouble() : 0.0;
    final pricePerUnit = qty > 0 ? totalPrice / qty : 0.0;
    final deliveryDate = _parseDate(order['deliveryDate']) ?? _parseDate(order['orderDate']);
    final deliveryStr = deliveryDate != null ? DateTimeUtils.formatAny(deliveryDate) : '—';
    final orderDate = _parseDate(order['orderDate']);
    final orderStr = orderDate != null ? DateTimeUtils.formatAny(orderDate) : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appSettingsStream(),
        builder: (context, settingsSnap) {
          final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? false;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _detailRow('Meal type', mealType),
                        _detailRow('Quantity', '$qty'),
                        _detailRow('Order date', orderStr),
                        _detailRow('Delivery / allocation date', deliveryStr),
                        _detailRow(
                          'Total',
                          showPrices ? 'Rs.${totalPrice.toStringAsFixed(2)}' : 'Price hidden',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              _statusDisplay(status),
                              style: TextStyle(
                                color: isPending
                                    ? Colors.orange.shade700
                                    : isCompleted
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            // Buttons: Back is in AppBar
            if (isPending) ...[
              FutureBuilder<bool>(
                future: isOrderPastDeadline(order),
                builder: (context, snap) {
                  final deadlinePassed = snap.data ?? false;
                  // Cancel: enabled only when deadline has NOT passed.
                  // Move to Pool: enabled only when deadline HAS passed; otherwise visible but disabled.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: deadlinePassed ? null : () => _confirmAndCancelOrder(context, orderId, order),
                          icon: Icon(
                            Icons.cancel_outlined,
                            color: deadlinePassed ? Colors.grey : Colors.red.shade700,
                          ),
                          label: Text(
                            'Cancel Order',
                            style: TextStyle(
                              color: deadlinePassed ? Colors.grey : Colors.red.shade700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: deadlinePassed ? Colors.grey : Colors.red.shade700,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.icon(
                          onPressed: deadlinePassed
                              ? () => _confirmAndMoveToPool(context, orderId, order, qty, pricePerUnit)
                              : null,
                          icon: const Icon(Icons.move_up),
                          label: const Text('Move to Pool'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _markComplete(context, orderId),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (isCompleted) ...[
              if (isAllocationDateTodayOrFuture(order))
                FilledButton.icon(
                  onPressed: () => _confirmAndMoveBackToPending(context, orderId),
                  icon: const Icon(Icons.pending_actions),
                  label: const Text('Move back to Pending'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Allocation date has passed. This order cannot be moved back to Pending.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
            ],
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmAndMoveToPool(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
    int qty,
    double pricePerUnit,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to pool?'),
        content: const Text(
          'Deadline has passed. This will move your order to the pool so others can allocate it. You cannot cancel after moving.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move to pool')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await addToPool(
        productId: order['productId'] as String? ?? '',
        productName: order['productName'] as String? ?? '',
        vendorId: order['vendorId'] as String? ?? '',
        vendorName: order['vendorName'] as String? ?? '',
        mealType: order['mealType'] as String? ?? '—',
        quantity: qty,
        pricePerUnit: pricePerUnit,
      );
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'MovedToPool'});
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order moved to pool.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndCancelOrder(BuildContext context, String orderId, Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This will cancel the order and return the quantity to available stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await cancelOrderAndRestoreStock(orderId: orderId, order: order);
      if (context.mounted) {
        Navigator.pop(context);
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
  }

  Future<void> _markComplete(BuildContext context, String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Completed'});
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as Complete.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndMoveBackToPending(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move back to Pending?'),
        content: const Text(
          'This will change the order status from Completed back to Pending. You can then Cancel or Complete it again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Pending'});
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order moved back to Pending.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
