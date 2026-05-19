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
    return m;
  }

  /// Creates a copy of this order with selected fields replaced.
  OrderModel copyWith({
    String? status,
    double? amountPaid,
    double? remainingBalance,
    String? paymongoLinkId,
    String? paymongoCheckoutUrl,
    String? paymentChannel,
    String? paymongoPaymentStatus,
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
