/// Domain model for an order. Maps to Firestore `orders` collection.
/// Add fields as needed when migrating screens (status, customerId, totalPrice, etc.).
class Order {
  const Order({
    required this.id,
    this.status,
    this.customerId,
    this.customerName,
    this.customerEmail,
    this.productId,
    this.productName,
    this.vendorId,
    this.vendorName,
    this.quantity = 0,
    this.totalPrice = 0,
    this.mealType,
    this.lateOrder = false,
    this.deliveryDate,
    this.orderDate,
  });

  final String id;
  final String? status;
  final String? customerId;
  final String? customerName;
  final String? customerEmail;
  final String? productId;
  final String? productName;
  final String? vendorId;
  final String? vendorName;
  final int quantity;
  final double totalPrice;
  final String? mealType;
  final bool lateOrder;
  final DateTime? deliveryDate;
  final DateTime? orderDate;

  factory Order.fromMap(String id, Map<String, dynamic> map) {
    return Order(
      id: id,
      status: map['status'] as String?,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      customerEmail: map['customerEmail'] as String?,
      productId: map['productId'] as String?,
      productName: map['productName'] as String?,
      vendorId: map['vendorId'] as String?,
      vendorName: map['vendorName'] as String?,
      quantity: (map['quantity'] is int) ? map['quantity'] as int : (map['quantity'] is num) ? (map['quantity'] as num).toInt() : 0,
      totalPrice: (map['totalPrice'] is num) ? (map['totalPrice'] as num).toDouble() : 0,
      mealType: map['mealType'] as String?,
      lateOrder: map['lateOrder'] == true,
      deliveryDate: _parseDate(map['deliveryDate']),
      orderDate: _parseDate(map['orderDate']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
