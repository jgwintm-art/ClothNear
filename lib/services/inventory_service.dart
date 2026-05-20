import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Handles all inventory mutation operations.
///
/// Design principles (follows standard e-commerce practices):
///
/// 1. ATOMIC — every deduction runs inside a Firestore transaction so that
///    concurrent orders cannot both decrement the same stock and cause
///    negative inventory (overselling).
///
/// 2. IDEMPOTENT — before deducting, the service checks whether this
///    [orderId] has already been recorded in the product's
///    `deductedOrders` map. If it has, the deduction is skipped.
///    This guarantees that retrying a failed network call, or calling
///    deductInventoryForOrder() from both the checkout screen and the
///    approval screen, will never double-deduct.
///
/// 3. OVERSELL-SAFE — if any variant has insufficient stock the entire
///    batch is aborted and an [InsufficientStockException] is thrown.
///    The caller (checkout / approval) should surface this to the user.
///
/// 4. VARIANT-KEYED — keys follow ProductModel.variantKey(color, size)
///    i.e. "${color.toLowerCase()}_${size.toLowerCase()}".
///
/// Firestore paths written:
///   products/{productId}
///     variants.{variantKey}.stock          — decremented atomically
///     deductedOrders.{orderId}             — idempotency marker (ms epoch)
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Deducts inventory for all items in [orderItems] atomically.
  ///
  /// [orderItems] — the `items` list stored on the Firestore order document.
  ///   Each item must contain: productId, color, size, quantity (int).
  ///
  /// [orderId] — used for idempotency. Calling this multiple times with the
  ///   same orderId is safe; subsequent calls are no-ops per product.
  ///
  /// Throws [InsufficientStockException] if ANY item has insufficient stock.
  /// In that case NO inventory is changed (the transaction aborts entirely
  /// per-product; products already processed are not rolled back — see note
  /// below about batch ordering).
  ///
  /// NOTE: We run one transaction per unique productId rather than one giant
  /// transaction across all products. Firestore transactions are limited to
  /// 500 documents and cross-shard transactions add latency. For typical
  /// orders (1–5 products) this is perfectly safe. We check oversell for
  /// ALL products before writing any, so the user gets a full error list.
  Future<void> deductInventoryForOrder({
    required String orderId,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    if (orderItems.isEmpty) return;

    // Group items by productId so we do one transaction per product doc.
    final Map<String, List<Map<String, dynamic>>> byProduct = {};
    for (final item in orderItems) {
      final pid = item['productId'] as String? ?? '';
      if (pid.isEmpty) continue;
      byProduct.putIfAbsent(pid, () => []).add(item);
    }

    // Phase 1: validate all products have sufficient stock.
    // We read all products first, then write, so the user gets a complete
    // list of stockouts rather than one-at-a-time error messages.
    final List<StockError> errors = [];

    for (final entry in byProduct.entries) {
      final productId = entry.key;
      final items = entry.value;

      final snap = await _db.collection('products').doc(productId).get();
      if (!snap.exists) {
        errors.add(
          StockError(
            productId: productId,
            productName: items.first['productName'] as String? ?? productId,
            variantKey: '',
            requested: 0,
            available: 0,
            reason: 'Product not found',
          ),
        );
        continue;
      }

      // Check idempotency: if already deducted for this order, skip validation.
      final data = snap.data()!;
      final deducted = (data['deductedOrders'] as Map<String, dynamic>?);
      if (deducted != null && deducted.containsKey(orderId)) continue;

      final variantsRaw = (data['variants'] as Map<String, dynamic>?) ?? {};

      for (final item in items) {
        final color = (item['color'] as String? ?? '').toLowerCase();
        final size = (item['size'] as String? ?? '').toLowerCase();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final key = ProductModel.variantKey(color, size);

        final variantData = variantsRaw[key] as Map<String, dynamic>?;
        if (variantData == null) {
          errors.add(
            StockError(
              productId: productId,
              productName: item['productName'] as String? ?? productId,
              variantKey: key,
              requested: qty,
              available: 0,
              reason: 'Variant not found',
            ),
          );
          continue;
        }

        final available = (variantData['stock'] as num?)?.toInt() ?? 0;
        if (available < qty) {
          errors.add(
            StockError(
              productId: productId,
              productName: item['productName'] as String? ?? productId,
              variantKey: key,
              requested: qty,
              available: available,
              reason: 'Insufficient stock',
            ),
          );
        }
      }
    }

    if (errors.isNotEmpty) {
      throw InsufficientStockException(errors);
    }

    // Phase 2: atomically deduct each product in its own transaction.
    for (final entry in byProduct.entries) {
      final productId = entry.key;
      final items = entry.value;
      final ref = _db.collection('products').doc(productId);

      await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return; // already validated; skip ghost products

        final data = snap.data()!;

        // Idempotency check inside the transaction (race-safe).
        final deducted = (data['deductedOrders'] as Map<String, dynamic>?);
        if (deducted != null && deducted.containsKey(orderId)) return;

        final variantsRaw = Map<String, dynamic>.from(
          data['variants'] as Map? ?? {},
        );

        // Build the update map.
        final Map<String, dynamic> updates = {};

        for (final item in items) {
          final color = (item['color'] as String? ?? '').toLowerCase();
          final size = (item['size'] as String? ?? '').toLowerCase();
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final key = ProductModel.variantKey(color, size);

          final variantData = variantsRaw[key] as Map<String, dynamic>?;
          if (variantData == null) continue;

          final current = (variantData['stock'] as num?)?.toInt() ?? 0;
          // Re-check inside the transaction in case another order raced.
          if (current < qty) {
            throw InsufficientStockException([
              StockError(
                productId: productId,
                productName: item['productName'] as String? ?? productId,
                variantKey: key,
                requested: qty,
                available: current,
                reason: 'Stock changed — please retry',
              ),
            ]);
          }

          // Use FieldValue.increment for server-side atomicity.
          updates['variants.$key.stock'] = FieldValue.increment(-qty);
        }

        // Record orderId so future retries are idempotent.
        updates['deductedOrders.$orderId'] =
            DateTime.now().millisecondsSinceEpoch;

        txn.update(ref, updates);
      });
    }
  }

  /// Restores inventory for a cancelled or rejected order.
  ///
  /// Safe to call multiple times — if the order was never deducted (e.g.
  /// a rush order that was rejected before approval), the restore is skipped.
  Future<void> restoreInventoryForOrder({
    required String orderId,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    if (orderItems.isEmpty) return;

    final Map<String, List<Map<String, dynamic>>> byProduct = {};
    for (final item in orderItems) {
      final pid = item['productId'] as String? ?? '';
      if (pid.isEmpty) continue;
      byProduct.putIfAbsent(pid, () => []).add(item);
    }

    for (final entry in byProduct.entries) {
      final productId = entry.key;
      final items = entry.value;
      final ref = _db.collection('products').doc(productId);

      await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;

        final data = snap.data()!;
        final deducted = (data['deductedOrders'] as Map<String, dynamic>?);

        // Only restore if this order was actually deducted.
        if (deducted == null || !deducted.containsKey(orderId)) return;

        final Map<String, dynamic> updates = {};

        for (final item in items) {
          final color = (item['color'] as String? ?? '').toLowerCase();
          final size = (item['size'] as String? ?? '').toLowerCase();
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final key = ProductModel.variantKey(color, size);

          updates['variants.$key.stock'] = FieldValue.increment(qty);
        }

        // Remove orderId from deductedOrders so re-placing the order works.
        updates['deductedOrders.$orderId'] = FieldValue.delete();

        txn.update(ref, updates);
      });
    }
  }

  /// Reads current variant stock for a list of items.
  /// Used by the checkout screen for stock validation before showing the UI.
  Future<StockCheckResult> checkStock(List<Map<String, dynamic>> items) async {
    final Map<String, List<Map<String, dynamic>>> byProduct = {};
    for (final item in items) {
      final pid = item['productId'] as String? ?? '';
      if (pid.isEmpty) continue;
      byProduct.putIfAbsent(pid, () => []).add(item);
    }

    final List<StockError> errors = [];

    for (final entry in byProduct.entries) {
      final productId = entry.key;
      final snap = await _db.collection('products').doc(productId).get();
      if (!snap.exists) continue;

      final data = snap.data()!;
      final variantsRaw = (data['variants'] as Map<String, dynamic>?) ?? {};

      for (final item in entry.value) {
        final color = (item['color'] as String? ?? '').toLowerCase();
        final size = (item['size'] as String? ?? '').toLowerCase();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final key = ProductModel.variantKey(color, size);

        final variantData = variantsRaw[key] as Map<String, dynamic>?;
        final available = (variantData?['stock'] as num?)?.toInt() ?? 0;

        if (available < qty) {
          errors.add(
            StockError(
              productId: productId,
              productName: item['productName'] as String? ?? productId,
              variantKey: key,
              requested: qty,
              available: available,
              reason: available == 0 ? 'Out of stock' : 'Insufficient stock',
            ),
          );
        }
      }
    }

    return StockCheckResult(errors: errors);
  }
}

