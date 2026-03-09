import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/app_settings.dart';
import '../utils/pool_utils.dart';
import '../widgets/order_before_countdown.dart';

const List<String> kMealTypes = ['Breakfast', 'Lunch', 'Dinner'];

class PlaceMealScreen extends StatefulWidget {
  const PlaceMealScreen({Key? key}) : super(key: key);

  @override
  State<PlaceMealScreen> createState() => _PlaceMealScreenState();
}

/// Start of today (midnight). Late orders allowed for current day.
DateTime get _todayStart {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Start of tomorrow (midnight) for date-picker.
DateTime get _tomorrow {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + 1);
}

class _PlaceMealScreenState extends State<PlaceMealScreen> {
  late DateTime _selectedDate;
  String? _selectedMealType;
  String? _selectedProductId;
  int _quantity = 1;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _loadError;

  /// Products filtered by selected meal type (Breakfast/Lunch/Dinner).
  /// If a product has no mealTypes or empty, it appears for all types.
  List<Map<String, dynamic>> get _productsForSelectedMealType {
    if (_selectedMealType == null) return _products;
    return _products.where((p) {
      final types = p['mealTypes'];
      if (types == null || types is! List || (types as List).isEmpty) return true;
      return (types as List).contains(_selectedMealType);
    }).toList();
  }

  Map<String, dynamic>? get _selectedProduct {
    if (_selectedProductId == null) return null;
    try {
      return _products.firstWhere(
        (p) => p['id'] == _selectedProductId,
      );
    } catch (_) {
      return null;
    }
  }

