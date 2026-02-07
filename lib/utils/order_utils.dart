import 'package:cloud_firestore/cloud_firestore.dart';

/// Cancels an order and restores the product's available stock by the ordered quantity.
/// Call this when a user or admin cancels an order (e.g. status was Pending).
Future<void> cancelOrderAndRestoreStock({
  required String orderId,
  required Map<String, dynamic> order,
}) async {
  final productId = order['productId'] as String?;
  final quantity = (order['quantity'] is int)
      ? (order['quantity'] as int)
      : (order['quantity'] is num)
          ? (order['quantity'] as num).toInt()
          : 0;
  if (productId == null || productId.isEmpty || quantity <= 0) return;

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final prodRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final prodSnap = await txn.get(prodRef);
    if (!prodSnap.exists) return;
    final data = prodSnap.data() as Map<String, dynamic>;
    final currentStock = (data['stock'] is int)
        ? (data['stock'] as int)
        : (data['stock'] is num)
            ? (data['stock'] as num).toInt()
            : 0;
    txn.update(prodRef, {'stock': currentStock + quantity});
    txn.update(orderRef, {'status': 'Cancelled'});
  });
}
