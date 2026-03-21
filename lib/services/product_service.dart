import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new product
  Future<void> addProduct(ProductModel product) async {
    await _firestore.collection('products').add(product.toMap());
  }

  // Get all products for a store
  Stream<List<ProductModel>> getProductsByStore(String storeId) {
    return _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update a product
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('products').doc(productId).update(data);
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  // Update specific variant stock
  Future<void> updateVariantStock(
    String productId,
    String variantKey,
    int newStock,
  ) async {
    await _firestore.collection('products').doc(productId).update({
      'variants.$variantKey.stock': newStock,
    });
  }

  // Get single product
  Future<ProductModel?> getProductById(String productId) async {
    DocumentSnapshot doc = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    if (!doc.exists) return null;
    return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}
