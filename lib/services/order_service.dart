import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'inventory_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InventoryService _inventoryService = InventoryService();

  // ── Order placement ────────────────────────────────────────────────────────

  /// Places a new order.
  ///
  /// For orders that go straight to 'processing' (normal in-person orders),
  /// inventory is deducted immediately after the document is created.
  ///
  /// For orders going to 'payment_pending' or 'pending_approval', inventory
  /// is deducted at confirmation time (see [confirmOnlinePayment] and
  /// [approveOrder]).
  ///
  /// Throws [InsufficientStockException] if stock is insufficient —
  /// the caller (CheckoutScreen) should surface this before order creation.
  Future<String> placeOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    final orderId = doc.id;

    // Deduct immediately only for normal in-person orders that skip approval
    // and skip payment_pending (i.e. status is already 'processing').
    if (order.status == 'processing') {
      await _inventoryService.deductInventoryForOrder(
        orderId: orderId,
        orderItems: order.items,
      );
    }

    return orderId;
  }

  // Get orders for a customer
  Stream<List<OrderModel>> getCustomerOrders(String customerUid) {
    return _firestore
        .collection('orders')
        .where('customerUid', isEqualTo: customerUid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort locally to avoid needing a Firestore index
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // Get orders for a store
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

  // ── Order status transitions ────────────────────────────────────────────────

  /// Approves a pending_approval order:
  ///   - Deducts inventory (atomic, idempotent, oversell-safe).
  ///   - Sets status to 'processing'.
  ///
  /// Throws [InsufficientStockException] if stock is insufficient.
  /// In that case the order status is NOT changed.
  Future<void> approveOrder(OrderModel order) async {
    // Deduct inventory first — if this throws, the order stays pending.
    await _inventoryService.deductInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
    // Only update status after inventory is secured.
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'processing',
    });
  }

  /// Updates order status to an arbitrary value (ready, completed, etc.).
  /// Does NOT touch inventory — use [approveOrder] for approval,
  /// [cancelOrder] / [rejectOrder] for cancellations.
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  /// Cancels an order and restores inventory if it had been deducted.
  /// Safe to call on pending_approval / payment_pending orders too —
  /// restore is a no-op if the order was never deducted.
  Future<void> cancelOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'cancelled',
    });
    await _inventoryService.restoreInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
  }

  /// Rejects a pending_approval order.
  /// Restores stock as a safety net (no-op if never deducted).
  Future<void> rejectOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).update({
      'status': 'rejected',
    });
    await _inventoryService.restoreInventoryForOrder(
      orderId: order.orderId,
      orderItems: order.items,
    );
  }

  // Delete a completed/cancelled/rejected order
  Future<void> deleteOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).delete();
  }

  // ── Payment confirmation with full audit trail ─────────────────────────────

  /// Confirms a manual (in-person/cash) payment for an order.
  ///
  /// [orderId]       Firestore document ID of the order.
  /// [amountReceived] Amount the staff member collected (may be full or partial).
  /// [confirmedByUid] UID of the staff member pressing confirm.
  /// [confirmedByName] Display name for the audit log.
  /// [note]           Optional note (e.g. "Customer paid in full at pickup").
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

    // Append to payment_events sub-collection for immutable audit log
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

  /// Records an automatic PayMongo payment confirmation in the audit log
  /// and deducts inventory for the confirmed order.
  /// Called by [PaymentPendingScreen] after polling confirms 'paid'.
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

    // Deduct inventory — idempotent: safe even if called twice.
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

  /// Reads the immutable payment_events log for an order (newest first).
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
