import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import '../utils/order_utils.dart';

class AdminOrderList extends StatelessWidget {
  const AdminOrderList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders'),
        backgroundColor: Colors.green.shade600,
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
              return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${doc.id}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
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

                        // Customer Info
                        Row(
                          children: [
                            Icon(Icons.person, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Customer: ${order['customerName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Product Info
                        Row(
                          children: [
                            Icon(Icons.inventory_2, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Product: ${order['productName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Vendor Info
                        Row(
                          children: [
                            Icon(Icons.store, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Vendor: ${order['vendorName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quantity & Date
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Ordered: ${DateTimeUtils.formatAny(order['orderDate'])}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.numbers, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Qty: ${order['quantity'] ?? 0}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.event, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Delivery: ${DateTimeUtils.formatAny(order['deliveryDate'])}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.restaurant, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Meal: ${order['mealType'] ?? '—'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Total Price
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
                            Row(
                              children: [
                                const Text('Total: ', style: TextStyle(fontSize: 16)),
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
          );
        },
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