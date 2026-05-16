import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../models/product.dart';

/// Repository for product/meal data. Encapsulates Firestore access.
class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Stream of products for a supplier. Returns typed [Product] list.
  Stream<List<Product>> streamProductsBySupplier(String supplierId) {
    return _firestore
        .collection(AppConstants.collectionProducts)
        .where('vendorId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Product.fromMap(d.id, d.data()))
            .toList());
  }

  /// Stream of all products (e.g. for admin).
  Stream<List<Product>> streamAllProducts() {
    return _firestore
        .collection(AppConstants.collectionProducts)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Product.fromMap(d.id, d.data()))
            .toList());
  }
}
