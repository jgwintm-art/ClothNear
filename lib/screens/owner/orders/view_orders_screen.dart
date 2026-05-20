import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/order_model.dart';
import '../../../services/order_service.dart';
import '../../../services/store_service.dart';
import '../../../services/inventory_service.dart';
import 'order_details_screen.dart';

class ViewOrdersScreen extends StatefulWidget {
  const ViewOrdersScreen({super.key});

  @override
  State<ViewOrdersScreen> createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen> {
  final _orderService = OrderService();
  final _storeService = StoreService();
  String _selectedFilter = 'all';
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final store = await _storeService.getStoreByOwner(uid).first;
    if (store != null && mounted) {
      setState(() => _storeId = store.storeId);
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    if (_selectedFilter == 'all') return orders;
    return orders.where((o) => o.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'View Orders',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _storeId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<OrderModel>>(
              stream: _orderService.getStoreOrders(_storeId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snapshot.data ?? [];
                final filtered = _filterOrders(allOrders);

                // Count by status
                final pendingCount = allOrders
                    .where((o) => o.status == 'pending_approval')
                    .length;
                final processingCount = allOrders
                    .where((o) => o.status == 'processing')
                    .length;
                final readyCount = allOrders
                    .where((o) => o.status == 'ready')
                    .length;

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
                            Colors.blue,
                            Colors.blue[50]!,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            'Ready',
                            readyCount.toString(),
                            Colors.green,
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
                          _buildFilterChip('rejected', 'Rejected'),
                          _buildFilterChip('cancelled', 'Cancelled'),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildOrderCard(filtered[index], true),
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

  Widget _buildOrderCard(OrderModel order, bool isOwner) {
    final statusConfig = _getStatusConfig(order.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OrderDetailsScreen(order: order, isOwner: isOwner),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusConfig['borderColor'] as Color),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusConfig['accentColor'] as Color,
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
                              color: statusConfig['badgeBg'] as Color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusConfig['label'] as String,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: statusConfig['badgeText'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.orderType[0].toUpperCase()}${order.orderType.substring(1)} Order  •  ${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 4),
                      // Items preview
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
                      if (order.items.length > 2)
                        Text(
                          '+${order.items.length - 2} more items',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₱${order.totalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.paymentType == 'full' ? 'Full' : 'Half',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Approve/Reject buttons for pending
                      if (isOwner && order.status == 'pending_approval') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _approveOrder(order),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.green[700]!),
                                  foregroundColor: Colors.green[700],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rejectOrder(order),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red[700]!),
                                  foregroundColor: Colors.red[700],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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

  Future<void> _approveOrder(OrderModel order) async {
    try {
      await _orderService.approveOrder(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order approved — inventory updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Approve — Insufficient Stock'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The following items do not have enough stock:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...e.errors.map(
                  (err) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            err.userMessage,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please restock the items before approving.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(OrderModel order) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;
    // rejectOrder restores inventory if it had somehow been deducted.
    await _orderService.rejectOrder(order);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order rejected'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this order?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending_approval':
        return {
          'label': 'Pending Approval',
          'accentColor': Colors.orange,
          'borderColor': Colors.orange.shade200,
          'badgeBg': Colors.orange[50]!,
          'badgeText': Colors.orange[800]!,
        };
      case 'processing':
        return {
          'label': 'Processing',
          'accentColor': Colors.blue[700]!,
          'borderColor': Colors.blue.shade200,
          'badgeBg': Colors.blue[50]!,
          'badgeText': Colors.blue[800]!,
        };
      case 'ready':
        return {
          'label': 'Ready for Pickup',
          'accentColor': Colors.green[700]!,
          'borderColor': Colors.green.shade200,
          'badgeBg': Colors.green[50]!,
          'badgeText': Colors.green[800]!,
        };
      case 'completed':
        return {
          'label': 'Completed',
          'accentColor': Colors.grey,
          'borderColor': Colors.grey.shade200,
          'badgeBg': Colors.grey[100]!,
          'badgeText': Colors.grey[600]!,
        };
      case 'rejected':
        return {
          'label': 'Rejected',
          'accentColor': Colors.red,
          'borderColor': Colors.red.shade200,
          'badgeBg': Colors.red[50]!,
          'badgeText': Colors.red[800]!,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'accentColor': Colors.grey,
          'borderColor': Colors.grey.shade200,
          'badgeBg': Colors.grey[100]!,
          'badgeText': Colors.grey[600]!,
        };
      default:
        return {
          'label': 'Unknown',
          'accentColor': Colors.grey,
          'borderColor': Colors.grey.shade200,
          'badgeBg': Colors.grey[100]!,
          'badgeText': Colors.grey[600]!,
        };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