  /// True when the selected date is the current calendar day (today).
  bool get _isSelectedDateToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year && _selectedDate.month == n.month && _selectedDate.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _tomorrow; // default to tomorrow; user can pick today for late orders
    _selectedMealType = kMealTypes.first;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      final list = snapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((p) => (p['stock'] ?? 0) > 0 && p['active'] != false)
          .toList();
      setState(() {
        _products = list;
        final filtered = list.where((p) {
          final types = p['mealTypes'];
          if (types == null || types is! List || (types as List).isEmpty) return true;
          return _selectedMealType != null && (types as List).contains(_selectedMealType);
        }).toList();
        if (filtered.isNotEmpty && (_selectedProductId == null || !filtered.any((p) => p['id'] == _selectedProductId))) {
          _selectedProductId = filtered.first['id'] as String?;
        } else if (filtered.isEmpty) {
          _selectedProductId = null;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_todayStart) ? _todayStart : _selectedDate,
      firstDate: _todayStart,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// True if Order Before deadline for the selected date and meal type has passed (late order path when date is today).
  Future<bool> _isLateOrder() async {
    final product = _selectedProduct ?? (_productsForSelectedMealType.isNotEmpty ? _productsForSelectedMealType.first : null);
    final vendorId = product?['vendorId'] as String?;
    if (vendorId == null || _selectedMealType == null) return false;
    final deadline = await getOrderBeforeDeadline(vendorId, _selectedMealType!, _selectedDate);
    if (deadline == null) return false;
    return !DateTime.now().isBefore(deadline);
  }

  Future<void> _confirmOrder() async {
    final product = _selectedProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meal'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedMealType == null || _selectedMealType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final isLate = await _isLateOrder();
    if (isLate) {
      final result = await _showLateOrderWarningDialog();
      if (result == null) return; // cancelled
      final customerNotes = result.length > 1 ? result[1] as String? : null;
      await _placeLateOrder(product, _quantity, _selectedDate, _selectedMealType!, customerNotes);
      return;
    }
    await _placeOrder(
      product,
      _quantity,
      _selectedDate,
      _selectedMealType!,
    );
  }

  /// Returns [confirmed, customerNotes]. If user cancelled, returns null.
  Future<List<dynamic>?> _showLateOrderWarningDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<List<dynamic>>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Late Meal Reservation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This is a Late Meal Reservation request and will be sent for supplier approval.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Notes for supplier (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Dietary request, delivery note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [true, controller.text.trim().isEmpty ? null : controller.text.trim()]),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade600),
            child: const Text('Submit for approval'),
          ),
        ],
      );
    });
    return result;
  }

  Future<void> _placeOrder(
    Map<String, dynamic> product,
    int quantity,
    DateTime deliveryDate,
    String mealType,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userDoc = firebaseUser != null
        ? await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get()
        : null;
    final userProfile =
        (userDoc != null && userDoc.exists) ? userDoc.data() : null;
    final totalPrice = (product['price'] ?? 0) * quantity;
    // Use auth uid so notifications can find fcmToken in users/{uid}
    final customerId = firebaseUser?.uid ?? userProfile?['id'] as String? ?? '';

    // Enforce meal limit per day for customers
    final role = (userProfile?['role'] as String?)?.toLowerCase() ?? 'customer';
    if (role == 'customer') {
      final limit = await getMealLimitForType(mealType);
      final startOfDay = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('mealType', isEqualTo: mealType)
          .get();
      int existingQty = 0;
      for (final d in ordersSnap.docs) {
        final data = d.data();
        final raw = data['deliveryDate'] ?? data['orderDate'];
        if (raw == null) continue;
        DateTime? dt;
        if (raw is String) dt = DateTime.tryParse(raw);
        if (raw is Timestamp) dt = (raw as Timestamp).toDate();
        if (dt != null && !dt.isBefore(startOfDay) && dt.isBefore(endOfDay)) {
          final q = (data['quantity'] is int) ? data['quantity'] as int : (data['quantity'] as num).toInt();
          existingQty += q;
        }
      }
      if (existingQty + quantity > limit) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$mealType maximum per day is $limit. You have already ordered $existingQty today.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final prodRef =
            FirebaseFirestore.instance.collection('products').doc(product['id']);
        final snap = await txn.get(prodRef);
        if (!snap.exists) {
          throw Exception('Product not found');
        }
        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] ?? 0) as int;
        if (currentStock < quantity) {
          throw Exception('Insufficient stock');
        }
        txn.update(prodRef, {'stock': currentStock - quantity});

        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        txn.set(orderRef, {
          'customerId': firebaseUser?.uid ?? userProfile?['id'] as String? ?? '',
          'customerName': userProfile?['name'] ?? firebaseUser?.displayName ?? '',
          'productId': product['id'] ?? '',
          'productName': product['name'] ?? '',
          'vendorId': product['vendorId'] ?? '',
          'vendorName': product['vendorName'] ?? '',
          'quantity': quantity,
          'totalPrice': totalPrice,
          'status': 'Pending',
          'orderDate': DateTime.now().toIso8601String(),
          'deliveryDate': deliveryDate.toIso8601String(),
          'mealType': mealType,
        });
      });

      if (!mounted) return;
      final showPrices = await getShowMealPricesToCustomers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            showPrices
                ? 'Order placed successfully! Total: Rs.${totalPrice.toStringAsFixed(2)}'
                : 'Order placed successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Places a late order (current day, past deadline). No stock decrement; status LateOrderPending for supplier approval.
  Future<void> _placeLateOrder(
    Map<String, dynamic> product,
    int quantity,
    DateTime deliveryDate,
    String mealType,
    String? customerNotes,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userDoc = firebaseUser != null
        ? await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get()
        : null;
    final userProfile = (userDoc != null && userDoc.exists) ? userDoc.data() : null;
    final totalPrice = (product['price'] ?? 0) * quantity;
    // Use auth uid so Cloud Function can find fcmToken in users/{uid}
    final customerId = firebaseUser?.uid ?? userProfile?['id'] as String? ?? '';
    final customerEmail = userProfile?['email'] as String? ?? firebaseUser?.email ?? '';

    // Enforce meal limit for customers (same as normal order)
    final role = (userProfile?['role'] as String?)?.toLowerCase() ?? 'customer';
    if (role == 'customer') {
      final limit = await getMealLimitForType(mealType);
      final startOfDay = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('mealType', isEqualTo: mealType)
          .get();
      int existingQty = 0;
      for (final d in ordersSnap.docs) {
        final data = d.data();
        if ((data['status'] as String?) == 'LateOrderPending' || (data['status'] as String?) == 'Pending') {
          final raw = data['deliveryDate'] ?? data['orderDate'];
          if (raw == null) continue;
          DateTime? dt;
          if (raw is String) dt = DateTime.tryParse(raw);
          if (raw is Timestamp) dt = (raw as Timestamp).toDate();
          if (dt != null && !dt.isBefore(startOfDay) && dt.isBefore(endOfDay)) {
            final q = (data['quantity'] is int) ? data['quantity'] as int : (data['quantity'] as num).toInt();
            existingQty += q;
          }
        }
      }
      if (existingQty + quantity > limit) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$mealType maximum per day is $limit. You have already ordered $existingQty today.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'customerId': customerId,
        'customerName': userProfile?['name'] ?? firebaseUser?.displayName ?? '',
        'customerEmail': customerEmail,
        'productId': product['id'] ?? '',
        'productName': product['name'] ?? '',
        'vendorId': product['vendorId'] ?? '',
        'vendorName': product['vendorName'] ?? '',
        'quantity': quantity,
        'totalPrice': totalPrice,
        'status': 'LateOrderPending',
        'lateOrder': true,
        'orderDate': DateTime.now().toIso8601String(),
        'deliveryDate': deliveryDate.toIso8601String(),
        'mealType': mealType,
        if (customerNotes != null && customerNotes.isNotEmpty) 'customerNotes': customerNotes,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Late reservation submitted. Supplier will review and notify you.'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  /// Confirm button: disabled when no meal selected or when Order Before deadline has passed for _selectedDate.
  /// Deadline applies only to the day before delivery (next-day rule).
  Widget _buildConfirmButton() {
    final product = _selectedProduct ?? (_productsForSelectedMealType.isNotEmpty ? _productsForSelectedMealType.first : null);
    final vendorId = product?['vendorId'] as String?;
    final hasProducts = _productsForSelectedMealType.isNotEmpty;

    if (vendorId == null || vendorId.isEmpty || _selectedMealType == null) {
      return ElevatedButton(
        onPressed: hasProducts ? _confirmOrder : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('Confirm'),
      );
    }

    final fieldName = 'orderBefore$_selectedMealType';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendor_config').doc(vendorId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ElevatedButton(
            onPressed: hasProducts ? _confirmOrder : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirm'),
          );
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return ElevatedButton(
            onPressed: hasProducts ? _confirmOrder : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirm'),
          );
        }
        return FutureBuilder<DateTime?>(
          future: getOrderBeforeDeadline(vendorId, _selectedMealType!, _selectedDate),
          builder: (context, deadlineSnap) {
            final deadline = deadlineSnap.data;
            final deadlinePassed = deadline != null && !DateTime.now().isBefore(deadline);
            // Allow confirm when deadline passed only if selected date is today (late order path); else disable
            final disabled = !hasProducts || (deadlinePassed && !_isSelectedDateToday);
            return ElevatedButton(
              onPressed: disabled ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm'),
            );
          },
        );
      },
    );
  }

  /// Shows a dialog with meal name, photo, remaining stock, and description.
  void _showMealDetail(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Unknown';
    final description = product['description'] as String? ?? '';
    final stock = (product['stock'] is int) ? product['stock'] as int : (product['stock'] is num ? (product['stock'] as num).toInt() : 0);
    final imagePath = product['image']?.toString();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imagePath != null && imagePath.isNotEmpty && imagePath.startsWith('assets/'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _mealImagePlaceholder(180),
                  ),
                )
              else if (imagePath != null && imagePath.isNotEmpty && (imagePath.startsWith('http://') || imagePath.startsWith('https://')))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imagePath,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _mealImagePlaceholder(180),
                  ),
                )
              else
                _mealImagePlaceholder(120),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 20, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Remaining stock: $stock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ],
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

  Widget _mealImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.restaurant,
        size: 64,
        color: Colors.grey.shade400,
      ),
    );
  }

  /// Builds "Recommended Order Before" countdown from supplier config for selected meal type.
  Widget _buildOrderBeforeCountdown() {
    final product = _selectedProduct ?? (_productsForSelectedMealType.isNotEmpty ? _productsForSelectedMealType.first : null);
    final vendorId = product?['vendorId'] as String?;
    if (vendorId == null || vendorId.isEmpty || _selectedMealType == null) return const SizedBox.shrink();

    final fieldName = 'orderBefore$_selectedMealType';
    final baseField = 'orderBefore${_selectedMealType}DeadlineBase';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendor_config').doc(vendorId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();
        final hourRaw = data[fieldName];
        final hour = hourRaw is int
            ? (hourRaw >= 0 && hourRaw <= 23 ? hourRaw : null)
            : (hourRaw is num ? hourRaw.toInt().clamp(0, 23) : null);
        if (hour == null) return const SizedBox.shrink();
        final base = data[baseField] as String?;
        final useDayBefore = base != kDeadlineBaseCurrent;
        return OrderBeforeCountdown(
          orderBeforeHour24: hour,
          label: 'Recommended Order Before',
          deliveryDate: _selectedDate,
          useDayBeforeDeadline: useDayBefore,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place a Meal'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Could not load meals',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadProducts,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: appSettingsStream(),
                  builder: (context, settingsSnap) {
                    final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? false;
                    return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Date
                      const Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('EEE, MMM d, y').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Meal type dropdown
                      const Text(
                        'Meal type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMealType,
                            isExpanded: true,
                            items: kMealTypes
                                .map((type) => DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedMealType = value;
                                  final filtered = _productsForSelectedMealType;
                                  final currentInFiltered = filtered.any((p) => p['id'] == _selectedProductId);
                                  if (!currentInFiltered && filtered.isNotEmpty) {
                                    _selectedProductId = filtered.first['id'] as String?;
                                  } else if (filtered.isEmpty) {
                                    _selectedProductId = null;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Recommended Order Before: only for current date
                      if (_isSelectedDateToday) _buildOrderBeforeCountdown(),
                      if (_isSelectedDateToday) const SizedBox(height: 24),
                      // Meal list dropdown (filtered by selected meal type)
                      const Text(
                        'Meal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _productsForSelectedMealType.any((p) => p['id'] == _selectedProductId)
                                ? _selectedProductId
                                : (_productsForSelectedMealType.isNotEmpty ? _productsForSelectedMealType.first['id'] as String? : null),
                            isExpanded: true,
                            items: _productsForSelectedMealType
                                .map((p) {
                                  final id = p['id'] as String?;
                                  final priceStr = showPrices
                                      ? 'Rs.${(p['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'
                                      : 'Price hidden';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(
                                      '${p['name'] ?? 'Unknown'} - $priceStr',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedProductId = value);
                              }
                            },
                          ),
                        ),
                      ),
                      if (_productsForSelectedMealType.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No meals available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      if (_selectedProduct != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showMealDetail(_selectedProduct!),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 18, color: Colors.teal.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'View meal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Quantity
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                      if (_selectedProduct != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          showPrices
                              ? 'Total: Rs.${((_selectedProduct!['price'] as num? ?? 0) * _quantity).toStringAsFixed(2)}'
                              : 'Total: Price hidden',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      // Cancel & Confirm (Confirm disabled when deadline passed for selected date)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                side: BorderSide(
                                    color: Colors.teal.shade600),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildConfirmButton(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                  },
                ),
    );
  }
}
