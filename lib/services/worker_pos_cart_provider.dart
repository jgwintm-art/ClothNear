import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single item in the POS cart.
///
/// IMMUTABLE by design — all fields are final.
/// Riverpod detects state changes by comparing state object references.
/// If CartItem were mutable, `current[idx].quantity += 1` would mutate the
/// same object already held in the previous state, making the old and new
/// state lists point to the same modified instances — Riverpod would see
/// identical references and suppress the rebuild entirely.
///
/// All mutations go through [copyWith] which returns a new instance.
class CartItem {
  final String productId;
  final String productName;
  final String color;
  final String size;
  final int quantity; // ← final, not var
  final double unitPrice;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.color,
    required this.size,
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => unitPrice * quantity;

  /// Unique key for variant identity — used to detect duplicates in addItem().
  String get variantKey => '$productId|$color|$size';

  /// Returns a copy with the given fields replaced.
  CartItem copyWith({
    String? productId,
    String? productName,
    String? color,
    String? size,
    int? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      color: color ?? this.color,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  /// Produces the exact Map shape expected by
  /// InventoryService.deductInventoryForOrder() and OrderService.placeOrder().
  Map<String, dynamic> toOrderItem() => {
    'productId': productId,
    'productName': productName,
    'color': color,
    'size': size,
    'quantity': quantity,
  };
}

/// Immutable state container for the POS cart.
class POSCartState {
  final List<CartItem> items;

  const POSCartState({this.items = const []});

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;
  double get total => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Returns the list of order item maps ready to pass to OrderModel.items
  /// and InventoryService.deductInventoryForOrder().
  List<Map<String, dynamic>> get orderItems =>
      items.map((i) => i.toOrderItem()).toList();

  POSCartState copyWith({List<CartItem>? items}) {
    return POSCartState(items: items ?? this.items);
  }
}

/// Riverpod 3 Notifier managing the POS cart lifecycle.
class POSCartNotifier extends Notifier<POSCartState> {
  @override
  POSCartState build() => const POSCartState();

  /// Adds [item] to the cart.
  /// If the same variant already exists, increments quantity via copyWith
  /// (never mutates the existing CartItem in place).
  void addItem(CartItem item) {
    final currentList = state.items.toList();
    final idx = currentList.indexWhere((i) => i.variantKey == item.variantKey);

    if (idx >= 0) {
      // Replace the existing CartItem with a new immutable instance.
      currentList[idx] = currentList[idx].copyWith(
        quantity: currentList[idx].quantity + item.quantity,
      );
    } else {
      currentList.add(item);
    }

    state = state.copyWith(items: currentList);
  }

  /// Removes the item at [index] entirely.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final next = state.items.toList()..removeAt(index);
    state = state.copyWith(items: next);
  }

  /// Sets the quantity of the item at [index] to [qty].
  /// Removes the item if qty <= 0.
  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= state.items.length) return;
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    final next = state.items.toList();
    // Replace with a new immutable CartItem — never mutate in place.
    next[index] = next[index].copyWith(quantity: qty);
    state = state.copyWith(items: next);
  }

  /// Empties the cart. Call after a successful sale is confirmed.
  void clearCart() {
    state = const POSCartState();
  }
}

/// System-wide Riverpod 3 provider for the POS Cart.
final posCartProvider = NotifierProvider<POSCartNotifier, POSCartState>(
  POSCartNotifier.new,
);
