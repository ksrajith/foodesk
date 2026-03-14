/// Domain model for a product/meal. Maps to Firestore `products` collection.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.stock = 0,
    this.mealTypes = const [],
    this.vendorId,
    this.vendorName,
    this.image,
    this.active = true,
  });

  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final List<String> mealTypes;
  final String? vendorId;
  final String? vendorName;
  final String? image;
  final bool active;

  bool get isActive => active;

  /// Parse from Firestore document map (document id + data).
  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final types = map['mealTypes'];
    return Product(
      id: id,
      name: (map['name'] ?? '') as String,
      description: map['description'] as String?,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0,
      stock: (map['stock'] is int) ? map['stock'] as int : (map['stock'] is num) ? (map['stock'] as num).toInt() : 0,
      mealTypes: types is List ? types.map((e) => e.toString()).toList() : [],
      vendorId: map['vendorId'] as String?,
      vendorName: map['vendorName'] as String?,
      image: map['image'] as String?,
      active: map['active'] != false,
    );
  }

  /// Convert to map for Firestore write (e.g. update). Excludes id (use doc ref separately).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description ?? '',
      'price': price,
      'stock': stock,
      'mealTypes': mealTypes,
      if (vendorId != null) 'vendorId': vendorId,
      if (vendorName != null) 'vendorName': vendorName,
      if (image != null && image!.isNotEmpty) 'image': image,
      'active': active,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    List<String>? mealTypes,
    String? vendorId,
    String? vendorName,
    String? image,
    bool? active,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      mealTypes: mealTypes ?? this.mealTypes,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      image: image ?? this.image,
      active: active ?? this.active,
    );
  }
}
