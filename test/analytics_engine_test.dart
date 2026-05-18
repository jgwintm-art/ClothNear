import 'package:flutter_test/flutter_test.dart';
import 'package:clothnear/models/analytics_models.dart';
import 'package:clothnear/models/order_model.dart';
import 'package:clothnear/models/product_model.dart';
import 'package:clothnear/models/store_operations_model.dart';
import 'package:clothnear/models/worker_model.dart';
import 'package:clothnear/services/analytics_engine_service.dart';

void main() {
  final engine = AnalyticsEngineService();

  ProductModel sampleProduct() {
    return ProductModel(
      productId: 'p1',
      storeId: 's1',
      name: 'Basic Tee',
      type: 'shirt',
      colors: ['black'],
      sizes: ['m'],
      basePrice: 200,
      variants: {
        'black_m': ProductVariant(price: 250, stock: 2),
      },
    );
  }

  OrderModel sampleOrder({
    String status = 'processing',
    int qty = 10,
    DateTime? createdAt,
  }) {
    return OrderModel(
      orderId: 'o1',
      customerUid: 'c1',
      storeId: 's1',
      storeName: 'Shop',
      items: [
        {
          'productId': 'p1',
          'productName': 'Basic Tee',
          'color': 'black',
          'size': 'm',
          'quantity': qty,
          'price': 250,
          'totalPrice': 250.0 * qty,
          'isPlain': true,
        },
      ],
      totalPrice: 250.0 * qty,
      amountPaid: 250.0 * qty,
      remainingBalance: 0,
      paymentType: 'full',
      orderType: 'normal',
      status: status,
      designType: 'preset',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  test('flags low stock and suggests restock', () {
    final report = engine.buildReport(
      products: [sampleProduct()],
      orders: [sampleOrder(qty: 15)],
      workers: [
        WorkerModel(
          uid: 'w1',
          name: 'Ana',
          email: 'a@test.com',
          storeId: 's1',
          permissions: const {},
          createdAt: DateTime.now(),
          createdBy: 'owner',
        ),
      ],
      operations: const StoreOperationsModel(lowStockThreshold: 5),
    );

    expect(report.inventory.alerts, isNotEmpty);
    expect(report.inventory.alerts.first.urgency, isNot(RestockUrgency.low));
    expect(report.workforce.activeOrderCount, 1);
    expect(report.printers.configuredPrinterCount, 1);
  });

  test('workforce insufficient when queue exceeds capacity', () {
    final report = engine.buildReport(
      products: [sampleProduct()],
      orders: [sampleOrder(qty: 200)],
      workers: [],
      operations: const StoreOperationsModel(),
    );

    expect(report.workforce.insufficientWorkforce, isTrue);
    expect(report.workforce.suggestedWorkerCount, greaterThan(0));
  });

  test('seasonal forecast returns monthly points', () {
    final orders = List.generate(
      5,
      (i) => sampleOrder(
        createdAt: DateTime.now().subtract(Duration(days: 30 * i)),
      ),
    );

    final report = engine.buildReport(
      products: [sampleProduct()],
      orders: orders,
      workers: [],
      operations: const StoreOperationsModel(),
    );

    expect(report.seasonal.historicalMonthly.length, 12);
    expect(report.seasonal.forecastMonthly.length, 3);
  });
}
