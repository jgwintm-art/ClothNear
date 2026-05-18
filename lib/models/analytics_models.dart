enum RestockUrgency { critical, high, medium, low }

enum RiskSeverity { critical, warning, info }

class LowStockAlert {
  final String productId;
  final String productName;
  final String variantKey;
  final String displayLabel;
  final int currentStock;
  final int suggestedRestockQty;
  final RestockUrgency urgency;
  final int unitsSoldLast30Days;
  final String reason;

  const LowStockAlert({
    required this.productId,
    required this.productName,
    required this.variantKey,
    required this.displayLabel,
    required this.currentStock,
    required this.suggestedRestockQty,
    required this.urgency,
    required this.unitsSoldLast30Days,
    required this.reason,
  });
}

class TrendingProduct {
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  final String trendLabel;

  const TrendingProduct({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
    required this.trendLabel,
  });
}

class InventoryInsights {
  final List<LowStockAlert> alerts;
  final List<TrendingProduct> trendingProducts;
  final int totalLowStockVariants;
  final int totalOutOfStockVariants;
  final String summary;

  const InventoryInsights({
    required this.alerts,
    required this.trendingProducts,
    required this.totalLowStockVariants,
    required this.totalOutOfStockVariants,
    required this.summary,
  });
}

class WorkforceInsights {
  final int activeWorkerCount;
  final int suggestedWorkerCount;
  final int activeOrderCount;
  final int pendingWorkloadUnits;
  final double estimatedProductionMinutes;
  final DateTime? estimatedCompletionTime;
  final bool insufficientWorkforce;
  final bool workloadImbalance;
  final String? hiringRecommendation;
  final String summary;

  const WorkforceInsights({
    required this.activeWorkerCount,
    required this.suggestedWorkerCount,
    required this.activeOrderCount,
    required this.pendingWorkloadUnits,
    required this.estimatedProductionMinutes,
    this.estimatedCompletionTime,
    required this.insufficientWorkforce,
    required this.workloadImbalance,
    this.hiringRecommendation,
    required this.summary,
  });
}

class PrinterInsights {
  final int configuredPrinterCount;
  final int suggestedPrinterCount;
  final int queuedPrintJobsUnits;
  final double estimatedPrintQueueMinutes;
  final double utilizationPercent;
  final bool printerShortage;
  final bool productionBottleneck;
  final String? procurementRecommendation;
  final String summary;

  const PrinterInsights({
    required this.configuredPrinterCount,
    required this.suggestedPrinterCount,
    required this.queuedPrintJobsUnits,
    required this.estimatedPrintQueueMinutes,
    required this.utilizationPercent,
    required this.printerShortage,
    required this.productionBottleneck,
    this.procurementRecommendation,
    required this.summary,
  });
}

class MonthlyDemandPoint {
  final int year;
  final int month;
  final String label;
  final int orderCount;
  final int unitsSold;
  final double revenue;

  const MonthlyDemandPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.orderCount,
    required this.unitsSold,
    required this.revenue,
  });
}

class SeasonalProductForecast {
  final String productId;
  final String productName;
  final int predictedUnits;
  final String rationale;

  const SeasonalProductForecast({
    required this.productId,
    required this.productName,
    required this.predictedUnits,
    required this.rationale,
  });
}

class SeasonalInsights {
  final List<MonthlyDemandPoint> historicalMonthly;
  final List<MonthlyDemandPoint> forecastMonthly;
  final List<String> peakPeriodLabels;
  final List<SeasonalProductForecast> highDemandProducts;
  final List<String> seasonalInventorySuggestions;
  final String summary;

  const SeasonalInsights({
    required this.historicalMonthly,
    required this.forecastMonthly,
    required this.peakPeriodLabels,
    required this.highDemandProducts,
    required this.seasonalInventorySuggestions,
    required this.summary,
  });
}

class OperationalRiskAlert {
  final RiskSeverity severity;
  final String title;
  final String message;
  final String category;

  const OperationalRiskAlert({
    required this.severity,
    required this.title,
    required this.message,
    required this.category,
  });
}

class RecommendedAction {
  final String title;
  final String description;
  final String priority;

  const RecommendedAction({
    required this.title,
    required this.description,
    required this.priority,
  });
}

class ShopAnalyticsReport {
  final InventoryInsights inventory;
  final WorkforceInsights workforce;
  final PrinterInsights printers;
  final SeasonalInsights seasonal;
  final List<OperationalRiskAlert> risks;
  final List<RecommendedAction> recommendedActions;
  final String insightsSummary;
  final String? aiNarrativeSummary;
  final List<String> aiBusinessSuggestions;
  final bool aiEnhancementUsed;
  final String? aiEnhancementError;
  final DateTime generatedAt;

  const ShopAnalyticsReport({
    required this.inventory,
    required this.workforce,
    required this.printers,
    required this.seasonal,
    required this.risks,
    required this.recommendedActions,
    required this.insightsSummary,
    this.aiNarrativeSummary,
    this.aiBusinessSuggestions = const [],
    this.aiEnhancementUsed = false,
    this.aiEnhancementError,
    required this.generatedAt,
  });

  ShopAnalyticsReport copyWithAi({
    required String narrative,
    required List<String> suggestions,
    String? error,
  }) {
    return ShopAnalyticsReport(
      inventory: inventory,
      workforce: workforce,
      printers: printers,
      seasonal: seasonal,
      risks: risks,
      recommendedActions: recommendedActions,
      insightsSummary: insightsSummary,
      aiNarrativeSummary: narrative,
      aiBusinessSuggestions: suggestions,
      aiEnhancementUsed: error == null,
      aiEnhancementError: error,
      generatedAt: generatedAt,
    );
  }
}
