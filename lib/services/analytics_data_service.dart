import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/worker_model.dart';

/// Aggregates Firestore data needed for analytics (client-side filtering).
class AnalyticsDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _orderFetchLimit = 250;

  Future<List<ProductModel>> fetchProducts(String storeId) async {
    final snap = await _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .get();
    return snap.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList();
  }

  Future<List<OrderModel>> fetchStoreOrders(String storeId) async {
    final snap = await _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .limit(_orderFetchLimit)
        .get();
    final orders = snap.docs
        .map((d) => OrderModel.fromMap(d.data(), d.id))
        .toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<List<WorkerModel>> fetchActiveWorkers(String ownerUid) async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('ownerUid', isEqualTo: ownerUid)
        .get();
    return snap.docs
        .map((d) => WorkerModel.fromMap(d.data(), d.id))
        .where((w) => w.isActive)
        .toList();
  }

  /// Variant key → units sold in [since, now].
  Map<String, int> aggregateVariantSales(
    List<OrderModel> orders, {
    required DateTime since,
    String? productIdFilter,
  }) {
    final sales = <String, int>{};
    for (final order in orders) {
      if (order.createdAt.isBefore(since)) continue;
      if (_isCancelledOrRejected(order.status)) continue;
      for (final item in order.items) {
        final pid = item['productId'] as String? ?? '';
        if (productIdFilter != null && pid != productIdFilter) continue;
        final color = (item['color'] as String? ?? '').toLowerCase();
        final size = (item['size'] as String? ?? '').toLowerCase();
        final key = '${color}_$size';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        sales[key] = (sales[key] ?? 0) + qty;
      }
    }
    return sales;
  }

  /// productId → { units, revenue }
  Map<String, Map<String, dynamic>> aggregateProductSales(
    List<OrderModel> orders, {
    required DateTime since,
  }) {
    final byProduct = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      if (order.createdAt.isBefore(since)) continue;
      if (_isCancelledOrRejected(order.status)) continue;
      for (final item in order.items) {
        final pid = item['productId'] as String? ?? '';
        final name = item['productName'] as String? ?? 'Unknown';
        final key = pid.isNotEmpty ? pid : name;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final lineTotal =
            (item['totalPrice'] as num?)?.toDouble() ??
            ((item['price'] as num?)?.toDouble() ?? 0) * qty;
        byProduct.putIfAbsent(
          key,
          () => {'units': 0, 'revenue': 0.0, 'name': name},
        );
        byProduct[key]!['units'] = (byProduct[key]!['units'] ?? 0) + qty;
        byProduct[key]!['revenue'] =
            (byProduct[key]!['revenue'] ?? 0) + lineTotal;
      }
    }
    return byProduct;
  }

  List<OrderModel> activeProductionOrders(List<OrderModel> orders) {
    const active = {'pending_approval', 'processing', 'ready'};
    return orders.where((o) => active.contains(o.status)).toList();
  }

  bool _isCancelledOrRejected(String status) {
    return status == 'cancelled' || status == 'rejected';
  }
}
