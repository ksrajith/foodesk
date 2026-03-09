import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  final Set<String> _selectedMealTypes = {};
  bool _saving = false;
  /// Active = shown to customers and listed at top in My Menu. Default true.
  bool _active = true;
  /// Meal photo: download URL (from Storage or existing product). Max 500 KB after compression.
  String? _imageUrl;
  bool _uploadingImage = false;
  static const int _maxImageBytes = 500 * 1024; // 500 KB

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
      final existingImage = p['image'];
      _imageUrl = (existingImage is String && existingImage.isNotEmpty) ? existingImage : null;
      _active = p['active'] != false;
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
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, imageQuality: 90, maxWidth: 1200);
    if (file == null || !mounted) return;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await _compressToMaxBytes(File(file.path), _maxImageBytes);
      if (bytes == null || bytes.isEmpty || !mounted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process image.'), backgroundColor: Colors.orange),
        );
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !mounted) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      if (mounted) setState(() { _imageUrl = url; _uploadingImage = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Compress image to at most [maxBytes]. Returns JPEG bytes or null.
  Future<List<int>?> _compressToMaxBytes(File file, int maxBytes) async {
    List<int>? bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      minHeight: 800,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return null;
    if (bytes.length <= maxBytes) return bytes;
    for (int quality = 70; quality >= 20; quality -= 15) {
      bytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 600,
        minHeight: 600,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (bytes != null && bytes.length <= maxBytes) return bytes;
    }
    bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 400,
      minHeight: 400,
      quality: 50,
      format: CompressFormat.jpeg,
    );
    return bytes;
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
        'active': _active,
      };
      if (_imageUrl != null && _imageUrl!.isNotEmpty) data['image'] = _imageUrl;

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
            CheckboxListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v ?? true),
              title: const Text('Active'),
              subtitle: const Text('Inactive meals are hidden from customers and listed at the bottom in My Meals'),
              activeColor: Colors.teal,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
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
            const Text('Meal photo (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_uploadingImage)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Row(
                children: [
                  if (_imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _imageUrl = null),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Remove'),
                    ),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 20),
                          label: const Text('Camera'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Image is compressed to max 500 KB before upload.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
