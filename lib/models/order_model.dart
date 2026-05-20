import 'package:flutter/foundation.dart';

class OrderModel {
  final String orderId;
  final String customerUid;
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items;
  final double totalPrice;
  final double amountPaid;
  final double remainingBalance;
  final String paymentType; // 'full' | 'half'
  final String orderType; // 'normal' | 'rush' | 'bulk' | 'walk_in'
  final String status;
  // 'pending_approval' | 'payment_pending' | 'processing' |
  // 'ready' | 'completed' | 'rejected' | 'cancelled'
  final String designType;
  final String designUrl;
  final String designName;
  final String specialInstructions;
  final DateTime createdAt;

  // ── Sales-history classification fields ─────────────────────────────────

  final String orderSource; // 'online' | 'pos'

  /// UID of the worker who processed this sale.
  /// Set only when [orderSource] == 'pos'.  Always null for online orders.
  final String? workerUid;

  /// Display name of the worker at the time of the sale (denormalized).
  /// Stored at write-time so the history list never needs a secondary lookup.
  /// Set only when [orderSource] == 'pos'.
  final String? workerName;

  // ── PayMongo fields (nullable — absent on in-person/legacy orders) ──────────
  final String? paymongoLinkId;
  final String? paymongoCheckoutUrl;
  final String? paymentChannel;
  final String? paymongoPaymentStatus;

  // ── Payment audit / tracking fields ─────────────────────────────────────────
  final int? paymentConfirmedAt;
  final String? paymentConfirmedBy;
  final String? paymentMethod;
  final String? paymongoPaymentId;
  final String? paymentNote;

