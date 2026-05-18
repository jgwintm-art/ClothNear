import 'package:intl/intl.dart';
import '../models/analytics_models.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/store_operations_model.dart';
import '../models/worker_model.dart';
import 'analytics_data_service.dart';

/// Rule-based analytics engine — always available without Gemini.
class AnalyticsEngineService {
  final AnalyticsDataService _data = AnalyticsDataService();

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  ShopAnalyticsReport buildReport({
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required List<WorkerModel> workers,
    required StoreOperationsModel operations,
  }) {
    final now = DateTime.now();
    final since30 = now.subtract(const Duration(days: 30));
    final since90 = now.subtract(const Duration(days: 90));

    final inventory = _buildInventoryInsights(
      products: products,
      orders: orders,
      since30: since30,
      since90: since90,
      threshold: operations.lowStockThreshold,
    );

    final activeOrders = _data.activeProductionOrders(orders);
    final workforce = _buildWorkforceInsights(
      orders: activeOrders,
      workers: workers,
      operations: operations,
      now: now,
    );

    final printers = _buildPrinterInsights(
      orders: activeOrders,
      operations: operations,
    );

    final seasonal = _buildSeasonalInsights(
      products: products,
      orders: orders,
      now: now,
    );

    final risks = _buildRiskAlerts(
      inventory: inventory,
      workforce: workforce,
      printers: printers,
      seasonal: seasonal,
    );

    final actions = _buildRecommendedActions(
      inventory: inventory,
      workforce: workforce,
      printers: printers,
      seasonal: seasonal,
    );

    final summary = _buildInsightsSummary(
      inventory: inventory,
      workforce: workforce,
      printers: printers,
      seasonal: seasonal,
      riskCount: risks.length,
    );

    return ShopAnalyticsReport(
      inventory: inventory,
      workforce: workforce,
      printers: printers,
      seasonal: seasonal,
      risks: risks,
      recommendedActions: actions,
      insightsSummary: summary,
      generatedAt: now,
    );
  }

  InventoryInsights _buildInventoryInsights({
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required DateTime since30,
    required DateTime since90,
    required int threshold,
  }) {
    final alerts = <LowStockAlert>[];
    var lowCount = 0;
    var outCount = 0;

    for (final product in products) {
      final sales30 = _data.aggregateVariantSales(
        orders,
        since: since30,
        productIdFilter: product.productId,
      );
      final sales90 = _data.aggregateVariantSales(
        orders,
        since: since90,
        productIdFilter: product.productId,
      );

      product.variants.forEach((variantKey, variant) {
        if (variant.stock == 0) {
          outCount++;
        } else if (variant.stock <= threshold) {
          lowCount++;
        }

        if (variant.stock > threshold) return;

        final sold30 = sales30[variantKey] ?? 0;
        final sold90 = sales90[variantKey] ?? 0;
        final weeklyVelocity = sold30 > 0 ? sold30 / 4.0 : sold90 / 12.0;
        final targetWeeksCover = 4;
        final suggestedQty = (weeklyVelocity * targetWeeksCover - variant.stock)
            .ceil()
            .clamp(0, 999);
        final restockQty = suggestedQty < 1 && variant.stock == 0
            ? (weeklyVelocity.ceil().clamp(5, 50))
            : suggestedQty.clamp(
                variant.stock == 0 ? 5 : 1,
                200,
              );

        final urgency = _restockUrgency(
          stock: variant.stock,
          sold30: sold30,
          threshold: threshold,
        );

        if (urgency == null) return;

        alerts.add(
          LowStockAlert(
            productId: product.productId,
            productName: product.name,
            variantKey: variantKey,
            displayLabel: _variantLabel(variantKey),
            currentStock: variant.stock,
            suggestedRestockQty: restockQty,
            urgency: urgency,
            unitsSoldLast30Days: sold30,
            reason: variant.stock == 0
                ? 'Out of stock'
                : 'Below $threshold units with ${sold30 > 0 ? 'active' : 'limited'} demand',
          ),
        );
      });
    }

    alerts.sort((a, b) {
      final order = {
        RestockUrgency.critical: 0,
        RestockUrgency.high: 1,
        RestockUrgency.medium: 2,
        RestockUrgency.low: 3,
      };
      return (order[a.urgency] ?? 9).compareTo(order[b.urgency] ?? 9);
    });

    final productSales = _data.aggregateProductSales(orders, since: since30);
    final trending = productSales.entries.map((e) {
      final name = e.value['name']?.toString() ?? e.key;
      final units = (e.value['units'] as num?)?.toInt() ?? 0;
      final revenue = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return TrendingProduct(
        productId: e.key,
        productName: name,
        unitsSold: units,
        revenue: revenue,
        trendLabel: units >= 20
            ? 'Hot'
            : units >= 8
                ? 'Rising'
                : 'Steady',
      );
    }).toList()
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    final summary = products.isEmpty
        ? 'No products in inventory yet.'
        : '$outCount variant(s) out of stock, $lowCount low. '
            '${trending.isNotEmpty ? 'Top seller: ${trending.first.productName}.' : 'Build sales history to improve forecasts.'}';

    return InventoryInsights(
      alerts: alerts,
      trendingProducts: trending.take(8).toList(),
      totalLowStockVariants: lowCount,
      totalOutOfStockVariants: outCount,
      summary: summary,
    );
  }

