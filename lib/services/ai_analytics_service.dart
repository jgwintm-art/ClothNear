import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/env_config.dart';
import '../models/analytics_models.dart';
import 'analytics_data_service.dart';
import 'analytics_engine_service.dart';
import 'store_operations_service.dart';

/// Orchestrates rule-based analytics with optional Gemini narrative enhancement.
class AiAnalyticsService {
  final AnalyticsDataService _dataService = AnalyticsDataService();
  final AnalyticsEngineService _engine = AnalyticsEngineService();
  final StoreOperationsService _operationsService = StoreOperationsService();

  ShopAnalyticsReport? _cachedReport;
  DateTime? _cacheTime;
  String? _cachedStoreId;
  static const _cacheTtl = Duration(minutes: 10);

  /// Full analytics pipeline for a store.
  Future<ShopAnalyticsReport> generateReport({
    required String storeId,
    required String ownerUid,
    bool enableAiEnhancement = true,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedReport != null &&
        _cachedStoreId == storeId &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedReport!;
    }

    final products = await _dataService.fetchProducts(storeId);
    final orders = await _dataService.fetchStoreOrders(storeId);
    final workers = await _dataService.fetchActiveWorkers(ownerUid);
    final operations = await _operationsService.getOperations(storeId);

    var report = _engine.buildReport(
      products: products,
      orders: orders,
      workers: workers,
      operations: operations,
    );

    if (enableAiEnhancement) {
      report = await _tryEnhanceWithGemini(report, storeId);
    }

    _cachedReport = report;
    _cacheTime = DateTime.now();
    _cachedStoreId = storeId;
    return report;
  }

  void clearCache() {
    _cachedReport = null;
    _cacheTime = null;
    _cachedStoreId = null;
  }

  Future<ShopAnalyticsReport> _tryEnhanceWithGemini(
    ShopAnalyticsReport report,
    String storeId,
  ) async {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      return report.copyWithAi(
        narrative: report.insightsSummary,
        suggestions: const [],
        error:
            'GEMINI_API_KEY not configured — rule-based analytics only. '
            '${EnvConfig.geminiConfigurationHint}',
      );
    }

    try {
      final payload = _compactPayload(report);
      final prompt = '''
You are a business operations advisor for a clothing print shop in the Philippines (ClothNear).

Given this analytics JSON snapshot, respond with ONLY valid JSON (no markdown):
{
  "narrative": "3-4 sentence executive summary for the shop owner",
  "suggestions": ["actionable tip 1", "actionable tip 2", "actionable tip 3"]
}

Keep suggestions practical, specific to the data, and under 120 characters each.

DATA:
$payload
''';

      final model = GenerativeModel(
        model: EnvConfig.geminiModel,
        apiKey: apiKey,
      );
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final parsed = _parseAiJson(text);

      return report.copyWithAi(
        narrative: parsed['narrative'] as String? ?? report.insightsSummary,
        suggestions: (parsed['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
    } catch (e) {
      return report.copyWithAi(
        narrative: report.insightsSummary,
        suggestions: const [],
        error: 'AI enhancement unavailable: $e',
      );
    }
  }

  String _compactPayload(ShopAnalyticsReport r) {
    final map = {
      'inventory': {
        'low': r.inventory.totalLowStockVariants,
        'out': r.inventory.totalOutOfStockVariants,
        'topAlerts': r.inventory.alerts
            .take(5)
            .map(
              (a) => {
                'product': a.productName,
                'variant': a.displayLabel,
                'stock': a.currentStock,
                'restock': a.suggestedRestockQty,
                'urgency': a.urgency.name,
              },
            )
            .toList(),
        'trending': r.inventory.trendingProducts
            .take(3)
            .map((t) => {'name': t.productName, 'units': t.unitsSold})
            .toList(),
      },
      'workforce': {
        'active': r.workforce.activeWorkerCount,
        'suggested': r.workforce.suggestedWorkerCount,
        'orders': r.workforce.activeOrderCount,
        'units': r.workforce.pendingWorkloadUnits,
        'minutes': r.workforce.estimatedProductionMinutes.round(),
      },
      'printers': {
        'count': r.printers.configuredPrinterCount,
        'suggested': r.printers.suggestedPrinterCount,
        'utilization': r.printers.utilizationPercent.round(),
        'queueMinutes': r.printers.estimatedPrintQueueMinutes.round(),
      },
      'seasonal': {
        'peaks': r.seasonal.peakPeriodLabels,
        'forecastOrders': r.seasonal.forecastMonthly
            .map((m) => m.orderCount)
            .toList(),
      },
      'risks': r.risks.length,
    };
    return jsonEncode(map);
  }

  Map<String, dynamic> _parseAiJson(String text) {
    final clean =
        text.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start == -1 || end == -1) {
      throw FormatException('No JSON in AI response');
    }
    return jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;
  }

  /// Convenience: current owner uid from Firebase Auth.
  String? get currentOwnerUid => FirebaseAuth.instance.currentUser?.uid;
}
