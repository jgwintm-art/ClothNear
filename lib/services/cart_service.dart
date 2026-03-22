import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_model.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get cart items for a customer
  Stream<List<CartItemModel>> getCartItems(String customerUid) {
    return _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CartItemModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Add item to cart
  Future<void> addToCart(String customerUid, CartItemModel item) async {
    // Check if same product+color+size already in cart
    final existing = await _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .where('productId', isEqualTo: item.productId)
        .where('color', isEqualTo: item.color)
        .where('size', isEqualTo: item.size)
        .get();

    if (existing.docs.isNotEmpty) {
      // Update quantity
      final existingDoc = existing.docs.first;
      final currentQty = existingDoc.data()['quantity'] ?? 1;
      await existingDoc.reference.update({
        'quantity': currentQty + item.quantity,
      });
    } else {
      // Add new item
      await _firestore
          .collection('carts')
          .doc(customerUid)
          .collection('items')
          .add(item.toMap());
    }
  }

  // Update cart item quantity
  Future<void> updateQuantity(
    String customerUid,
    String cartItemId,
    int quantity,
  ) async {
    await _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .doc(cartItemId)
        .update({'quantity': quantity});
  }

  // Remove item from cart
  Future<void> removeFromCart(String customerUid, String cartItemId) async {
    await _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .doc(cartItemId)
        .delete();
  }

  // Clear entire cart
  Future<void> clearCart(String customerUid) async {
    final items = await _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .get();
    for (final doc in items.docs) {
      await doc.reference.delete();
    }
  }

  // Get cart item count
  Stream<int> getCartCount(String customerUid) {
    return _firestore
        .collection('carts')
        .doc(customerUid)
        .collection('items')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