  RestockUrgency? _restockUrgency({
    required int stock,
    required int sold30,
    required int threshold,
  }) {
    if (stock == 0) return RestockUrgency.critical;
    if (stock <= threshold && sold30 >= 10) return RestockUrgency.high;
    if (stock <= threshold && sold30 >= 3) return RestockUrgency.medium;
    if (stock <= threshold) return RestockUrgency.low;
    return null;
  }

  WorkforceInsights _buildWorkforceInsights({
    required List<OrderModel> orders,
    required List<WorkerModel> workers,
    required StoreOperationsModel operations,
    required DateTime now,
  }) {
    var units = 0;
    var minutes = 0.0;

    for (final order in orders) {
      final complexity = _orderComplexityMultiplier(order);
      for (final item in order.items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        units += qty;
        final isCustom =
            item['isPlain'] == false ||
            ((item['customDesignUrl'] as String?)?.isNotEmpty ?? false);
        final perItem = isCustom
            ? operations.avgMinutesPerCustomItem
            : operations.avgMinutesPerItem;
        minutes += qty * perItem * complexity;
      }
    }

    final activeWorkers = workers.length;
    final capacityPerWorker = operations.workerDailyCapacityMinutes;
    final effectiveCapacity = activeWorkers > 0
        ? activeWorkers * capacityPerWorker
        : capacityPerWorker;
    final suggestedWorkers = minutes <= 0
        ? activeWorkers.clamp(1, 99)
        : (minutes / capacityPerWorker).ceil().clamp(1, 99);

    final insufficient = activeWorkers < suggestedWorkers && units > 0;
    final imbalance = activeWorkers > 0 &&
        suggestedWorkers > activeWorkers + 1;

    DateTime? completion;
    if (minutes > 0 && effectiveCapacity > 0) {
      final daysNeeded = minutes / effectiveCapacity;
      completion = now.add(
        Duration(minutes: (daysNeeded * 24 * 60).round()),
      );
    }

    String? hiring;
    if (insufficient) {
      final gap = suggestedWorkers - activeWorkers;
      hiring =
          'Consider adding $gap worker${gap > 1 ? 's' : ''} to meet current production queue.';
    }

    final summary = activeWorkers == 0
        ? 'No active workers — assign staff before peak orders.'
        : '$activeWorkers worker(s) handling $units unit(s) across ${orders.length} active order(s).';

    return WorkforceInsights(
      activeWorkerCount: activeWorkers,
      suggestedWorkerCount: suggestedWorkers,
      activeOrderCount: orders.length,
      pendingWorkloadUnits: units,
      estimatedProductionMinutes: minutes,
      estimatedCompletionTime: completion,
      insufficientWorkforce: insufficient,
      workloadImbalance: imbalance,
      hiringRecommendation: hiring,
      summary: summary,
    );
  }

  PrinterInsights _buildPrinterInsights({
    required List<OrderModel> orders,
    required StoreOperationsModel operations,
  }) {
    var queueUnits = 0;
    var queueMinutes = 0.0;

    for (final order in orders) {
      final complexity = _orderComplexityMultiplier(order);
      for (final item in order.items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        queueUnits += qty;
        queueMinutes +=
            qty * operations.avgMinutesPerItem * 0.85 * complexity;
      }
    }

    final printerCount = operations.printerCount.clamp(1, 99);
    final dailyCapacity =
        printerCount * operations.printerDailyCapacityMinutes;
    final utilization = dailyCapacity > 0
        ? ((queueMinutes / dailyCapacity) * 100).clamp(0, 200)
        : 0.0;

    final suggestedPrinters = queueMinutes <= 0
        ? printerCount
        : (queueMinutes / operations.printerDailyCapacityMinutes)
            .ceil()
            .clamp(1, 20);

    final shortage = suggestedPrinters > printerCount && queueUnits > 0;
    final bottleneck = utilization >= 85;

    String? procurement;
    if (shortage) {
      procurement =
          'Add ${suggestedPrinters - printerCount} printer(s) to reduce queue backlog.';
    } else if (bottleneck) {
      procurement = 'Printers are near full utilization — stagger rush/bulk jobs.';
    }

    final summary = queueUnits == 0
        ? 'No print queue backlog.'
        : '$queueUnits unit(s) queued (~${queueMinutes.round()} min) across $printerCount printer(s).';

    return PrinterInsights(
      configuredPrinterCount: printerCount,
      suggestedPrinterCount: suggestedPrinters,
      queuedPrintJobsUnits: queueUnits,
      estimatedPrintQueueMinutes: queueMinutes,
      utilizationPercent: utilization.toDouble(),
      printerShortage: shortage,
      productionBottleneck: bottleneck,
      procurementRecommendation: procurement,
      summary: summary,
    );
  }

