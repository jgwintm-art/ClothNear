import 'package:cloud_firestore/cloud_firestore.dart';

class PricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Bulk-update the price of every variant on a single product.
  Future<void> updateAllVariantPrices(
    String productId,
    Map<String, double> variantPrices, // key → new price
    double newBasePrice,
  ) async {
    final Map<String, dynamic> updates = {'basePrice': newBasePrice};
    variantPrices.forEach((key, price) {
      updates['variants.$key.price'] = price;
    });
    await _firestore.collection('products').doc(productId).update(updates);
  }

  /// Update just the base price of a product (cascades to all variant
  /// controllers in the UI — does NOT write per-variant prices).
  Future<void> updateBasePrice(String productId, double newBasePrice) async {
    await _firestore.collection('products').doc(productId).update({
      'basePrice': newBasePrice,
    });
  }

  /// Update a single variant's price.
  Future<void> updateVariantPrice(
    String productId,
    String variantKey,
    double newPrice,
  ) async {
    await _firestore.collection('products').doc(productId).update({
      'variants.$variantKey.price': newPrice,
    });
  }
}
