import 'package:flutter/foundation.dart';

/// Represents a single item in the POS cart.
class CartItem {
  final String productId;
  final String productName;
  final String color;
  final String size;
  int quantity;
  final double unitPrice;

  CartItem({
    required this.productId,
    required this.productName,
    required this.color,
    required this.size,
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => unitPrice * quantity;

  /// Produces the exact Map shape expected by
  /// InventoryService.deductInventoryForOrder().
  Map<String, dynamic> toOrderItem() => {
    'productId': productId,
    'productName': productName,
    'color': color,
    'size': size,
    'quantity': quantity,
  };

  /// Unique key for variant identity — used to detect duplicates in addItem().
  String get variantKey => '$productId|$color|$size';
}

/// Lightweight ChangeNotifier that holds the POS cart state for one transaction.
///
/// Lifecycle:
///   - Provide at WorkerPOSScreen level (not app-level) so the cart is
///     automatically disposed when the POS screen is popped.
///   - clearCart() is called after a successful sale before navigating away.
class POSCartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  // ── Read-only accessors ────────────────────────────────────────────────────

  List<CartItem> get items => List.unmodifiable(_items);

  /// Running total across all line items.
  double get total => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Total individual units in the cart (not distinct products).
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  bool get isEmpty => _items.isEmpty;

  // ── Mutation methods ───────────────────────────────────────────────────────

  /// Adds [item] to the cart.
  ///
  /// If the same variant (productId + color + size) is already in the cart,
  /// the quantity is incremented instead of creating a duplicate row.
  void addItem(CartItem item) {
    final existing = _items.indexWhere((i) => i.variantKey == item.variantKey);
    if (existing >= 0) {
      _items[existing].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  /// Removes the item at [index] entirely.
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  /// Sets the quantity of the item at [index] to [qty].
  ///
  /// If [qty] <= 0 the item is removed from the cart.
  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= _items.length) return;
    if (qty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = qty;
    }
    notifyListeners();
  }

  /// Empties the cart. Call after a successful sale is confirmed.
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // ── Helpers for order creation ─────────────────────────────────────────────

  /// Returns the list of order item maps ready to pass to OrderModel.items
  /// and InventoryService.deductInventoryForOrder().
  List<Map<String, dynamic>> get orderItems =>
      _items.map((i) => i.toOrderItem()).toList();
}
