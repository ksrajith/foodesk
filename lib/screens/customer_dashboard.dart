import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/date_time_utils.dart';
import '../utils/fcm_utils.dart';
import '../utils/order_utils.dart';
import '../utils/pool_utils.dart';
import '../utils/app_settings.dart';
import 'place_meal_screen.dart';
import 'pool_screen.dart';
// AppData removed: use FirebaseAuth/Firestore for user data

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  @override
  void initState() {
    super.initState();
    refreshFcmTokenAndSave();
    Future<void>.delayed(const Duration(seconds: 3), () => refreshFcmTokenAndSave());
    Future<void>.delayed(const Duration(seconds: 8), () => refreshFcmTokenAndSave());
  }

  Future<void> _sendTestNotification() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      // Save this device's token first so the server sends to this phone (not another device)
      await refreshFcmTokenAndSave();
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Token updated. Sending test… (may take 1–2 min if server is cold). Stay on this screen or put app in background.'),
          duration: Duration(seconds: 5),
        ),
      );
      final callable = FirebaseFunctions.instance.httpsCallable('sendTestNotification');
      await callable.call();
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text('Test notification sent. Check your device (or the banner above if app was open).')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Notification test failed.')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test notification',
            onPressed: _sendTestNotification,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/customer-order-history'),
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appSettingsStream(),
        builder: (context, settingsSnap) {
          final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? false;
          return _buildHomeTiles(context, showPrices);
        },
      ),
    );
  }

  Widget _buildHomeTiles(BuildContext context, bool showPrices) {
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
                    onTap: () => Navigator.pushNamed(context, '/customer-order-history'),
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
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: poolStreamForDate(todayDate),
                    builder: (context, poolSnap) {
                      int poolCount = 0;
                      if (poolSnap.hasData && poolSnap.data != null) {
                        poolCount = poolSnap.data!.docs
                            .where((d) {
                              final q = d.data()['quantity'];
                              final n = q is int ? q : (q is num ? q.toInt() : 0);
                              return n > 0;
                            })
                            .length;
                      }
                      return InkWell(
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
                                  'Food Pool',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  poolCount == 0
                                      ? 'No items · View or allocate from today\'s pool'
                                      : '$poolCount item${poolCount == 1 ? '' : 's'} in pool',
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMyOrders(BuildContext context, bool showPrices) {
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
                            showPrices
                                ? 'Rs.${(order['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}'
                                : 'Price hidden',
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
