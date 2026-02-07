import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// AppData removed: use FirebaseAuth/Firestore for current user data

class VendorDashboard extends StatelessWidget {
  const VendorDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
  final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AppData.logout();
              // ignore: use_build_context_synchronously
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(Icons.store, size: 35, color: Colors.teal.shade600),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${firebaseUser?.displayName ?? 'Vendor'}!',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: Vendor',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
            .collection('products')
            .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
            .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _buildStatCard(
                        'My Products',
                        count.toString(),
                        Icons.inventory,
                        Colors.teal,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
            .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _buildStatCard(
                        'My Orders',
                        count.toString(),
                        Icons.shopping_bag,
                        Colors.green,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
            .collection('products')
            .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
            .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      int totalStock = 0;
                      for (final d in docs) {
                        final stock = d.data()['stock'];
                        if (stock is num) totalStock += stock.toInt();
                      }
                      return _buildStatCard(
                        'Total Stock',
                        totalStock.toString(),
                        Icons.warehouse,
                        Colors.green,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
            .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      double revenue = 0;
                      for (final d in docs) {
                        final price = d.data()['totalPrice'];
                        if (price is num) revenue += price.toDouble();
                      }
                      return _buildStatCard(
                        'Revenue',
                        'Rs.${revenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.teal.shade700,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Navigation Options
            const Text(
              'Quick Access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuTile(
                    context,
                    'My Products',
                    'View and manage your products',
                    Icons.inventory_2,
                    Colors.teal,
                    '/vendor-products',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'Order Before',
                    'Set cut-off time for each meal type (24h)',
                    Icons.schedule,
                    Colors.orange,
                    '/vendor-order-before',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'My Orders',
                    'View orders for your products',
                    Icons.shopping_bag,
                    Colors.green,
                    '/vendor-orders',
                  ),
                  const SizedBox(height: 12),
                  _buildLateOrdersTile(context, firebaseUser?.uid ?? ''),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'Order Summary',
                    'Product-wise order analytics',
                    Icons.analytics,
                    Colors.blue,
                    '/vendor-order-summary',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, String subtitle, IconData icon, Color color, String route) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  Widget _buildLateOrdersTile(BuildContext context, String vendorId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('lateOrder', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          for (final d in snapshot.data!.docs) {
            final data = d.data();
            if ((data['status'] as String?) != 'LateOrderPending') continue;
            final raw = data['deliveryDate'] ?? data['orderDate'];
            if (raw == null) continue;
            DateTime? dt;
            if (raw is String) dt = DateTime.tryParse(raw);
            if (raw is Timestamp) dt = (raw as Timestamp).toDate();
            if (dt != null && !dt.isBefore(todayStart) && dt.isBefore(todayEnd)) count++;
          }
        }
        return Card(
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child: Icon(Icons.schedule, color: Colors.orange.shade700),
            ),
            title: const Text('Late Orders', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(count == 0 ? 'No pending late orders for today' : '$count pending for today'),
            trailing: count > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/vendor-late-orders'),
          ),
        );
      },
    );
  }

  // Stock and revenue are computed from Firestore via StreamBuilders above.
}