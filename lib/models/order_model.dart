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
  final String orderType; // 'normal' | 'rush' | 'bulk'
  final String status;
  // 'pending_approval' | 'payment_pending' | 'processing' |
  // 'ready' | 'completed' | 'rejected' | 'cancelled'
  final String designType;
  final String designUrl;
  final String designName;
  final String specialInstructions;
  final DateTime createdAt;

  // ── PayMongo fields (nullable — absent on in-person/legacy orders) ──────────
  /// The PayMongo Link ID (e.g. "link_xxxx"). Used to poll payment status.
  final String? paymongoLinkId;

  /// The hosted checkout URL the customer opens to pay.
  final String? paymongoCheckoutUrl;

  /// Payment channel chosen by customer: 'gcash' | 'paymaya' | 'card' | null
  final String? paymentChannel;

  /// PayMongo payment status: 'unpaid' | 'paid' | 'failed' | null
  /// null = not an online payment (in-person order)
  final String? paymongoPaymentStatus;

  // ── Payment audit / tracking fields ─────────────────────────────────────────

  /// ISO timestamp (ms epoch) when payment was confirmed (auto or manual).
  final int? paymentConfirmedAt;

  /// UID or display name of the staff member who confirmed a manual payment.
  /// 'system' for auto-confirmed PayMongo payments.
  final String? paymentConfirmedBy;

  /// Human-readable method: 'gcash' | 'paymaya' | 'card' | 'cash' | 'partial_cash'
  /// Distinct from [paymentChannel] (which is the PayMongo channel enum).
  final String? paymentMethod;

  /// PayMongo payment object ID (e.g. 'pay_xxxx') returned by the webhook/poll.
  /// Immutable once set — provides a permanent audit reference.
  final String? paymongoPaymentId;

  /// Optional note added by staff when confirming a manual/cash payment.
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
    // PayMongo — all optional, null-safe
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
      // PayMongo — gracefully null on existing documents
      paymongoLinkId: map['paymongoLinkId'] as String?,
      paymongoCheckoutUrl: map['paymongoCheckoutUrl'] as String?,
      paymentChannel: map['paymentChannel'] as String?,
      paymongoPaymentStatus: map['paymongoPaymentStatus'] as String?,
      // Payment audit
      paymentConfirmedAt: map['paymentConfirmedAt'] as int?,
      paymentConfirmedBy: map['paymentConfirmedBy'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      paymongoPaymentId: map['paymongoPaymentId'] as String?,
      paymentNote: map['paymentNote'] as String?,
    );
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
    };
    // Only write PayMongo fields when they have values — keeps existing
    // in-person order documents clean.
    if (paymongoLinkId != null) m['paymongoLinkId'] = paymongoLinkId;
    if (paymongoCheckoutUrl != null) {
      m['paymongoCheckoutUrl'] = paymongoCheckoutUrl;
    }
    if (paymentChannel != null) m['paymentChannel'] = paymentChannel;
    if (paymongoPaymentStatus != null) {
      m['paymongoPaymentStatus'] = paymongoPaymentStatus;
    }
    // Payment audit fields — only write when present
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

  bool get isOnlinePayment =>
      paymongoLinkId != null && paymongoLinkId!.isNotEmpty;

  bool get isPaymentConfirmed =>
      isOnlinePayment ? paymongoPaymentStatus == 'paid' : remainingBalance <= 0;

  /// Resolved payment method label for display in dashboards.
  String get paymentMethodDisplay {
    if (paymentMethod != null) {
      switch (paymentMethod) {
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
      }
    }
    // Fallback: derive from paymentChannel / isOnlinePayment
    if (isOnlinePayment) return paymentChannelDisplay;
    return 'In-Person / Cash';
  }

  /// Derived payment status for owner/worker dashboards.
  /// More granular than [paymongoPaymentStatus].
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
    switch (paymentChannel) {
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
