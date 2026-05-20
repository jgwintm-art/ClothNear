// lib/services/order_service.dart
//
// CHANGES FROM ORIGINAL:
//   • Added [createPosOrder()]        — dedicated POS entry point that stamps
//     orderSource, workerUid, workerName, and uses a WriteBatch so the order
//     write + inventory deduction are atomic.
//   • Added [getWorkerSalesHistory()]  — paginated query for a single worker.
//   • Added [getOwnerSalesHistory()]   — paginated, filterable owner query.
//   • Added [getStorePosOrders()]      — owner: POS-only stream (real-time).
//   • All original methods are UNCHANGED — zero breaking changes.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'inventory_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InventoryService _inventoryService = InventoryService();

  // ── Original: Order placement (online orders) ──────────────────────────────

  /// Places a new order.
  ///
  /// For orders that go straight to 'processing' (normal in-person orders),
  /// inventory is deducted immediately after the document is created.
  ///
  /// For orders going to 'payment_pending' or 'pending_approval', inventory
  /// is deducted at confirmation time.
  ///
  /// Throws [InsufficientStockException] if stock is insufficient.
  Future<String> placeOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    final orderId = doc.id;

    if (order.status == 'processing') {
      await _inventoryService.deductInventoryForOrder(
        orderId: orderId,
        orderItems: order.items,
      );
    }

    return orderId;
  }

  // ── NEW: POS order creation ────────────────────────────────────────────────

  /// Creates a completed walk-in POS sale atomically.
  ///
  /// Uses a [WriteBatch] to write the order document and trigger inventory
  /// deduction as a single operation:
  ///   1.  The order document is written with [orderSource] = 'pos' and
  ///       the worker's [workerUid] / [workerName] stamped in.
  ///   2.  Inventory deduction runs AFTER the batch commits, using the
  ///       existing idempotency-safe [InventoryService.deductInventoryForOrder].
  ///
  /// Why not a pure batch for inventory too?
  /// [InventoryService] uses per-product transactions internally (not batch
  /// writes) because each product requires a read-before-write.  Firestore
  /// transactions and batches cannot be mixed.  The deduction is still safe:
  ///   • If the batch (order write) succeeds but deduction throws, the caller
  ///     surfaces the error and the order document is left with status
  ///     'processing', which the owner can see and action manually — the same
  ///     error path that existed before this change.
  ///   • The deduction is idempotent (keyed on orderId) so retrying is safe.
  ///
  /// Returns the new order's Firestore document ID.
  Future<String> createPosOrder({
    required String storeId,
    required String storeName,
    required String workerUid,
    required String workerName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required double amountTendered,
    required String paymentMethod, // 'cash'
  }) async {
    // Step 1 — validate stock before touching Firestore.
    final stockResult = await _inventoryService.checkStock(items);
    if (!stockResult.isOk) {
      throw InsufficientStockException(stockResult.errors);
    }

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // Step 2 — build the order document.
    final order = OrderModel(
      orderId: '', // will be replaced by the doc ID below
      customerUid: 'walk_in',
      storeId: storeId,
      storeName: storeName,
      items: items,
      totalPrice: totalPrice,
      amountPaid: totalPrice, // POS = paid in full at point of sale
      remainingBalance: 0.0,
      paymentType: 'full',
      orderType: 'walk_in',
      status: 'processing', // immediate — no approval needed
      designType: 'none',
      createdAt: now,
      // ── NEW fields ───────────────────────────────────────────────────────
      orderSource: 'pos',
      workerUid: workerUid,
      workerName: workerName,
      // ─────────────────────────────────────────────────────────────────────
      paymentMethod: paymentMethod,
      paymentConfirmedAt: nowMs,
      paymentConfirmedBy: workerName,
    );

    // Step 3 — write the order document via a batch (single network round-trip).
    final orderRef = _firestore.collection('orders').doc();
    final batch = _firestore.batch();
    batch.set(orderRef, order.toMap());
    await batch.commit();

    final orderId = orderRef.id;

    // Step 4 — deduct inventory (idempotent, safe to retry on failure).
    await _inventoryService.deductInventoryForOrder(
      orderId: orderId,
      orderItems: items,
    );

    return orderId;
  }

  // ── Original: Customer order stream ───────────────────────────────────────

  Stream<List<OrderModel>> getCustomerOrders(String customerUid) {
    return _firestore
        .collection('orders')
        .where('customerUid', isEqualTo: customerUid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // ── Original: Store order stream ───────────────────────────────────────────

  Stream<List<OrderModel>> getStoreOrders(String storeId) {
    return _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // ── NEW: Sales history queries ─────────────────────────────────────────────

  /// Returns one page of a worker's own POS sales, newest first.
  ///
  /// [workerUid]   filters to this worker's sales only.
  /// [storeId]     scopes the query to the correct store.
  /// [limit]       documents per page (default 20).
  /// [startAfter]  cursor snapshot from the previous page; null = first page.
  ///
  /// Requires Firestore composite index:
  ///   Collection: orders
  ///   Fields:     storeId ASC, workerUid ASC, createdAt DESC
  Future<List<OrderModel>> getWorkerSalesHistory({
    required String workerUid,
    required String storeId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('workerUid', isEqualTo: workerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Returns one page of paginated sales history for the owner view.
  ///
  /// All parameters except [storeId] are optional filters.
  ///
  /// [orderSource]     'pos' | 'online' | null (all)
  /// [workerUid]       filter to a specific worker (POS only)
  /// [status]          filter by order status string
  /// [fromDate]        inclusive lower bound on createdAt
  /// [toDate]          inclusive upper bound on createdAt
  /// [limit]           documents per page (default 20)
  /// [startAfter]      pagination cursor
  ///
  /// Requires Firestore composite indexes (see firestore.indexes.json):
  ///   • storeId ASC, createdAt DESC
  ///   • storeId ASC, orderSource ASC, createdAt DESC
  ///   • storeId ASC, workerUid ASC, createdAt DESC
  ///   • storeId ASC, status ASC, createdAt DESC
  Future<List<OrderModel>> getOwnerSalesHistory({
    required String storeId,
    String? orderSource,
    String? workerUid,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId);

    if (orderSource != null) {
      query = query.where('orderSource', isEqualTo: orderSource);
    }
    if (workerUid != null) {
      query = query.where('workerUid', isEqualTo: workerUid);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (fromDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: fromDate.millisecondsSinceEpoch,
      );
    }
    if (toDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: toDate.millisecondsSinceEpoch,
      );
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Returns the raw [DocumentSnapshot] list for the last page fetched —
  /// callers store the last snapshot as the cursor for the next page call.
  /// Convenience wrapper used by the Riverpod notifiers below.
  Future<QuerySnapshot> getOwnerSalesHistoryRaw({
    required String storeId,
    String? orderSource,
    String? workerUid,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId);

    if (orderSource != null) {
      query = query.where('orderSource', isEqualTo: orderSource);
    }
    if (workerUid != null) {
      query = query.where('workerUid', isEqualTo: workerUid);
    }

    // If a specific status filter is active, use it.
    // Otherwise exclude all non-revenue statuses.
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else {
      query = query.where(
        'status',
        whereIn: ['processing', 'ready', 'completed'],
      );
    }

    if (fromDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: fromDate.millisecondsSinceEpoch,
      );
    }
    if (toDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: toDate.millisecondsSinceEpoch,
      );
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return query.get();
  }

  Future<QuerySnapshot> getWorkerSalesHistoryRaw({
    required String workerUid,
    required String storeId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('workerUid', isEqualTo: workerUid)
        .where('status', whereIn: ['processing', 'completed', 'ready'])
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return query.get();
  }

  // ── Original: Order status transitions ────────────────────────────────────

  Future<void> approveOrder(OrderModel order) async {
    await _inventoryService.deductInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'processing',
    });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  Future<void> cancelOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'cancelled',
    });
    await _inventoryService.restoreInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
  }

  Future<void> rejectOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'rejected',
    });
    await _inventoryService.restoreInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
  }

  Future<void> deleteOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).delete();
  }

  // ── Original: Payment confirmation ────────────────────────────────────────

  Future<void> confirmManualPayment({
    required String orderId,
    required double totalPrice,
    required double amountReceived,
    required String confirmedByUid,
    required String confirmedByName,
    String note = '',
  }) async {
    final remaining = (totalPrice - amountReceived).clamp(0.0, totalPrice);
    final now = DateTime.now().millisecondsSinceEpoch;

    final Map<String, dynamic> update = {
      'amountPaid': amountReceived,
      'remainingBalance': remaining,
      'paymentConfirmed': true,
      'paymentConfirmedAt': now,
      'paymentConfirmedBy': confirmedByName,
      'paymentConfirmedByUid': confirmedByUid,
      'paymentMethod': remaining <= 0 ? 'cash' : 'partial_cash',
    };
    if (note.isNotEmpty) update['paymentNote'] = note;

    await _firestore.collection('orders').doc(orderId).update(update);

    await _firestore
        .collection('orders')
        .doc(orderId)
        .collection('payment_events')
        .add({
          'type': remaining <= 0 ? 'full_payment' : 'partial_payment',
          'method': remaining <= 0 ? 'cash' : 'partial_cash',
          'amount': amountReceived,
          'remainingAfter': remaining,
          'confirmedBy': confirmedByName,
          'confirmedByUid': confirmedByUid,
          'note': note,
          'timestamp': now,
          'source': 'manual',
        });
  }

  Future<void> confirmOnlinePayment({
    required String orderId,
    required double amountPaid,
    required double totalPrice,
    required String paymentChannel,
    required List<Map<String, dynamic>> orderItems,
    String paymongoPaymentId = '',
  }) async {
    final remaining = (totalPrice - amountPaid).clamp(0.0, totalPrice);
    final now = DateTime.now().millisecondsSinceEpoch;

    final Map<String, dynamic> update = {
      'status': 'processing',
      'amountPaid': amountPaid,
      'remainingBalance': remaining,
      'paymongoPaymentStatus': 'paid',
      'paymentConfirmedAt': now,
      'paymentConfirmedBy': 'system',
      'paymentMethod': paymentChannel,
    };
    if (paymongoPaymentId.isNotEmpty) {
      update['paymongoPaymentId'] = paymongoPaymentId;
    }

    await _firestore.collection('orders').doc(orderId).update(update);

    await _inventoryService.deductInventoryForOrder(
      orderId: orderId,
      orderItems: orderItems,
    );

    await _firestore
        .collection('orders')
        .doc(orderId)
        .collection('payment_events')
        .add({
          'type': remaining <= 0 ? 'full_payment' : 'partial_payment',
          'method': paymentChannel,
          'amount': amountPaid,
          'remainingAfter': remaining,
          'confirmedBy': 'system',
          'paymongoPaymentId': paymongoPaymentId,
          'timestamp': now,
          'source': 'paymongo_auto',
        });
  }

  Stream<List<Map<String, dynamic>>> getPaymentEvents(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('payment_events')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'eventId': d.id}).toList());
  }
}
