import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Immutable state container for the POS cart in Riverpod 3.
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
  void addItem(CartItem item) {
    final currentList = state.items.toList();
    final existingIndex = currentList.indexWhere(
      (i) => i.variantKey == item.variantKey,
    );

    if (existingIndex >= 0) {
      currentList[existingIndex].quantity += item.quantity;
    } else {
      currentList.add(item);
    }

    state = state.copyWith(items: currentList);
  }

  /// Removes the item at [index] entirely.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final currentList = state.items.toList()..removeAt(index);
    state = state.copyWith(items: currentList);
  }

  /// Sets the quantity of the item at [index] to [qty].
  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= state.items.length) return;
    if (qty <= 0) {
      removeItem(index);
    } else {
      final currentList = state.items.toList();
      currentList[index].quantity = qty;
      state = state.copyWith(items: currentList);
    }
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
