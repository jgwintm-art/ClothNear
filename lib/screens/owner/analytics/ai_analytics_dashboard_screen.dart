import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/analytics_models.dart';
import '../../../models/store_operations_model.dart';
import '../../../services/ai_analytics_service.dart';
import '../../../services/analytics_engine_service.dart';
import '../../../services/store_operations_service.dart';
import '../../../services/store_service.dart';
import 'widgets/analytics_section_card.dart';
import 'widgets/demand_forecast_chart.dart';
import 'widgets/operations_settings_sheet.dart';

class AiAnalyticsDashboardScreen extends StatefulWidget {
  const AiAnalyticsDashboardScreen({super.key});

  @override
  State<AiAnalyticsDashboardScreen> createState() =>
      _AiAnalyticsDashboardScreenState();
}

class _AiAnalyticsDashboardScreenState
    extends State<AiAnalyticsDashboardScreen> {
  final _analyticsService = AiAnalyticsService();
  final _operationsService = StoreOperationsService();
  final _engine = AnalyticsEngineService();

  String? _storeId;
  StoreOperationsModel _operations = const StoreOperationsModel();
  ShopAnalyticsReport? _report;
  bool _loading = true;
  bool _useAi = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }

    try {
      final store = await StoreService().getStoreByOwner(uid).first;
      if (store == null) {
        setState(() {
          _loading = false;
          _error = 'No store found';
        });
        return;
      }
      _storeId = store.storeId;
      _operations = await _operationsService.getOperations(store.storeId);
      await _loadReport(forceRefresh: true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadReport({bool forceRefresh = false}) async {
    if (_storeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final report = await _analyticsService.generateReport(
        storeId: _storeId!,
        ownerUid: uid,
        enableAiEnhancement: _useAi,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openSettings() async {
    if (_storeId == null) return;
    final updated = await showModalBottomSheet<StoreOperationsModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OperationsSettingsSheet(
        storeId: _storeId!,
        initial: _operations,
      ),
    );
    if (updated != null) {
      _operations = updated;
      _analyticsService.clearCache();
      await _loadReport(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.teal[700]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Analytics',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Operations settings',
            icon: Icon(Icons.tune, color: accent),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: accent),
            onPressed: _loading
                ? null
                : () {
                    _analyticsService.clearCache();
                    _loadReport(forceRefresh: true);
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildDashboard(accent),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _bootstrap,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Color accent) {
    final r = _report!;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return RefreshIndicator(
      onRefresh: () => _loadReport(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 16,
          vertical: 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(accent),
                const SizedBox(height: 12),
                _buildAiToggle(),
                const SizedBox(height: 16),
                _buildInsightsSummary(r, accent),
                if (isWide)
                  _buildWideGrid(r, accent)
                else ...[
                  _buildLowInventory(r),
                  _buildWorkforce(r, accent),
                  _buildPrinters(r, Colors.indigo),
                  _buildProductionTime(r, accent),
                  _buildDemandForecast(r),
                  _buildTrending(r),
                  _buildRisks(r),
                  _buildActions(r),
                  _buildAiSuggestions(r),
                ],
                const SizedBox(height: 24),
                Text(
                  'Updated ${_formatTime(r.generatedAt)} • Rule-based core'
                  '${r.aiEnhancementUsed ? ' + Gemini' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideGrid(ShopAnalyticsReport r, Color accent) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLowInventory(r)),
            const SizedBox(width: 16),
            Expanded(child: _buildWorkforce(r, accent)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPrinters(r, Colors.indigo)),
            const SizedBox(width: 16),
            Expanded(child: _buildProductionTime(r, accent)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDemandForecast(r)),
            const SizedBox(width: 16),
            Expanded(child: _buildTrending(r)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRisks(r)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildActions(r),
                  _buildAiSuggestions(r),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderRow(Color accent) {
    return Row(
      children: [
        Icon(Icons.analytics, color: accent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Operational intelligence for your print shop',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: Colors.teal[700]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Gemini AI narrative (optional)',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Switch(
            value: _useAi,
            onChanged: (v) {
              setState(() => _useAi = v);
              _analyticsService.clearCache();
              _loadReport(forceRefresh: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSummary(ShopAnalyticsReport r, Color accent) {
    final text = r.aiNarrativeSummary ?? r.insightsSummary;
    return AnalyticsSectionCard(
      title: 'AI Insights Summary',
      icon: Icons.insights,
      accentColor: accent,
      subtitle: r.aiEnhancementUsed
          ? 'Enhanced with Gemini'
          : r.aiEnhancementError != null
              ? 'Rule-based only'
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 14, height: 1.45)),
          if (r.aiEnhancementError != null) ...[
            const SizedBox(height: 8),
            Text(
              r.aiEnhancementError!,
              style: TextStyle(fontSize: 11, color: Colors.orange[800]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLowInventory(ShopAnalyticsReport r) {
    return AnalyticsSectionCard(
      title: 'Low Inventory Alerts',
      icon: Icons.inventory_2_outlined,
      accentColor: Colors.orange,
      subtitle:
          '${r.inventory.totalOutOfStockVariants} out • ${r.inventory.totalLowStockVariants} low',
      child: r.inventory.alerts.isEmpty
          ? Text(
              'No restock alerts. Inventory levels look healthy.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          : Column(
              children: r.inventory.alerts.take(8).map(_alertTile).toList(),
            ),
    );
  }

  Widget _alertTile(LowStockAlert a) {
    final color = switch (a.urgency) {
      RestockUrgency.critical => Colors.red,
      RestockUrgency.high => Colors.orange,
      RestockUrgency.medium => Colors.amber[800]!,
      RestockUrgency.low => Colors.blue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.productName} • ${a.displayLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Stock: ${a.currentStock} • Restock ~${a.suggestedRestockQty} • 30d sold: ${a.unitsSoldLast30Days}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(
              a.urgency.name.toUpperCase(),
              style: TextStyle(fontSize: 9, color: color),
            ),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforce(ShopAnalyticsReport r, Color accent) {
    final w = r.workforce;
    return AnalyticsSectionCard(
      title: 'Workforce Recommendations',
      icon: Icons.people_alt_outlined,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow('Active workers', '${w.activeWorkerCount}'),
          _metricRow('Suggested workers', '${w.suggestedWorkerCount}'),
          _metricRow('Active orders', '${w.activeOrderCount}'),
          _metricRow('Pending units', '${w.pendingWorkloadUnits}'),
          if (w.insufficientWorkforce)
            _badge('Insufficient workforce', Colors.red),
          if (w.workloadImbalance)
            _badge('Workload imbalance', Colors.orange),
          if (w.hiringRecommendation != null) ...[
            const SizedBox(height: 8),
            Text(
              w.hiringRecommendation!,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrinters(ShopAnalyticsReport r, Color color) {
    final p = r.printers;
    return AnalyticsSectionCard(
      title: 'Printer Capacity Warnings',
      icon: Icons.print_outlined,
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow('Configured printers', '${p.configuredPrinterCount}'),
          _metricRow('Recommended printers', '${p.suggestedPrinterCount}'),
          _metricRow(
            'Utilization',
            '${p.utilizationPercent.toStringAsFixed(0)}%',
          ),
          _metricRow(
            'Queue (est.)',
            '${p.estimatedPrintQueueMinutes.round()} min',
          ),
          if (p.printerShortage) _badge('Printer shortage', Colors.red),
          if (p.productionBottleneck)
            _badge('Production bottleneck', Colors.orange),
          if (p.procurementRecommendation != null) ...[
            const SizedBox(height: 8),
            Text(
              p.procurementRecommendation!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductionTime(ShopAnalyticsReport r, Color accent) {
    final w = r.workforce;
    return AnalyticsSectionCard(
      title: 'Estimated Production Completion',
      icon: Icons.schedule,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _engine.formatCompletionTime(w.estimatedCompletionTime),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ~${w.estimatedProductionMinutes.round()} production minutes '
            'and ${w.activeWorkerCount} active worker(s).',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandForecast(ShopAnalyticsReport r) {
    return AnalyticsSectionCard(
      title: 'Demand Forecast',
      icon: Icons.show_chart,
      accentColor: Colors.teal,
      subtitle: r.seasonal.summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemandForecastChart(
            historical: r.seasonal.historicalMonthly,
            forecast: r.seasonal.forecastMonthly,
          ),
          if (r.seasonal.peakPeriodLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Peak periods: ${r.seasonal.peakPeriodLabels.join(', ')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          ...r.seasonal.highDemandProducts.take(3).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '• ${p.productName}: ~${p.predictedUnits} units/mo (${p.rationale})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTrending(ShopAnalyticsReport r) {
    return AnalyticsSectionCard(
      title: 'Trending Products',
      icon: Icons.trending_up,
      accentColor: Colors.purple,
      child: r.inventory.trendingProducts.isEmpty
          ? Text(
              'No sales in the last 30 days yet.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          : Column(
              children: r.inventory.trendingProducts
                  .take(6)
                  .map(
                    (t) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.productName),
                      subtitle: Text(
                        '${t.unitsSold} units • ₱${t.revenue.toStringAsFixed(0)}',
                      ),
                      trailing: Chip(
                        label: Text(t.trendLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildRisks(ShopAnalyticsReport r) {
    return AnalyticsSectionCard(
      title: 'Operational Risk Alerts',
      icon: Icons.warning_amber_rounded,
      accentColor: Colors.red,
      child: r.risks.isEmpty
          ? Text(
              'No critical risks detected.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          : Column(
              children: r.risks.map(_riskTile).toList(),
            ),
    );
  }

  Widget _riskTile(OperationalRiskAlert risk) {
    final color = switch (risk.severity) {
      RiskSeverity.critical => Colors.red,
      RiskSeverity.warning => Colors.orange,
      RiskSeverity.info => Colors.blue,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 10, color: color),
      title: Text(risk.title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(risk.message, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildActions(ShopAnalyticsReport r) {
    return AnalyticsSectionCard(
      title: 'Recommended Actions',
      icon: Icons.checklist,
      accentColor: Colors.green[700]!,
      child: r.recommendedActions.isEmpty
          ? const Text('No actions at this time.')
          : Column(
              children: r.recommendedActions
                  .map(
                    (a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      title: Text(a.title),
                      subtitle: Text(a.description),
                      trailing: Text(
                        a.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildAiSuggestions(ShopAnalyticsReport r) {
    if (r.aiBusinessSuggestions.isEmpty &&
        r.seasonal.seasonalInventorySuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final tips = [
      ...r.aiBusinessSuggestions,
      ...r.seasonal.seasonalInventorySuggestions,
    ];

    return AnalyticsSectionCard(
      title: 'AI Business Suggestions',
      icon: Icons.lightbulb_outline,
      accentColor: Colors.amber[800]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips
            .take(6)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.amber[900])),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