  SeasonalInsights _buildSeasonalInsights({
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required DateTime now,
  }) {
    final historical = <MonthlyDemandPoint>[];
    for (var i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 1);
      var orderCount = 0;
      var units = 0;
      var revenue = 0.0;

      for (final order in orders) {
        if (order.createdAt.isBefore(start) || !order.createdAt.isBefore(end)) {
          continue;
        }
        if (order.status == 'cancelled' || order.status == 'rejected') {
          continue;
        }
        orderCount++;
        revenue += order.totalPrice;
        for (final item in order.items) {
          units += (item['quantity'] as num?)?.toInt() ?? 1;
        }
      }

      historical.add(
        MonthlyDemandPoint(
          year: monthDate.year,
          month: monthDate.month,
          label: '${_monthLabels[monthDate.month - 1]} ${monthDate.year}',
          orderCount: orderCount,
          unitsSold: units,
          revenue: revenue,
        ),
      );
    }

    final recent = historical.length >= 3
        ? historical.sublist(historical.length - 3)
        : historical;
    final avgOrders = recent.isEmpty
        ? 0.0
        : recent.map((e) => e.orderCount).reduce((a, b) => a + b) /
            recent.length;
    final avgUnits = recent.isEmpty
        ? 0.0
        : recent.map((e) => e.unitsSold).reduce((a, b) => a + b) /
            recent.length;

    final forecast = <MonthlyDemandPoint>[];
    for (var f = 1; f <= 3; f++) {
      final fd = DateTime(now.year, now.month + f, 1);
      forecast.add(
        MonthlyDemandPoint(
          year: fd.year,
          month: fd.month,
          label: '${_monthLabels[fd.month - 1]} ${fd.year}',
          orderCount: avgOrders.round(),
          unitsSold: avgUnits.round(),
          revenue: recent.isEmpty
              ? 0
              : recent.map((e) => e.revenue).reduce((a, b) => a + b) /
                  recent.length,
        ),
      );
    }

    final sortedHist = [...historical]
      ..sort((a, b) => b.orderCount.compareTo(a.orderCount));
    final peakLabels = sortedHist
        .where((p) => p.orderCount > 0)
        .take(3)
        .map((p) => p.label)
        .toList();

    final since90 = now.subtract(const Duration(days: 90));
    final productSales =
        _data.aggregateProductSales(orders, since: since90);
    final forecasts = productSales.entries.map((e) {
      final name = e.value['name']?.toString() ?? e.key;
      final units = (e.value['units'] as num?)?.toInt() ?? 0;
      final predicted = (units / 3).ceil();
      return SeasonalProductForecast(
        productId: e.key,
        productName: name,
        predictedUnits: predicted,
        rationale: 'Based on $units units sold in the last 90 days',
      );
    }).toList()
      ..sort((a, b) => b.predictedUnits.compareTo(a.predictedUnits));

    final suggestions = <String>[];
    if (peakLabels.isNotEmpty) {
      suggestions.add(
        'Peak demand observed in ${peakLabels.join(', ')} — pre-stock bestsellers 2–3 weeks ahead.',
      );
    }
    if (forecasts.isNotEmpty) {
      suggestions.add(
        'Increase inventory for ${forecasts.first.productName} before next forecast month.',
      );
    }
    if (products.isNotEmpty && orders.length < 10) {
      suggestions.add(
        'Limited order history — forecasts will improve as more orders complete.',
      );
    }

    final summary = orders.isEmpty
        ? 'No historical orders yet for seasonal forecasting.'
        : 'Average ${avgOrders.toStringAsFixed(1)} orders/month (last 3 months).';