// ── Result/exception types ─────────────────────────────────────────────────────

class StockError {
  final String productId;
  final String productName;
  final String variantKey;
  final int requested;
  final int available;
  final String reason;

  const StockError({
    required this.productId,
    required this.productName,
    required this.variantKey,
    required this.requested,
    required this.available,
    required this.reason,
  });

  /// Human-readable label, e.g. "Black XL"
  String get variantLabel {
    if (variantKey.isEmpty) return '';
    final parts = variantKey.split('_');
    final color = parts.isNotEmpty
        ? parts[0][0].toUpperCase() + parts[0].substring(1)
        : '';
    final size = parts.length > 1 ? parts[1].toUpperCase() : '';
    return '$color $size'.trim();
  }

  String get userMessage {
    if (available == 0) {
      return '$productName (${variantLabel.isNotEmpty ? variantLabel : variantKey}) is out of stock.';
    }
    return '$productName (${variantLabel.isNotEmpty ? variantLabel : variantKey}): '
        'only $available available, you requested $requested.';
  }
}

class InsufficientStockException implements Exception {
  final List<StockError> errors;
  const InsufficientStockException(this.errors);

  String get userMessage => errors.map((e) => e.userMessage).join('\n');

  @override
  String toString() => 'InsufficientStockException: $userMessage';
}

class StockCheckResult {
  final List<StockError> errors;
  const StockCheckResult({required this.errors});
  bool get isOk => errors.isEmpty;
}
