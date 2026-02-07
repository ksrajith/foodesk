import 'package:cloud_firestore/cloud_firestore.dart';

/// Date string YYYY-MM-DD for today (local).
String get todayDate {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Pool document id for a given date and product.
String poolDocId(String date, String productId) => '${date}_$productId';

/// Returns true if the order's meal type "Order Before" deadline for the vendor has passed today.
Future<bool> isOrderPastDeadline(Map<String, dynamic> order) async {
  final vendorId = order['vendorId'] as String?;
  final mealType = order['mealType'] as String?;
  if (vendorId == null || vendorId.isEmpty || mealType == null || mealType.isEmpty) return false;
  try {
    final doc = await FirebaseFirestore.instance.collection('vendor_config').doc(vendorId).get();
    if (!doc.exists || doc.data() == null) return false;
    final fieldName = 'orderBefore$mealType';
    final hourRaw = doc.data()![fieldName];
    final hour = hourRaw is int ? hourRaw : (hourRaw is num ? hourRaw.toInt() : null);
    if (hour == null || hour < 0 || hour > 23) return false;
    final now = DateTime.now();
    final deadline = DateTime(now.year, now.month, now.day, hour, 0);
    return now.isAfter(deadline) || now.isAtSameMomentAs(deadline);
  } catch (_) {
    return false;
  }
}

/// Add quantity to pool for today and the given product (when user moves order to pool).
Future<void> addToPool({
  required String productId,
  required String productName,
  required String vendorId,
  required String vendorName,
  required String mealType,
  required int quantity,
  double pricePerUnit = 0,
}) async {
  if (quantity <= 0) return;
  final date = todayDate;
  final id = poolDocId(date, productId);
  final ref = FirebaseFirestore.instance.collection('pool').doc(id);
  await FirebaseFirestore.instance.runTransaction((txn) async {
    final snap = await txn.get(ref);
    final current = (snap.exists && snap.data() != null)
        ? ((snap.data()!['quantity'] is int)
            ? (snap.data()!['quantity'] as int)
            : (snap.data()!['quantity'] as num).toInt())
        : 0;
    if (snap.exists) {
      txn.update(ref, {'quantity': current + quantity});
    } else {
      txn.set(ref, {
        'date': date,
        'productId': productId,
        'productName': productName,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'mealType': mealType,
        'quantity': current + quantity,
        'pricePerUnit': pricePerUnit,
      });
    }
  });
}

/// Stream of pool items for a given date (e.g. today). Filter to quantity > 0 in the app.
Stream<QuerySnapshot<Map<String, dynamic>>> poolStreamForDate(String date) {
  return FirebaseFirestore.instance
      .collection('pool')
      .where('date', isEqualTo: date)
      .snapshots();
}

/// Allocate (claim) quantity from pool: decrement pool and create an order for the user.
Future<void> allocateFromPool({
  required String poolDocId,
  required Map<String, dynamic> poolData,
  required int quantity,
  required String customerId,
  required String customerName,
}) async {
  if (quantity <= 0) return;
  final ref = FirebaseFirestore.instance.collection('pool').doc(poolDocId);
  final productId = poolData['productId'] as String?;
  final productName = poolData['productName'] as String?;
  final vendorId = poolData['vendorId'] as String?;
  final vendorName = poolData['vendorName'] as String?;
  final mealType = poolData['mealType'] as String?;
  final pricePerUnit = (poolData['pricePerUnit'] is num) ? (poolData['pricePerUnit'] as num).toDouble() : 0.0;
  final totalPrice = pricePerUnit * quantity;
  if (productId == null || vendorId == null) return;

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final snap = await txn.get(ref);
    if (!snap.exists) throw Exception('Pool item not found');
    final data = snap.data()!;
    final currentQty = (data['quantity'] is int) ? (data['quantity'] as int) : (data['quantity'] as num).toInt();
    if (currentQty < quantity) throw Exception('Not enough in pool');
    txn.update(ref, {'quantity': currentQty - quantity});
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    txn.set(orderRef, {
      'customerId': customerId,
      'customerName': customerName,
      'productId': productId,
      'productName': productName ?? 'Pool meal',
      'vendorId': vendorId,
      'vendorName': vendorName ?? '',
      'quantity': quantity,
      'totalPrice': totalPrice,
      'status': 'Pending',
      'orderDate': DateTime.now().toIso8601String(),
      'deliveryDate': DateTime.now().toIso8601String(),
      'mealType': mealType ?? '—',
      'fromPool': true,
    });
  });
}
