import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_pending_registrations.dart';

/// Returns true if [order]'s delivery/order date falls on [date] (year, month, day).
bool _orderOnDate(Map<String, dynamic> order, DateTime date) {
  final raw = order['deliveryDate'] ?? order['orderDate'];
  if (raw == null) return false;
  DateTime? dt;
  if (raw is String) dt = DateTime.tryParse(raw);
  else if (raw is Timestamp) dt = raw.toDate();
  if (dt == null) return false;
  return dt.year == date.year && dt.month == date.month && dt.day == date.day;
}

DateTime get _today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
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
                      child: Icon(Icons.admin_panel_settings, size: 35, color: Colors.teal.shade600),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${firebaseUser?.displayName ?? 'Admin'}!',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: Admin',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Cards (tappable)
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _buildStatCard(
                        context,
                        'Total Users',
                        count.toString(),
                        Icons.people,
                        Colors.teal,
                        onTap: () => _showTotalUsersDialog(context),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('registration_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _buildStatCard(
                        context,
                        'Total Pending Registration',
                        count.toString(),
                        Icons.person_add_alt_1,
                        Colors.orange,
                        onTap: () => _showPendingRegistrationDialog(context),
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
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final today = _today;
                      final count = docs.where((d) => _orderOnDate(d.data(), today)).length;
                      return _buildStatCard(
                        context,
                        'Total Orders',
                        count.toString(),
                        Icons.shopping_cart,
                        Colors.green,
                        onTap: () => _showTotalOrdersDialog(context),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final today = _today;
                      double total = 0;
                      for (final d in docs) {
                        if (!_orderOnDate(d.data(), today)) continue;
                        final price = d.data()['totalPrice'];
                        if (price is num) total += price.toDouble();
                      }
                      return _buildStatCard(
                        context,
                        'Total Cost',
                        'Rs.${total.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.teal.shade700,
                        onTap: () => _showTotalCostDialog(context),
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
                    'Order food',
                    'Browse meals and place an order',
                    Icons.restaurant_menu,
                    Colors.teal,
                    '/customer-home',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'Pending Registrations',
                    'Approve or reject new user registrations',
                    Icons.person_add,
                    Colors.orange,
                    '/admin-pending-registrations',
                    badgeStream: FirebaseFirestore.instance
                        .collection('registration_requests')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'Approved Registrations',
                    'View, activate or deactivate user accounts',
                    Icons.verified_user,
                    Colors.teal,
                    '/admin-approved-registrations',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'Admin Settings',
                    'User management, meal display and limits',
                    Icons.settings,
                    Colors.blueGrey,
                    '/admin-settings',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'View All Products',
                    'Manage all products in the system',
                    Icons.inventory_2,
                    Colors.green,
                    '/admin-products',
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context,
                    'View All Orders',
                    'Monitor all customer orders',
                    Icons.shopping_bag,
                    Colors.green,
                    '/admin-orders',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Card(
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
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }

  static void _showTotalCostDialog(BuildContext context) {
    DateTime selectedDate = _today;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Total Cost by date'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Date: '),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      final onDate = docs.where((d) => _orderOnDate(d.data(), selectedDate)).toList();
                      final Map<String, Map<String, dynamic>> byProduct = {};
                      for (final d in onDate) {
                        final data = d.data();
                        final name = data['productName'] as String? ?? 'Unknown';
                        if (!byProduct.containsKey(name)) {
                          byProduct[name] = {'quantity': 0, 'cost': 0.0};
                        }
                        final q = (data['quantity'] is int) ? (data['quantity'] as int) : (data['quantity'] as num).toInt();
                        final c = (data['totalPrice'] is num) ? (data['totalPrice'] as num).toDouble() : 0.0;
                        byProduct[name]!['quantity'] = (byProduct[name]!['quantity'] as int) + q;
                        byProduct[name]!['cost'] = (byProduct[name]!['cost'] as double) + c;
                      }
                      final entries = byProduct.entries.toList();
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No orders for this date'),
                        );
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            return ListTile(
                              title: Text(e.key),
                              subtitle: Text('Qty: ${e.value['quantity']}'),
                              trailing: Text(
                                'Rs.${(e.value['cost'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _showTotalOrdersDialog(BuildContext context) {
    DateTime selectedDate = _today;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Total Orders by date'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Date: '),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      final onDate = docs.where((d) => _orderOnDate(d.data(), selectedDate)).toList();
                      final Map<String, int> orderCountByProduct = {};
                      for (final d in onDate) {
                        final name = d.data()['productName'] as String? ?? 'Unknown';
                        orderCountByProduct[name] = (orderCountByProduct[name] ?? 0) + 1;
                      }
                      final entries = orderCountByProduct.entries.toList();
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No orders for this date'),
                        );
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            return ListTile(
                              title: Text(e.key),
                              trailing: Text(
                                '${e.value}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _showTotalUsersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          int customers = 0, vendors = 0, admins = 0;
          if (snapshot.hasData) {
            for (final d in snapshot.data!.docs) {
              final role = ((d.data()['role'] as String?) ?? 'Customer').toLowerCase();
              if (role == 'admin') admins++;
              else if (role == 'vendor') vendors++;
              else customers++;
            }
          }
          return AlertDialog(
            title: const Text('User accounts summary'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _userSummaryRow('Active Customer accounts', customers, Icons.person),
                _userSummaryRow('Active Vendor accounts', vendors, Icons.store),
                _userSummaryRow('Active Admin accounts', admins, Icons.admin_panel_settings),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _userSummaryRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.teal.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  static void _showPendingRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('registration_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          int customers = 0, vendors = 0, admins = 0;
          if (snapshot.hasData) {
            for (final d in snapshot.data!.docs) {
              final role = (d.data()['requestedRole'] as String?) ?? 'Customer';
              if (role == 'Admin') admins++;
              else if (role == 'Vendor') vendors++;
              else customers++;
            }
          }
          return AlertDialog(
            title: const Text('Pending registrations'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tap a category to see the list and approve or reject.'),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPendingListByRole(context, 'Customer');
                  },
                  child: _userSummaryRow('Customers waiting for approval', customers, Icons.person),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPendingListByRole(context, 'Vendor');
                  },
                  child: _userSummaryRow('Vendors waiting for approval', vendors, Icons.store),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPendingListByRole(context, 'Admin');
                  },
                  child: _userSummaryRow('Admins waiting for approval', admins, Icons.admin_panel_settings),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _showPendingListByRole(BuildContext context, String role) {
    final title = role == 'Customer'
        ? 'Customers waiting for approval'
        : role == 'Vendor'
            ? 'Vendors waiting for approval'
            : 'Admins waiting for approval';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('registration_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs
                  .where((d) => ((d.data()['requestedRole'] as String?) ?? 'Customer') == role)
                  .toList();
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No pending $role requests.'),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final email = data['email'] as String? ?? '—';
                    final name = data['name'] as String? ?? '—';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        child: Icon(Icons.person_add, color: Colors.teal.shade700, size: 20),
                      ),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(name),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        AdminPendingRegistrations.showApprovalDialog(context, doc.reference.id, data);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String route, {
    Stream<QuerySnapshot<Map<String, dynamic>>>? badgeStream,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: badgeStream == null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (count > 0) const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  );
                },
              ),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  // Revenue is computed from Firestore in a StreamBuilder above.
}