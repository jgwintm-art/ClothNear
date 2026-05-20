// lib/services/worker_pos_cart_provider.dart
//
// CHANGES FROM ORIGINAL:
//   • POSCartProvider (ChangeNotifier) replaced by _CartNotifier (Notifier<_CartState>)
//     — zero ChangeNotifier in the codebase; fully Riverpod 3 compliant.
//   • _CartState is an immutable value object; all mutations return new state
//     via copyWith(), making state changes explicit and testable.
//   • posCartProvider is a plain NotifierProvider (not autoDispose) so the
//     nested ProviderScope inside WorkerPOSScreen controls its lifetime —
//     it is created when the POS screen opens and disposed on pop.
//   • CartItem is UNCHANGED — same fields, same toOrderItem(), same variantKey.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CartItem — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Cart state — immutable value object
// ─────────────────────────────────────────────────────────────────────────────

class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;
  double get total => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Serializes each CartItem into the Firestore-compatible map structure
  /// expected by OrderModel.items, InventoryService.checkStock(), and
  /// InventoryService.deductInventoryForOrder().
  /// Delegates to CartItem.toOrderItem() as the single source of truth.
  List<Map<String, dynamic>> get orderItems =>
      items.map((i) => i.toOrderItem()).toList();

  CartState copyWith({List<CartItem>? items}) =>
      CartState(items: items ?? this.items);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart notifier — Riverpod 3 Notifier
// ─────────────────────────────────────────────────────────────────────────────

class _CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds [item] to the cart.
  ///
  /// If the same variant (productId + color + size) is already in the cart,
  /// the quantity is incremented instead of creating a duplicate row.
  /// CartItem.quantity is mutable (var) — incremented directly.
  void addItem(CartItem item) {
    final current = state.items.toList();
    final idx = current.indexWhere((e) => e.variantKey == item.variantKey);
    if (idx >= 0) {
      current[idx].quantity += item.quantity;
    } else {
      current.add(item);
    }
    state = state.copyWith(items: current);
  }

  /// Removes the item at [index] entirely.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final current = state.items.toList()..removeAt(index);
    state = state.copyWith(items: current);
  }

  /// Sets the quantity of the item at [index] to [qty].
  ///
  /// If [qty] <= 0 the item is removed from the cart.
  /// CartItem.quantity is mutable (var) — set directly, no reconstruction needed.
  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= state.items.length) return;
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    final current = state.items.toList();
    current[index].quantity = qty;
    state = state.copyWith(items: current);
  }

  /// Empties the cart. Called after a successful sale and on new sale start.
  void clearCart() => state = const CartState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider — scoped to WorkerPOSScreen's nested ProviderScope
// ─────────────────────────────────────────────────────────────────────────────

/// Cart provider scoped to the POS session.
///
/// This is a plain [NotifierProvider] (not autoDispose) because lifetime
/// is controlled by the nested [ProviderScope] inside [WorkerPOSScreen].
/// When the POS screen is popped, the [ProviderScope] disposes and the cart
/// is automatically reset — no manual cleanup needed.
final posCartProvider = NotifierProvider<_CartNotifier, CartState>(
  _CartNotifier.new,
);