  OrderModel({
    required this.orderId,
    required this.customerUid,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.totalPrice,
    required this.amountPaid,
    required this.remainingBalance,
    required this.paymentType,
    required this.orderType,
    required this.status,
    required this.designType,
    this.designUrl = '',
    this.designName = '',
    this.specialInstructions = '',
    required this.createdAt,
    // default 'online' keeps all call sites that omit this field valid.
    this.orderSource = 'online',
    this.workerUid,
    this.workerName,
    // PayMongo
    this.paymongoLinkId,
    this.paymongoCheckoutUrl,
    this.paymentChannel,
    this.paymongoPaymentStatus,
    // Payment audit
    this.paymentConfirmedAt,
    this.paymentConfirmedBy,
    this.paymentMethod,
    this.paymongoPaymentId,
    this.paymentNote,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      // Explicitly log the map data for debugging
      debugPrint('OrderModel.fromMap: Processing map for ID $id: $map');

      final String? paymentMethod = map['paymentMethod'] as String?;
      final String? paymentChannel = map['paymentChannel'] as String?;
      final String? paymongoLinkId = map['paymongoLinkId'] as String?;
      final String? paymongoCheckoutUrl = map['paymongoCheckoutUrl'] as String?;
      final String? paymongoPaymentStatus = map['paymongoPaymentStatus'] as String?;
      final String? paymentConfirmedBy = map['paymentConfirmedBy'] as String?;
      final String? paymongoPaymentId = map['paymongoPaymentId'] as String?;
      final String? paymentNote = map['paymentNote'] as String?;
      final String? workerUid = map['workerUid'] as String?;
      final String? workerName = map['workerName'] as String?;

      debugPrint('paymentMethod: $paymentMethod (is null: ${paymentMethod == null})');
      debugPrint('paymentChannel: $paymentChannel (is null: ${paymentChannel == null})');
      debugPrint('paymongoLinkId: $paymongoLinkId (is null: ${paymongoLinkId == null})');
      debugPrint('paymongoCheckoutUrl: $paymongoCheckoutUrl (is null: ${paymongoCheckoutUrl == null})');
      debugPrint('paymongoPaymentStatus: $paymongoPaymentStatus (is null: ${paymongoPaymentStatus == null})');
      debugPrint('paymentConfirmedBy: $paymentConfirmedBy (is null: ${paymentConfirmedBy == null})');
      debugPrint('paymongoPaymentId: $paymongoPaymentId (is null: ${paymongoPaymentId == null})');
      debugPrint('paymentNote: $paymentNote (is null: ${paymentNote == null})');
      debugPrint('workerUid: $workerUid (is null: ${workerUid == null})');
      debugPrint('workerName: $workerName (is null: ${workerName == null})');

      return OrderModel(
        orderId: id,
        customerUid: map['customerUid'] ?? '',
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        items: List<Map<String, dynamic>>.from(map['items'] ?? []),
        totalPrice: (map['totalPrice'] ?? 0).toDouble(),
        amountPaid: (map['amountPaid'] ?? 0).toDouble(),
        remainingBalance: (map['remainingBalance'] ?? 0).toDouble(),
        paymentType: map['paymentType'] ?? 'full',
        orderType: map['orderType'] ?? 'normal',
        status: map['status'] ?? 'processing',
        designType: map['designType'] ?? 'preset',
        designUrl: map['designUrl'] ?? '',
        designName: map['designName'] ?? '',
        specialInstructions: map['specialInstructions'] ?? '',
        createdAt: map['createdAt'] != null
            ? map['createdAt'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
                  : map['createdAt'] is DateTime
                  ? map['createdAt'] as DateTime
                  : (map['createdAt'] as dynamic).toDate()
            : DateTime.now(),
        // null-coalesce to 'online' so every legacy document is safe.
        orderSource: map['orderSource'] as String? ?? 'online',
        workerUid: workerUid,
        workerName: workerName,
        // PayMongo
        paymongoLinkId: paymongoLinkId,
        paymongoCheckoutUrl: paymongoCheckoutUrl,
        paymentChannel: paymentChannel,
        paymongoPaymentStatus: paymongoPaymentStatus,
        // Payment audit
        paymentConfirmedAt: map['paymentConfirmedAt'] as int?,
        paymentConfirmedBy: paymentConfirmedBy,
        paymentMethod: paymentMethod,
        paymongoPaymentId: paymongoPaymentId,
        paymentNote: paymentNote,
      );
    } catch (e) {
      debugPrint('OrderModel.fromMap: ERROR deserializing order ID $id. Map: $map. Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'customerUid': customerUid,
      'storeId': storeId,
      'storeName': storeName,
      'items': items,
      'totalPrice': totalPrice,
      'amountPaid': amountPaid,
      'remainingBalance': remainingBalance,
      'paymentType': paymentType,
      'orderType': orderType,
      'status': status,
      'designType': designType,
      'designUrl': designUrl,
      'designName': designName,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'orderSource': orderSource,
    };

    // POS worker fields — only write for POS orders to keep online docs clean.
    if (workerUid != null) m['workerUid'] = workerUid;
    if (workerName != null) m['workerName'] = workerName;

    // PayMongo fields
    if (paymongoLinkId != null) m['paymongoLinkId'] = paymongoLinkId;
    if (paymongoCheckoutUrl != null) {
      m['paymongoCheckoutUrl'] = paymongoCheckoutUrl;
    }
    if (paymentChannel != null) m['paymentChannel'] = paymentChannel;
    if (paymongoPaymentStatus != null) {
      m['paymongoPaymentStatus'] = paymongoPaymentStatus;
    }

    // Payment audit fields
    if (paymentConfirmedAt != null) {
      m['paymentConfirmedAt'] = paymentConfirmedAt;
    }
    if (paymentConfirmedBy != null) {
      m['paymentConfirmedBy'] = paymentConfirmedBy;
    }
    if (paymentMethod != null) m['paymentMethod'] = paymentMethod;
    if (paymongoPaymentId != null) m['paymongoPaymentId'] = paymongoPaymentId;
    if (paymentNote != null) m['paymentNote'] = paymentNote;

    return m;
  }

  OrderModel copyWith({
    String? status,
    double? amountPaid,
    double? remainingBalance,
    String? orderSource,
    String? workerUid,
    String? workerName,
    String? paymongoLinkId,
    String? paymongoCheckoutUrl,
    String? paymentChannel,
    String? paymongoPaymentStatus,
    int? paymentConfirmedAt,
    String? paymentConfirmedBy,
    String? paymentMethod,
    String? paymongoPaymentId,
    String? paymentNote,
  }) {
    return OrderModel(
      orderId: orderId,
      customerUid: customerUid,
      storeId: storeId,
      storeName: storeName,
      items: items,
      totalPrice: totalPrice,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      paymentType: paymentType,
      orderType: orderType,
      status: status ?? this.status,
      designType: designType,
      designUrl: designUrl,
      designName: designName,
      specialInstructions: specialInstructions,
      createdAt: createdAt,
      orderSource: orderSource ?? this.orderSource,
      workerUid: workerUid ?? this.workerUid,
      workerName: workerName ?? this.workerName,
      paymongoLinkId: paymongoLinkId ?? this.paymongoLinkId,
      paymongoCheckoutUrl: paymongoCheckoutUrl ?? this.paymongoCheckoutUrl,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      paymongoPaymentStatus:
          paymongoPaymentStatus ?? this.paymongoPaymentStatus,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      paymentConfirmedBy: paymentConfirmedBy ?? this.paymentConfirmedBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymongoPaymentId: paymongoPaymentId ?? this.paymongoPaymentId,
      paymentNote: paymentNote ?? this.paymentNote,
    );
  }

  // ── Display helpers ──────────────────────────────────────────────────────────

  /// True when this order was processed at a POS terminal by a worker.
  bool get isPosOrder => orderSource == 'pos';

  /// True when this is a customer-placed online order.
  bool get isOnlineOrder => orderSource == 'online';

  String get statusDisplay {
    switch (status) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'payment_pending':
        return 'Awaiting Payment';
      case 'processing':
        return 'Processing';
      case 'ready':
        return 'Ready for Pickup';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  double get progressValue {
    switch (status) {
      case 'pending_approval':
        return 0.1;
      case 'payment_pending':
        return 0.2;
      case 'processing':
        return 0.45;
      case 'ready':
        return 0.75;
      case 'completed':
        return 1.0;
      default:
        return 0.0;
    }
  }

  bool get isOnlinePayment {
    final id = paymongoLinkId;
    return id != null && id.isNotEmpty;
  }

  bool get isPaymentConfirmed =>
      isOnlinePayment ? paymongoPaymentStatus == 'paid' : remainingBalance <= 0;

  String get paymentMethodDisplay {
    // Safely handle null paymentMethod before switching.
    // If paymentMethod is null, it's an in-person cash payment by default.
    final method = paymentMethod ?? 'cash';

    switch (method) {
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'Maya';
      case 'card':
        return 'Card';
      case 'cash':
        return 'Cash';
      case 'partial_cash':
        return 'Cash (Partial)';
      default:
        // Fallback for any unexpected string values, defaults to cash
        return 'In-Person / Cash';
    }
  }

  String get resolvedPaymentStatus {
    if (status == 'payment_pending') return 'pending_online';
    if (status == 'cancelled' || status == 'rejected') return 'void';
    if (isPaymentConfirmed && remainingBalance <= 0) return 'paid';
    if (amountPaid > 0 && remainingBalance > 0) return 'partial';
    if (!isPaymentConfirmed && remainingBalance > 0) return 'unpaid';
    return 'unpaid';
  }

  String get resolvedPaymentStatusDisplay {
    switch (resolvedPaymentStatus) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partially Paid';
      case 'pending_online':
        return 'Awaiting Online Payment';
      case 'unpaid':
        return 'Unpaid';
      case 'void':
        return 'Void';
      default:
        return 'Unknown';
    }
  }

  DateTime? get paymentConfirmedAtDateTime => paymentConfirmedAt != null
      ? DateTime.fromMillisecondsSinceEpoch(paymentConfirmedAt!)
      : null;

  String get paymentChannelDisplay {
    switch (paymentChannel ?? '') { // Handle null paymentChannel
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'Maya';
      case 'card':
        return 'Card';
      default:
        return 'In-Person';
    }
  }
}