    return SeasonalInsights(
      historicalMonthly: historical,
      forecastMonthly: forecast,
      peakPeriodLabels: peakLabels,
      highDemandProducts: forecasts.take(5).toList(),
      seasonalInventorySuggestions: suggestions,
      summary: summary,
    );
  }

  List<OperationalRiskAlert> _buildRiskAlerts({
    required InventoryInsights inventory,
    required WorkforceInsights workforce,
    required PrinterInsights printers,
    required SeasonalInsights seasonal,
  }) {
    final risks = <OperationalRiskAlert>[];

    if (inventory.totalOutOfStockVariants > 0) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.critical,
          title: 'Stockouts',
          message:
              '${inventory.totalOutOfStockVariants} variant(s) are out of stock — you may lose sales.',
          category: 'inventory',
        ),
      );
    }

    if (workforce.insufficientWorkforce) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.critical,
          title: 'Understaffed',
          message: workforce.hiringRecommendation ??
              'Production queue exceeds current workforce capacity.',
          category: 'workforce',
        ),
      );
    }

    if (printers.printerShortage) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.warning,
          title: 'Printer capacity',
          message: printers.procurementRecommendation ??
              'Print queue may delay order fulfillment.',
          category: 'printers',
        ),
      );
    }

    if (printers.productionBottleneck) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.warning,
          title: 'Production bottleneck',
          message:
              'Printer utilization at ${printers.utilizationPercent.toStringAsFixed(0)}% of daily capacity.',
          category: 'printers',
        ),
      );
    }

    if (workforce.workloadImbalance) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.info,
          title: 'Workload imbalance',
          message:
              'Suggested ${workforce.suggestedWorkerCount} workers vs ${workforce.activeWorkerCount} active.',
          category: 'workforce',
        ),
      );
    }

    if (seasonal.peakPeriodLabels.isNotEmpty &&
        inventory.trendingProducts.isNotEmpty) {
      risks.add(
        OperationalRiskAlert(
          severity: RiskSeverity.info,
          title: 'Seasonal demand',
          message:
              'Prepare for peaks in ${seasonal.peakPeriodLabels.first} — trending: ${inventory.trendingProducts.first.productName}.',
          category: 'seasonal',
        ),
      );
    }

    return risks;
  }

  List<RecommendedAction> _buildRecommendedActions({
    required InventoryInsights inventory,
    required WorkforceInsights workforce,
    required PrinterInsights printers,
    required SeasonalInsights seasonal,
  }) {
    final actions = <RecommendedAction>[];

    final criticalAlerts =
        inventory.alerts.where((a) => a.urgency == RestockUrgency.critical);
    if (criticalAlerts.isNotEmpty) {
      final first = criticalAlerts.first;
      actions.add(
        RecommendedAction(
          title: 'Restock ${first.productName}',
          description:
              '${first.displayLabel}: order ~${first.suggestedRestockQty} units immediately.',
          priority: 'high',
        ),
      );
    }

    if (workforce.hiringRecommendation != null) {
      actions.add(
        RecommendedAction(
          title: 'Review staffing',
          description: workforce.hiringRecommendation!,
          priority: 'high',
        ),
      );
    }

    if (printers.procurementRecommendation != null) {
      actions.add(
        RecommendedAction(
          title: 'Printer capacity',
          description: printers.procurementRecommendation!,
          priority: 'medium',
        ),
      );
    }

    for (final suggestion in seasonal.seasonalInventorySuggestions.take(2)) {
      actions.add(
        RecommendedAction(
          title: 'Seasonal prep',
          description: suggestion,
          priority: 'medium',
        ),
      );
    }

    if (inventory.trendingProducts.isNotEmpty) {
      final top = inventory.trendingProducts.first;
      actions.add(
        RecommendedAction(
          title: 'Promote trending item',
          description:
              '${top.productName} sold ${top.unitsSold} units (30d) — ensure stock and visibility.',
          priority: 'low',
        ),
      );
    }

    return actions;
  }

  String _buildInsightsSummary({
    required InventoryInsights inventory,
    required WorkforceInsights workforce,
    required PrinterInsights printers,
    required SeasonalInsights seasonal,
    required int riskCount,
  }) {
    final parts = <String>[
      inventory.summary,
      workforce.summary,
      printers.summary,
      seasonal.summary,
    ];
    if (riskCount > 0) {
      parts.add('$riskCount operational risk(s) detected.');
    }
    return parts.join(' ');
  }

  double _orderComplexityMultiplier(OrderModel order) {
    switch (order.orderType) {
      case 'rush':
        return 1.5;
      case 'bulk':
        return 2.0;
      default:
        return 1.0;
    }
  }

  String _variantLabel(String variantKey) {
    final parts = variantKey.split('_');
    if (parts.isEmpty) return variantKey;
    final color = parts.first.isNotEmpty
        ? parts.first[0].toUpperCase() + parts.first.substring(1)
        : variantKey;
    final size = parts.length > 1 ? parts[1].toUpperCase() : '';
    return size.isEmpty ? color : '$color $size';
  }

  String formatCompletionTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }
}
