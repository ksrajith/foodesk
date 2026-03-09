import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/admin_report_pdf.dart';
import 'supplier_add_edit_meal_screen.dart';

const List<String> _mealTypeFilterOptions = ['Breakfast', 'Lunch', 'Dinner'];
const List<String> _statusFilterOptions = ['All', 'Available', 'Unavailable'];

class SupplierProductList extends StatefulWidget {
  const SupplierProductList({Key? key}) : super(key: key);

  @override
  State<SupplierProductList> createState() => _SupplierProductListState();
}

class _SupplierProductListState extends State<SupplierProductList> {
  /// Optional filter: null = All, else filter by this meal type.
  String? _selectedMealTypeFilter;
  /// Status filter: All, Available (active), Unavailable (inactive). Default All.
  String _statusFilter = 'All';
  List<Map<String, dynamic>> _lastProducts = [];

  bool _isActive(Map<String, dynamic> product) => product['active'] != false;

  bool _productMatchesMealTypeFilter(Map<String, dynamic> product) {
    if (_selectedMealTypeFilter == null) return true;
    final types = product['mealTypes'];
    if (types == null || types is! List) return false;
    return (types as List).contains(_selectedMealTypeFilter);
  }

  bool _productMatchesStatusFilter(Map<String, dynamic> product) {
    if (_statusFilter == 'All') return true;
    if (_statusFilter == 'Available') return _isActive(product);
    return !_isActive(product);
  }

  /// Sort: active first, then inactive (inactive at bottom).
  List<Map<String, dynamic>> _sortActiveFirst(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) {
      final aa = _isActive(a);
      final bb = _isActive(b);
      if (aa != bb) return aa ? -1 : 1;
      return ((a['name'] ?? '') as String).compareTo((b['name'] ?? '') as String);
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Menu'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () async {
              await printMyMealsPdf(
                products: _lastProducts,
                mealTypeFilter: _selectedMealTypeFilter,
                statusFilter: _statusFilter == 'All' ? null : _statusFilter,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF ready to print or share')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SupplierAddEditMealScreen()),
          );
          if (added == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Meal added.'), backgroundColor: Colors.green),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
        backgroundColor: Colors.teal.shade600,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMealTypeFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('vendorId', isEqualTo: firebaseUser?.uid ?? '')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                final allProducts = docs.map((d) => {'id': d.id, ...d.data()}).toList();
                var supplierProducts = allProducts
                    .where(_productMatchesMealTypeFilter)
                    .where(_productMatchesStatusFilter)
                    .toList();
                supplierProducts = _sortActiveFirst(supplierProducts);
                // Only update state when the list actually changed to avoid frequent refresh
                final ids = supplierProducts.map((p) => p['id'] as String?).toList();
                final prevIds = _lastProducts.map((p) => p['id'] as String?).toList();
                if (ids.length != prevIds.length || !listEquals(ids, prevIds)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _lastProducts = supplierProducts);
                  });
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey.shade300),
                        const SizedBox(height: 24),
                        Text('No products yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Start adding products to your store', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        const SizedBox(height: 24),
                        Icon(Icons.add_circle_outline, size: 48, color: Colors.grey.shade400),
                      ],
                    ),
                  );
                }
                if (supplierProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No meals match the selected filter',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text('Try a different meal type or clear the filter', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: supplierProducts.length,
            itemBuilder: (context, index) {
              final product = supplierProducts[index];
              return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SupplierAddEditMealScreen(product: product),
                        ),
                      );
                      if (updated == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meal updated.'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.shade200,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: product['image'] != null && product['image'].toString().startsWith('assets/')
                                ? Image.asset(
                                    product['image'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.fastfood,
                                          size: 45,
                                          color: Colors.teal.shade300,
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      product['image'] ?? '📦',
                                      style: const TextStyle(fontSize: 45),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product['name'] ?? 'Unknown Product',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isActive(product) ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isActive(product) ? Colors.green.shade300 : Colors.orange.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      _isActive(product) ? 'Available' : 'Unavailable',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _isActive(product) ? Colors.green.shade700 : Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                product['description'] ?? 'No description available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (product['mealTypes'] is List && (product['mealTypes'] as List).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: (product['mealTypes'] as List)
                                      .whereType<String>()
                                      .map((t) => Chip(
                                            label: Text(t, style: const TextStyle(fontSize: 11)),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ))
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tag,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ID: ${product['id'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rs.${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (product['stock'] ?? 0) > 0
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: (product['stock'] ?? 0) > 0
                                            ? Colors.green.shade300
                                            : Colors.red.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inventory_2,
                                          size: 18,
                                          color: (product['stock'] ?? 0) > 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Stock: ${product['stock'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: (product['stock'] ?? 0) > 0
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                );
            },
          );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Meal type:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedMealTypeFilter,
                  hint: const Text('All'),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ..._mealTypeFilterOptions.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                  ],
                  onChanged: (v) => setState(() => _selectedMealTypeFilter = v),
                ),
              ),
              const SizedBox(width: 24),
              Text('Status:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                isDense: true,
                items: _statusFilterOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
