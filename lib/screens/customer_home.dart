import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_time_utils.dart';
import '../utils/order_utils.dart';
import '../utils/pool_utils.dart';
import 'place_meal_screen.dart';
import 'pool_screen.dart';
// AppData removed: use FirebaseAuth/Firestore for user data

class CustomerHome extends StatefulWidget {
  const CustomerHome({Key? key}) : super(key: key);

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showMyOrders(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // ignore: use_build_context_synchronously
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _buildHomeTiles(context),
    );
  }

  Widget _buildHomeTiles(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.teal.shade400],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${user?.displayName ?? 'Customer'}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an option below',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showMyOrders(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 56,
                              color: Colors.teal.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Order History',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'View your past and current orders',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const PlaceMealScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_shopping_cart,
                              size: 56,
                              color: Colors.teal.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Place Order',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse products and place a new order',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const PoolScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 56,
                              color: Colors.teal.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Pool for today',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'View or allocate food from today\'s pool',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMyOrders(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Orders'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('customerId', isEqualTo: firebaseUser?.uid ?? '')
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
                return const Center(child: Text('No orders yet'));
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final order = doc.data();
                  final orderId = doc.id;
                  final status = (order['status'] as String?)?.toLowerCase();
                  final isPending = status == 'pending';
                  final statusDisplay = status == 'lateorderpending'
                      ? 'Late - Pending approval'
                      : status == 'rejected'
                          ? 'Rejected'
                          : (order['status'] as String? ?? '—');
                  final mealType = order['mealType'] ?? '—';
                  final deliveryStr = DateTimeUtils.formatAny(order['deliveryDate']);
                  final qty = (order['quantity'] is int)
                      ? (order['quantity'] as int)
                      : (order['quantity'] is num)
                          ? (order['quantity'] as num).toInt()
                          : 0;
                  final totalPrice = (order['totalPrice'] is num) ? (order['totalPrice'] as num).toDouble() : 0.0;
                  final pricePerUnit = qty > 0 ? totalPrice / qty : 0.0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(order['productName'] ?? 'N/A'),
                      subtitle: Text(
                        'Qty: ${order['quantity']} · $mealType · $deliveryStr · $statusDisplay',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending)
                            FutureBuilder<bool>(
                              future: isOrderPastDeadline(order),
                              builder: (context, deadlineSnap) {
                                final pastDeadline = deadlineSnap.data ?? false;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pastDeadline)
                                      TextButton(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Move to pool?'),
                                              content: const Text(
                                                'Deadline has passed. This will move your order to the pool so others can allocate it. You cannot cancel after moving.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('No'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Move to pool'),
                                                ),
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
                                        },
                                        child: const Text('Move to pool', style: TextStyle(fontSize: 12)),
                                      )
                                    else
                                      TextButton(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Cancel order?'),
                                              content: const Text(
                                                'This will cancel the order and return the quantity to available stock.',
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
                                        },
                                        child: Text('Cancel', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                                      ),
                                    const SizedBox(width: 8),
                                  ],
                                );
                              },
                            ),
                          Text(
                            'Rs.${(order['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
