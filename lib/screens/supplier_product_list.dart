import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_constants.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
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
  final ProductRepository _productRepository = ProductRepository();

  String? _selectedMealTypeFilter;
  String _statusFilter = 'All';
  List<Product> _lastProducts = [];

  bool _productMatchesMealTypeFilter(Product product) {
    if (_selectedMealTypeFilter == null) return true;
    return product.mealTypes.contains(_selectedMealTypeFilter);
  }

  bool _productMatchesStatusFilter(Product product) {
    if (_statusFilter == 'All') return true;
    if (_statusFilter == 'Available') return product.isActive;
    return !product.isActive;
  }

  List<Product> _sortActiveFirst(List<Product> list) {
    final copy = List<Product>.from(list);
    copy.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  /// Converts [Product] list to list of maps for PDF (existing util expects Map).
  List<Map<String, dynamic>> _productsToMaps(List<Product> products) {
    return products.map((p) => {'id': p.id, ...p.toMap()}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                products: _productsToMaps(_lastProducts),
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
            child: StreamBuilder<List<Product>>(
              stream: _productRepository.streamProductsByVendor(vendorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allProducts = snapshot.data ?? [];
                var supplierProducts = allProducts
                    .where(_productMatchesMealTypeFilter)
                    .where(_productMatchesStatusFilter)
                    .toList();
                supplierProducts = _sortActiveFirst(supplierProducts);
                final ids = supplierProducts.map((p) => p.id).toList();
                final prevIds = _lastProducts.map((p) => p.id).toList();
                if (ids.length != prevIds.length || !listEquals(ids, prevIds)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _lastProducts = supplierProducts);
                  });
                }
                if (allProducts.isEmpty) {
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
                    return _ProductCard(
                      product: product,
                      onTap: () async {
                        final productMap = {'id': product.id, ...product.toMap()};
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => SupplierAddEditMealScreen(product: productMap),
                          ),
                        );
                        if (updated == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Meal updated.'), backgroundColor: Colors.green),
                          );
                        }
                      },
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.image;
    final isAsset = imageUrl != null && imageUrl.startsWith('assets/');

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isAsset && imageUrl != null
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderIcon(),
                        )
                      : (imageUrl != null && imageUrl.startsWith('http'))
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderIcon(),
                            )
                          : _placeholderIcon(),
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
                            product.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.isActive ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: product.isActive ? Colors.green.shade300 : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            product.isActive ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: product.isActive ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description ?? 'No description available',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.mealTypes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: product.mealTypes
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text('ID: ${product.id}', style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
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
                            Text('Price', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Rs.${product.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: product.stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: product.stock > 0 ? Colors.green.shade300 : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 18,
                                color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock: ${product.stock}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
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
  }

  Widget _placeholderIcon() => Center(
        child: Icon(Icons.fastfood, size: 45, color: Colors.teal.shade300),
      );
}
