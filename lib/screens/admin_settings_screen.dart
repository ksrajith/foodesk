import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_approved_registrations_screen.dart';
import '../utils/app_settings.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'User Management', icon: Icon(Icons.people)),
            Tab(text: 'Meal Display', icon: Icon(Icons.visibility)),
            Tab(text: 'Meal Limits', icon: Icon(Icons.restaurant)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserManagementTab(),
          _MealDisplaySettingsTab(),
          _MealLimitConfigTab(),
        ],
      ),
    );
  }
}

class _UserManagementTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.teal),
            title: const Text('Approved Registrations'),
            subtitle: const Text('View, activate or deactivate user accounts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const AdminApprovedRegistrationsScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealDisplaySettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const docId = 'settings';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('app_settings').doc(docId).snapshots(),
      builder: (context, snapshot) {
        final showPrices = snapshot.hasData &&
            snapshot.data!.exists &&
            snapshot.data!.data() != null &&
            (snapshot.data!.data()!['showMealPricesToCustomers'] as bool? ?? false);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal Display Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Show meal prices to customers',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                        ),
                      ),
                      Switch(
                        value: showPrices,
                        onChanged: (value) async {
                          try {
                            await FirebaseFirestore.instance.collection('app_settings').doc(docId).set(
                              {
                                'showMealPricesToCustomers': value,
                                'updatedAt': FieldValue.serverTimestamp(),
                                'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                              },
                              SetOptions(merge: true),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value ? 'Prices are now visible to customers.' : 'Prices are now hidden.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        activeColor: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showPrices ? 'Customers see prices on menus and order pages.' : 'Customers see "Price hidden" instead of amounts.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MealLimitConfigTab extends StatefulWidget {
  @override
  State<_MealLimitConfigTab> createState() => _MealLimitConfigTabState();
}

class _MealLimitConfigTabState extends State<_MealLimitConfigTab> {
  static const List<String> mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final t in mealTypes) _controllers[t] = TextEditingController(text: '2');
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final settings = await getAppSettings();
    final limits = settings['mealLimits'] as Map<String, int>? ?? {};
    for (final t in mealTypes) {
      _controllers[t]!.text = (limits[t] ?? 2).toString();
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveLimits() async {
    final limits = <String, int>{};
    for (final t in mealTypes) {
      final v = int.tryParse(_controllers[t]!.text);
      if (v == null || v < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$t: enter a valid number ≥ 0'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      limits[t] = v;
    }
    try {
      await FirebaseFirestore.instance.collection('app_settings').doc('settings').set(
        {
          'mealLimits': limits,
          'mealLimitsUpdatedAt': FieldValue.serverTimestamp(),
          'mealLimitsUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal limits saved.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximum meals per customer per day',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Set the maximum quantity per meal type that a customer can order for a single day.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ...mealTypes.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 100, child: Text(t)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _controllers[t],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('per day'),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLimits,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save limits'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
