import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../owner/orders/order_details_screen.dart';

class WorkerOrdersScreen extends StatefulWidget {
  final String storeId;
  final bool canUpdateStatus;
  final bool canConfirmPayments;

  const WorkerOrdersScreen({
    super.key,
    required this.storeId,
    required this.canUpdateStatus,
    required this.canConfirmPayments,
  });

  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  final _orderService = OrderService();
  String _selectedFilter = 'all';

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    if (_selectedFilter == 'all') return orders;
    return orders.where((o) => o.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'View Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.getStoreOrders(widget.storeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: TextStyle(color: Colors.red[700]),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];
          final filtered = _filterOrders(allOrders);

          final pendingCount = allOrders
              .where((o) => o.status == 'pending_approval')
              .length;
          final processingCount = allOrders
              .where((o) => o.status == 'processing')
              .length;
          final readyCount = allOrders.where((o) => o.status == 'ready').length;

          return Column(
            children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Pending',
                      pendingCount.toString(),
                      Colors.orange,
                      Colors.orange[50]!,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Processing',
                      processingCount.toString(),
                      Colors.blue[700]!,
                      Colors.blue[50]!,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Ready',
                      readyCount.toString(),
                      Colors.green[700]!,
                      Colors.green[50]!,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Total',
                      allOrders.length.toString(),
                      Colors.grey,
                      Colors.grey[100]!,
                    ),
                  ],
                ),
              ),

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('all', 'All'),
                    _buildFilterChip('pending_approval', 'Pending'),
                    _buildFilterChip('processing', 'Processing'),
                    _buildFilterChip('ready', 'Ready'),
                    _buildFilterChip('completed', 'Completed'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Orders list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No orders found',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildOrderCard(filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color textColor,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColors = <String, Color>{
      'pending_approval': Colors.orange,
      'processing': Colors.blue[700]!,
      'ready': Colors.green[700]!,
      'completed': Colors.grey,
      'cancelled': Colors.grey,
      'rejected': Colors.red,
    };
    final accent = statusColors[order.status] ?? Colors.grey;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(
            order: order,
            isOwner: widget.canUpdateStatus, // workers with status permission
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.orderId.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              order.statusDisplay,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.orderType[0].toUpperCase()}${order.orderType.substring(1)} • ${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 4),
                      ...order.items
                          .take(2)
                          .map(
                            (item) => Text(
                              '${item['productName']} × ${item['quantity']}  •  ${item['color']} ${item['size']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      const SizedBox(height: 6),
                      Text(
                        '₱${order.totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
