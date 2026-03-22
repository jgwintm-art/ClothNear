class OrderModel {
  final String orderId;
  final String customerUid;
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items;
  final double totalPrice;
  final double amountPaid;
  final double remainingBalance;
  final String paymentType; // 'full' or 'half'
  final String orderType; // 'normal', 'rush', 'bulk'
  final String
  status; // 'pending_approval', 'processing', 'ready', 'completed', 'rejected', 'cancelled'
  final String designType; // 'preset' or 'custom'
  final String designUrl;
  final String designName;
  final String specialInstructions;
  final DateTime createdAt;

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
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'createdAt': createdAt,
    };
  }

  // Helper getters
  String get statusDisplay {
    switch (status) {
      case 'pending_approval':
        return 'Pending Approval';
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
      case 'processing':
        return 0.35;
      case 'ready':
        return 0.75;
      case 'completed':
        return 1.0;
      default:
        return 0.0;
    }
  }
}
