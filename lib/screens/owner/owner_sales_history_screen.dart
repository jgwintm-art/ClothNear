// lib/screens/owner/owner_sales_history_screen.dart
//
// Owner Sales History Screen.
//
// Shows ALL store sales — both POS walk-in transactions and completed online
// orders — in a unified, filterable, paginated timeline.
//
// Features:
//   • Filter by order source (POS / Online / All)
//   • Filter by status (Processing / Completed / Cancelled / All)
//   • Filter by date range (from / to)
//   • Worker attribution shown on POS orders
//   • Paginated list (20 per page, load-more on scroll)
//   • Pull-to-refresh
//   • Active filter chip bar
//   • Sale detail bottom sheet

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../services/sales_history_providers.dart';

class OwnerSalesHistoryScreen extends ConsumerStatefulWidget {
  final String storeId;
  final String storeName;

  const OwnerSalesHistoryScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  ConsumerState<OwnerSalesHistoryScreen> createState() =>
      _OwnerSalesHistoryScreenState();
}

class _OwnerSalesHistoryScreenState
    extends ConsumerState<OwnerSalesHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
      ref.read(ownerSalesHistoryProvider(widget.storeId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(ownerSalesHistoryProvider(widget.storeId));
    final filter = ref.watch(ownerSalesFilterProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales History',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            Text(
              widget.storeName,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.filter_list_outlined),
            ),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context, filter),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref
                .read(ownerSalesHistoryProvider(widget.storeId).notifier)
                .refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(ownerSalesHistoryProvider(widget.storeId).notifier)
            .refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Summary card ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SummaryCard(orders: historyState.orders),
            ),

            // ── Active filter chips ───────────────────────────────────────
            if (filter.hasActiveFilters)
              SliverToBoxAdapter(
                child: _FilterChipBar(
                  filter: filter,
                  onClear: () =>
                      ref.read(ownerSalesFilterProvider.notifier).clearAll(),
                ),
              ),

            // ── Error banner ─────────────────────────────────────────────
            if (historyState.error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(message: historyState.error!),
              ),

            // ── Loading skeleton ─────────────────────────────────────────
            if (historyState.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _SaleTileSkeleton(),
                  childCount: 8,
                ),
              )
            // ── Empty state ──────────────────────────────────────────────
            else if (historyState.orders.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: filter.hasActiveFilters
                      ? 'No sales match your filters.'
                      : 'No sales recorded yet.',
                  subtitle: filter.hasActiveFilters
                      ? 'Try adjusting or clearing your filters.'
                      : 'POS and online transactions will appear here.',
                ),
              )
            // ── Sales list ───────────────────────────────────────────────
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _OwnerSaleTile(
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
                                  ownerSalesHistoryProvider(
                                    widget.storeId,
                                  ).notifier,
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

  void _showFilterSheet(BuildContext context, SalesHistoryFilter current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(storeId: widget.storeId),
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
// Summary card — computed from the current loaded page
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<OrderModel> orders;
  const _SummaryCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    final posOrders = orders.where((o) => o.isPosOrder).toList();
    final onlineOrders = orders.where((o) => o.isOnlineOrder).toList();
    final posTotal = posOrders.fold(0.0, (s, o) => s + o.totalPrice);
    final onlineTotal = onlineOrders.fold(0.0, (s, o) => s + o.totalPrice);
    final grandTotal = posTotal + onlineTotal;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing ${orders.length} transaction${orders.length != 1 ? 's' : ''}',
            style: TextStyle(color: Colors.blue[200], fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${fmt.format(grandTotal)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: 'POS',
                value: '₱${fmt.format(posTotal)}',
                count: posOrders.length,
                color: Colors.purple[300]!,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Online',
                value: '₱${fmt.format(onlineTotal)}',
                count: onlineOrders.length,
                color: Colors.teal[300]!,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.blue[100],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            '$count txn${count != 1 ? 's' : ''}',
            style: TextStyle(color: Colors.blue[200], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter chip bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipBar extends StatelessWidget {
  final SalesHistoryFilter filter;
  final VoidCallback onClear;
  const _FilterChipBar({required this.filter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d');
    final chips = <String>[];
    if (filter.orderSource != null) {
      chips.add(filter.orderSource == 'pos' ? 'POS only' : 'Online only');
    }
    if (filter.status != null) chips.add(filter.status!);
    if (filter.workerUid != null) chips.add('Worker filtered');
    if (filter.fromDate != null || filter.toDate != null) {
      final from = filter.fromDate != null
          ? dateFmt.format(filter.fromDate!)
          : '…';
      final to = filter.toDate != null ? dateFmt.format(filter.toDate!) : '…';
      chips.add('$from – $to');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              children: chips
                  .map(
                    (c) => Chip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.blue[50],
                      side: BorderSide(color: Colors.blue[200]!),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner sale list tile
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerSaleTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  const _OwnerSaleTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy  h:mm a');
    final currFmt = NumberFormat('#,##0.00', 'en_PH');
    final itemCount = order.items.fold<int>(
      0,
      (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0),
    );

    final isPOS = order.isPosOrder;
    final sourceColor = isPOS ? Colors.purple[700]! : Colors.teal[700]!;
    final sourceIcon = isPOS
        ? Icons.point_of_sale_outlined
        : Icons.shopping_bag_outlined;
    final sourceLabel = isPOS ? 'Walk-in POS' : 'Online Order';

    Color statusColor;
    switch (order.status) {
      case 'completed':
        statusColor = Colors.green[700]!;
        break;
      case 'cancelled':
      case 'rejected':
        statusColor = Colors.red[700]!;
        break;
      case 'processing':
        statusColor = Colors.blue[700]!;
        break;
      default:
        statusColor = Colors.orange[700]!;
    }

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
                color: sourceColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(sourceIcon, color: sourceColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: sourceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFmt.format(order.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPOS
                        ? '$itemCount item${itemCount != 1 ? 's' : ''}  •  By ${order.workerName ?? 'Unknown'}'
                        : '$itemCount item${itemCount != 1 ? 's' : ''}  •  ${order.paymentMethodDisplay}',
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
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
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
// Filter bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  final String storeId;
  const _FilterSheet({required this.storeId});

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _orderSource;
  late String? _status;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final f = ref.read(ownerSalesFilterProvider);
    _orderSource = f.orderSource;
    _status = f.status;
    _fromDate = f.fromDate;
    _toDate = f.toDate;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Filter Sales',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),

          // Order source
          Text(
            'Source',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _SegmentedRow(
            options: const {'All': null, 'POS': 'pos', 'Online': 'online'},
            selected: _orderSource,
            onSelected: (v) => setState(() => _orderSource = v),
          ),
          const SizedBox(height: 16),

          // Status
          Text(
            'Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _SegmentedRow(
            options: const {
              'All': null,
              'Processing': 'processing',
              'Completed': 'completed',
              'Cancelled': 'cancelled',
            },
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),

          // Date range
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: _fromDate != null
                      ? dateFmt.format(_fromDate!)
                      : 'From date',
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _fromDate = d);
                  },
                  onClear: _fromDate != null
                      ? () => setState(() => _fromDate = null)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePickerButton(
                  label: _toDate != null ? dateFmt.format(_toDate!) : 'To date',
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _toDate = d);
                  },
                  onClear: _toDate != null
                      ? () => setState(() => _toDate = null)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(ownerSalesFilterProvider.notifier).clearAll();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final notifier = ref.read(
                      ownerSalesFilterProvider.notifier,
                    );
                    notifier.setOrderSource(_orderSource);
                    notifier.setStatus(_status);
                    notifier.setFromDate(_fromDate);
                    notifier.setToDate(_toDate);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final Map<String, String?> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SegmentedRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((e) {
          final isSelected = e.value == selected;
          return GestureDetector(
            onTap: () => onSelected(e.value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
                ),
              ),
              child: Text(
                e.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerButton({
    required this.label,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: Colors.grey[500]),
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
    final isPOS = order.isPosOrder;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: controller,
          children: [
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

            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPOS ? 'Walk-in POS Sale' : 'Online Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPOS ? Colors.purple[50] : Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPOS ? Colors.purple[700] : Colors.teal[700],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Transaction meta
            _detailRow('Date', dateFmt.format(order.createdAt)),
            if (isPOS) ...[
              _detailRow('Processed by', order.workerName ?? '—'),
              _detailRow('Payment', order.paymentMethodDisplay),
            ] else ...[
              _detailRow(
                'Customer',
                order.customerUid == 'walk_in' ? 'Walk-in' : order.customerUid,
              ),
              _detailRow('Payment', order.paymentMethodDisplay),
              _detailRow('Payment status', order.resolvedPaymentStatusDisplay),
            ],
            _detailRow('Order type', isPOS ? 'POS Walk-in' : order.orderType),
            const Divider(height: 28),

            // Items
            Text(
              'Items',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map((item) {
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              // POS items store unitPrice; online orders may not — fallback gracefully.
              final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final lineTotal = qty * unitPrice;
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
                    if (lineTotal > 0)
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
                    color: Colors.blue[700],
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
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
            textAlign: TextAlign.center,
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
                Container(height: 12, width: 140, color: Colors.grey[100]),
                const SizedBox(height: 6),
                Container(height: 10, width: 200, color: Colors.grey[100]),
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
              Container(height: 20, width: 60, color: Colors.grey[100]),
            ],
          ),
        ],
      ),
    );
  }
}
