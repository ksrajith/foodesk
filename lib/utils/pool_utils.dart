import 'package:cloud_firestore/cloud_firestore.dart';

/// Date string YYYY-MM-DD for today (local).
String get todayDate {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Pool document id for a given date and product.
String poolDocId(String date, String productId) => '${date}_$productId';

/// Deadline base: 'day_before' = deadline on (deliveryDate - 1) at hour; 'current' = deadline on deliveryDate at hour.
const String kDeadlineBaseDayBefore = 'day_before';
const String kDeadlineBaseCurrent = 'current';
const String kDeadlineBaseDefault = kDeadlineBaseDayBefore;

/// Parses delivery/order date from order map.
DateTime? _orderDeliveryDate(Map<String, dynamic> order) {
  final raw = order['deliveryDate'] ?? order['orderDate'];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is Timestamp) return raw.toDate();
  return null;
}

/// Returns the "Order Before" deadline for a given vendor, meal type, and delivery date.
/// Uses vendor_config: orderBefore{MealType} (hour) and orderBefore{MealType}DeadlineBase ('day_before' | 'current').
/// Default deadline base is 'day_before'.
Future<DateTime?> getOrderBeforeDeadline(String vendorId, String mealType, DateTime deliveryDate) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('vendor_config').doc(vendorId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    final fieldName = 'orderBefore$mealType';
    final hourRaw = data[fieldName];
    final hour = hourRaw is int ? hourRaw : (hourRaw is num ? hourRaw.toInt() : null);
    if (hour == null || hour < 0 || hour > 23) return null;
    final baseField = 'orderBefore${mealType}DeadlineBase';
    final base = (data[baseField] as String?) ?? kDeadlineBaseDefault;
    final useDayBefore = base != kDeadlineBaseCurrent;
    final deadlineDay = useDayBefore
        ? deliveryDate.subtract(const Duration(days: 1))
        : deliveryDate;
    return DateTime(
      deadlineDay.year,
      deadlineDay.month,
      deadlineDay.day,
      hour.clamp(0, 23),
      0,
    );
  } catch (_) {
    return null;
  }
}

/// Returns true if the order's "Order Before" deadline has passed (based on order's delivery date and supplier config).
Future<bool> isOrderPastDeadline(Map<String, dynamic> order) async {
  final vendorId = order['vendorId'] as String?;
  final mealType = order['mealType'] as String?;
  final deliveryDate = _orderDeliveryDate(order);
  if (vendorId == null || vendorId.isEmpty || mealType == null || mealType.isEmpty || deliveryDate == null) {
    return false;
  }
  try {
    final deadline = await getOrderBeforeDeadline(vendorId, mealType, deliveryDate);
    if (deadline == null) return false;
    final now = DateTime.now();
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

/// Date string YYYY-MM-DD from DateTime.
String dateToDateString(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Returns (startDate, endDate) as YYYY-MM-DD for the given mode anchored to [refDate].
/// [mode] is 'Daily' | 'Weekly' | 'Monthly' | 'Yearly'.
MapEntry<String, String> poolDateRangeForMode(DateTime refDate, String mode) {
  String start;
  String end;
  switch (mode) {
    case 'Weekly':
      final weekday = refDate.weekday;
      final startDt = DateTime(refDate.year, refDate.month, refDate.day - (weekday - 1));
      final endDt = startDt.add(const Duration(days: 6));
      start = dateToDateString(startDt);
      end = dateToDateString(endDt);
      break;
    case 'Monthly':
      start = dateToDateString(DateTime(refDate.year, refDate.month, 1));
      final lastDay = DateTime(refDate.year, refDate.month + 1, 0);
      end = dateToDateString(lastDay);
      break;
    case 'Yearly':
      start = dateToDateString(DateTime(refDate.year, 1, 1));
      end = dateToDateString(DateTime(refDate.year, 12, 31));
      break;
    default:
      start = dateToDateString(refDate);
      end = start;
  }
  return MapEntry(start, end);
}

/// Stream of pool items for a given date (e.g. today). Filter to quantity > 0 in the app.
Stream<QuerySnapshot<Map<String, dynamic>>> poolStreamForDate(String date) {
  return FirebaseFirestore.instance
      .collection('pool')
      .where('date', isEqualTo: date)
      .snapshots();
}

/// Stream of pool items for a date range (inclusive). YYYY-MM-DD strings sort lexicographically.
Stream<QuerySnapshot<Map<String, dynamic>>> poolStreamForDateRange(String startDate, String endDate) {
  return FirebaseFirestore.instance
      .collection('pool')
      .where('date', isGreaterThanOrEqualTo: startDate)
      .where('date', isLessThanOrEqualTo: endDate)
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
