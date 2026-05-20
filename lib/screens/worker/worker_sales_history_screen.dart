import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../services/sales_history_providers.dart';

class WorkerSalesHistoryScreen extends ConsumerStatefulWidget {
  final String workerUid;
  final String storeId;
  final String workerName;

  const WorkerSalesHistoryScreen({
    super.key,
    required this.workerUid,
    required this.storeId,
    required this.workerName,
  });

  @override
  ConsumerState<WorkerSalesHistoryScreen> createState() =>
      _WorkerSalesHistoryScreenState();
}

class _WorkerSalesHistoryScreenState
    extends ConsumerState<WorkerSalesHistoryScreen> {
  late final WorkerHistoryParams _params;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _params = WorkerHistoryParams(
      workerUid: widget.workerUid,
      storeId: widget.storeId,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(workerSalesHistoryProvider(_params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(workerSalesHistoryProvider(_params));
    final dailyTotals = ref.watch(workerDailyTotalProvider(_params));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Sales',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(workerSalesHistoryProvider(_params).notifier)
                .refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(workerSalesHistoryProvider(_params).notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Daily summary card ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _DailySummaryCard(
                totalAmount: dailyTotals.total,
                transactionCount: dailyTotals.count,
                workerName: widget.workerName,
              ),
            ),

            // ── Error banner ─────────────────────────────────────────────
            if (historyState.error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(message: historyState.error!),
              ),

            // ── Loading skeleton (first load) ────────────────────────────
            if (historyState.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _SaleTileSkeleton(),
                  childCount: 6,
                ),
              )
            // ── Empty state ──────────────────────────────────────────────
            else if (historyState.orders.isEmpty)
              const SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No sales recorded yet.',
                  subtitle: 'Your POS transactions will appear here.',
                ),
              )
            // ── Sales list ───────────────────────────────────────────────
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _WorkerSaleTile(
                      order: historyState.orders[i],
                      onTap: () =>
                          _showDetailSheet(context, historyState.orders[i]),
                    ),
                    childCount: historyState.orders.length,
                  ),
                ),
              ),

              // Load-more indicator
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: historyState.isLoadingMore
                        ? const CircularProgressIndicator()
                        : historyState.hasMore
                        ? TextButton(
                            onPressed: () => ref
                                .read(
                                  workerSalesHistoryProvider(_params).notifier,
                                )
                                .loadMore(),
                            child: const Text('Load more'),
                          )
                        : Text(
                            'All sales loaded',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SaleDetailSheet(order: order),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily summary card
// ─────────────────────────────────────────────────────────────────────────────

class _DailySummaryCard extends StatelessWidget {
  final double totalAmount;
  final int transactionCount;
  final String workerName;

  const _DailySummaryCard({
    required this.totalAmount,
    required this.transactionCount,
    required this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple[700],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Sales",
            style: TextStyle(color: Colors.purple[200], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${fmt.format(totalAmount)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$transactionCount transaction${transactionCount != 1 ? 's' : ''} today',
            style: TextStyle(color: Colors.purple[200], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker sale list tile
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerSaleTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _WorkerSaleTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy  h:mm a');
    final currFmt = NumberFormat('#,##0.00', 'en_PH');
    final itemCount = order.items.fold<int>(
      0,
      (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.point_of_sale_outlined,
                color: Colors.purple[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFmt.format(order.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}  •  ${order.paymentMethodDisplay}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${currFmt.format(order.totalPrice)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.purple[700],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sale detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SaleDetailSheet extends StatelessWidget {
  final OrderModel order;
  const _SaleDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMMM d, yyyy  h:mm a');
    final currFmt = NumberFormat('#,##0.00', 'en_PH');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: controller,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sale Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const Divider(height: 28),

            // Date & worker
            _detailRow('Date', dateFmt.format(order.createdAt)),
            _detailRow('Processed by', order.workerName ?? '—'),
            _detailRow('Payment', order.paymentMethodDisplay),
            _detailRow('Type', 'Walk-in POS Sale'),
            const Divider(height: 28),

            // Items
            Text(
              'Items Sold',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map((item) {
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final lineTotal = qty * price;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['productName'] ?? '—'}'
                        '  (${item['color'] ?? ''}/${item['size'] ?? ''})'
                        '  ×$qty',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '₱${currFmt.format(lineTotal)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 28),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '₱${currFmt.format(order.totalPrice)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _SaleTileSkeleton extends StatelessWidget {
  const _SaleTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 120, color: Colors.grey[100]),
                const SizedBox(height: 6),
                Container(height: 10, width: 180, color: Colors.grey[100]),
                const SizedBox(height: 6),
                Container(height: 10, width: 100, color: Colors.grey[100]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(height: 14, width: 70, color: Colors.grey[100]),
              const SizedBox(height: 6),
              Container(height: 20, width: 40, color: Colors.grey[100]),
            ],
          ),
        ],
      ),
    );
  }
}
