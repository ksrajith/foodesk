import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_settings.dart';
import '../utils/pool_utils.dart';

/// Shows today's pool items. Users can allocate (claim) food from the pool.
class PoolScreen extends StatelessWidget {
  const PoolScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = todayDate;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool for today'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: appSettingsStream(),
        builder: (context, settingsSnap) {
          final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? true;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: poolStreamForDate(date),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          final withQty = docs.where((d) {
            final q = d.data()['quantity'];
            final n = q is int ? q : (q is num ? q.toInt() : 0);
            return n > 0;
          }).toList();
          if (withQty.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No items in the pool for today',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pool resets at midnight.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: withQty.length,
            itemBuilder: (context, index) {
              final doc = withQty[index];
              final data = doc.data();
              final id = doc.id;
              final qty = (data['quantity'] is int)
                  ? (data['quantity'] as int)
                  : (data['quantity'] as num).toInt();
              final productName = data['productName'] ?? 'N/A';
              final mealType = data['mealType'] ?? '—';
              final vendorName = data['vendorName'] ?? '';
              final pricePerUnit = (data['pricePerUnit'] is num) ? (data['pricePerUnit'] as num).toDouble() : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(productName),
                  subtitle: Text('$mealType · $vendorName · Qty: $qty'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showPrices && pricePerUnit > 0)
                        Text(
                          'Rs.${pricePerUnit.toStringAsFixed(2)}/unit',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: qty > 0
                            ? () => _showAllocateDialog(
                                  context,
                                  poolDocId: id,
                                  poolData: data,
                                  maxQty: qty,
                                )
                            : null,
                        child: const Text('Allocate'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
        },
      ),
    );
  }

  void _showAllocateDialog(
    BuildContext context, {
    required String poolDocId,
    required Map<String, dynamic> poolData,
    required int maxQty,
  }) {
    int selected = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Allocate from pool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${poolData['productName'] ?? 'Item'} · max $maxQty'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Quantity: '),
                  DropdownButton<int>(
                    value: selected.clamp(1, maxQty),
                    items: List.generate(maxQty, (i) => i + 1)
                        .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) => setState(() => selected = v ?? 1),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = selected.clamp(1, maxQty);
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please sign in again.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }
                try {
                  await allocateFromPool(
                    poolDocId: poolDocId,
                    poolData: poolData,
                    quantity: qty,
                    customerId: user.uid,
                    customerName: user.displayName ?? 'Customer',
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Allocated from pool.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Allocate'),
            ),
          ],
        ),
      ),
    );
  }
}
