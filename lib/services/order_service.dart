import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Place a new order
  Future<String> placeOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    return doc.id;
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

  // Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
    });
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'cancelled',
    });
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

  /// Records an automatic PayMongo payment confirmation in the audit log.
  /// Called by [PaymentPendingScreen] after polling confirms 'paid'.
  Future<void> confirmOnlinePayment({
    required String orderId,
    required double amountPaid,
    required double totalPrice,
    required String paymentChannel,
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
