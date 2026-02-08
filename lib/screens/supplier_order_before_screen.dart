import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kMealTypeKeys = ['Breakfast', 'Lunch', 'Dinner'];
List<int> get _hours24 => List.generate(24, (i) => i);

class SupplierOrderBeforeScreen extends StatefulWidget {
  const SupplierOrderBeforeScreen({Key? key}) : super(key: key);

  @override
  State<SupplierOrderBeforeScreen> createState() => _SupplierOrderBeforeScreenState();
}

class _SupplierOrderBeforeScreenState extends State<SupplierOrderBeforeScreen> {
  final Map<String, int> _orderBeforeHours = {
    'Breakfast': 8,
    'Lunch': 12,
    'Dinner': 19,
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendor_config')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          for (final key in kMealTypeKeys) {
            final v = data['orderBefore$key'];
            if (v is int && v >= 0 && v <= 23) _orderBeforeHours[key] = v;
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final data = <String, int>{
        'orderBeforeBreakfast': _orderBeforeHours['Breakfast']!,
        'orderBeforeLunch': _orderBeforeHours['Lunch']!,
        'orderBeforeDinner': _orderBeforeHours['Dinner']!,
      };
      await FirebaseFirestore.instance
          .collection('vendor_config')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order Before times saved.'), backgroundColor: Colors.green),
      );
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
        title: const Text('Order Before'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: Colors.red.shade700)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Set the latest time (24h) customers can place an order for each meal type. Countdown resets daily at 00:00.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      ...kMealTypeKeys.map((mealType) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Before — $mealType',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _orderBeforeHours[mealType]!,
                                    isExpanded: true,
                                    items: _hours24
                                        .map((h) => DropdownMenuItem<int>(
                                              value: h,
                                              child: Text(
                                                '${h.toString().padLeft(2, '0')}:00',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _orderBeforeHours[mealType] = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
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
                              : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
