import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Meal types that can be selected (one or more per meal).
const List<String> kMealTypeOptions = ['Breakfast', 'Lunch', 'Dinner'];

class SupplierAddEditMealScreen extends StatefulWidget {
  const SupplierAddEditMealScreen({Key? key, this.product}) : super(key: key);
  /// If non-null, we are editing this product; otherwise adding new.
  final Map<String, dynamic>? product;

  @override
  State<SupplierAddEditMealScreen> createState() => _SupplierAddEditMealScreenState();
}

class _SupplierAddEditMealScreenState extends State<SupplierAddEditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageController = TextEditingController();

  final Set<String> _selectedMealTypes = {};
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = (p['name'] ?? '') as String;
      _descriptionController.text = (p['description'] ?? '') as String;
      _priceController.text = (p['price'] != null)
          ? (p['price'] is int ? (p['price'] as int).toString() : (p['price'] as num).toStringAsFixed(2))
          : '';
      _stockController.text = (p['stock'] != null) ? (p['stock'] is int ? (p['stock'] as int).toString() : (p['stock'] as num).truncate().toString()) : '0';
      _imageController.text = (p['image'] ?? '') as String;
      final types = p['mealTypes'];
      if (types is List) {
        for (final t in types) {
          if (t is String && kMealTypeOptions.contains(t)) {
            _selectedMealTypes.add(t);
          }
        }
      }
      if (_selectedMealTypes.isEmpty) {
        _selectedMealTypes.addAll(kMealTypeOptions);
      }
    } else {
      _stockController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMealTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one meal type (Breakfast, Lunch, or Dinner).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal name is required.'), backgroundColor: Colors.orange),
      );
      return;
    }

    double? price;
    try {
      price = double.parse(_priceController.text.trim().replaceFirst(',', '.'));
    } catch (_) {}
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price.'), backgroundColor: Colors.orange),
      );
      return;
    }

    int stock = 0;
    try {
      stock = int.parse(_stockController.text.trim());
    } catch (_) {}
    if (stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Available qty must be 0 or more.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in.'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
        return;
      }

      final data = <String, dynamic>{
        'name': name,
        'description': _descriptionController.text.trim(),
        'price': price,
        'mealTypes': _selectedMealTypes.toList(),
        'vendorId': user.uid,
        'vendorName': user.email ?? user.displayName ?? 'Supplier',
        'stock': stock,
      };
      final imagePath = _imageController.text.trim();
      if (imagePath.isNotEmpty) data['image'] = imagePath;

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!['id'] as String)
            .update(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal updated.'), backgroundColor: Colors.green),
        );
      } else {
        final ref = FirebaseFirestore.instance.collection('products').doc();
        data['id'] = ref.id;
        await ref.set(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal added.'), backgroundColor: Colors.green),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Meal' : 'Add Meal'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Meal name *',
                hintText: 'e.g. Rice and curry chicken',
                prefixIcon: const Icon(Icons.restaurant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Meal name is required';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Meal type *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            ...kMealTypeOptions.map((type) => CheckboxListTile(
                  value: _selectedMealTypes.contains(type),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedMealTypes.add(type);
                      } else {
                        _selectedMealTypes.remove(type);
                      }
                    });
                  },
                  title: Text(type),
                  activeColor: Colors.teal,
                )),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price (Rs.) *',
                hintText: 'e.g. 450',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Price is required';
                final n = double.tryParse(v.trim().replaceFirst(',', '.'));
                if (n == null || n < 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Available qty',
                hintText: 'e.g. 20',
                prefixIcon: const Icon(Icons.inventory_2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter 0 or more';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Short description of the meal',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _imageController,
              decoration: InputDecoration(
                labelText: 'Meal photo (optional)',
                hintText: 'Asset path e.g. assets/ProductImages/meal.png or image URL',
                prefixIcon: const Icon(Icons.photo),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Update Meal' : 'Add Meal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
