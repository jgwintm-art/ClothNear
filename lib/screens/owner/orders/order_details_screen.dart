import 'package:flutter/material.dart';
import '../../../models/order_model.dart';
import '../../../services/order_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  final bool isOwner;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.isOwner,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _orderService = OrderService();
  bool _isLoading = false;
  late OrderModel _order;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'processing', 'label': 'Processing'},
    {'value': 'ready', 'label': 'Ready for Pickup'},
    {'value': 'completed', 'label': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    await _orderService.updateOrderStatus(_order.orderId, newStatus);
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerUid: _order.customerUid,
        storeId: _order.storeId,
        storeName: _order.storeName,
        items: _order.items,
        totalPrice: _order.totalPrice,
        amountPaid: _order.amountPaid,
        remainingBalance: _order.remainingBalance,
        paymentType: _order.paymentType,
        orderType: _order.orderType,
        status: newStatus,
        designType: _order.designType,
        designUrl: _order.designUrl,
        specialInstructions: _order.specialInstructions,
        createdAt: _order.createdAt,
      );
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $newStatus!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _approveOrder() async {
    setState(() => _isLoading = true);
    await _orderService.updateOrderStatus(_order.orderId, 'processing');
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerUid: _order.customerUid,
        storeId: _order.storeId,
        storeName: _order.storeName,
        items: _order.items,
        totalPrice: _order.totalPrice,
        amountPaid: _order.amountPaid,
        remainingBalance: _order.remainingBalance,
        paymentType: _order.paymentType,
        orderType: _order.orderType,
        status: 'processing',
        designType: _order.designType,
        designUrl: _order.designUrl,
        specialInstructions: _order.specialInstructions,
        createdAt: _order.createdAt,
      );
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order approved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _rejectOrder() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
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
                hintText: 'Reason (optional)',
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    await _orderService.updateOrderStatus(_order.orderId, 'rejected');
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerUid: _order.customerUid,
        storeId: _order.storeId,
        storeName: _order.storeName,
        items: _order.items,
        totalPrice: _order.totalPrice,
        amountPaid: _order.amountPaid,
        remainingBalance: _order.remainingBalance,
        paymentType: _order.paymentType,
        orderType: _order.orderType,
        status: 'rejected',
        designType: _order.designType,
        designUrl: _order.designUrl,
        specialInstructions: _order.specialInstructions,
        createdAt: _order.createdAt,
      );
      _isLoading = false;
    });
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

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
          'This will permanently delete this order record. This cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _orderService.deleteOrder(_order.orderId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Cancel Order',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    await _orderService.cancelOrder(_order.orderId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
          'Order #${_order.orderId.substring(0, 6).toUpperCase()}',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  _buildStatusBanner(),
                  const SizedBox(height: 16),

                  // Order info
                  _buildCard(
                    title: 'Order Information',
                    child: Column(
                      children: [
                        _buildRow(
                          'Order ID',
                          '#${_order.orderId.substring(0, 6).toUpperCase()}',
                        ),
                        _buildRow(
                          'Order Type',
                          '${_order.orderType[0].toUpperCase()}${_order.orderType.substring(1)}',
                        ),
                        _buildRow('Date', _formatDate(_order.createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Items
                  _buildCard(
                    title: 'Items Ordered',
                    child: Column(
                      children: [
                        ..._order.items.map((item) => _buildItemRow(item)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₱${_order.totalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Design
                  _buildCard(
                    title: 'Design',
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _order.designType == 'custom'
                                ? Colors.purple[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _order.designType == 'custom'
                                ? Icons.upload_file_outlined
                                : Icons.checkroom_outlined,
                            color: _order.designType == 'custom'
                                ? Colors.purple[700]
                                : Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _order.designType == 'custom'
                                    ? 'Custom Design Uploaded'
                                    : 'Plain — No Design',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_order.designType == 'custom' &&
                                  _order.designUrl.isNotEmpty)
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    'View Design File',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment
                  _buildCard(
                    title: 'Payment',
                    child: Column(
                      children: [
                        _buildRow(
                          'Total',
                          '₱${_order.totalPrice.toStringAsFixed(0)}',
                        ),
                        _buildRow(
                          'Amount Paid',
                          '₱${_order.amountPaid.toStringAsFixed(0)}',
                        ),
                        if (_order.remainingBalance > 0)
                          _buildRow(
                            'Balance Due',
                            '₱${_order.remainingBalance.toStringAsFixed(0)}',
                            valueColor: Colors.orange[700],
                          ),
                        _buildRow(
                          'Payment Type',
                          _order.paymentType == 'full'
                              ? 'Full Payment'
                              : 'Half Payment',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Special instructions
                  if (_order.specialInstructions.isNotEmpty)
                    _buildCard(
                      title: 'Special Instructions',
                      child: Text(
                        _order.specialInstructions,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  if (_order.specialInstructions.isNotEmpty)
                    const SizedBox(height: 12),

                  // Approve/Reject — only for pending + owner
                  if (widget.isOwner &&
                      _order.status == 'pending_approval') ...[
                    _buildCard(
                      title: 'Decision Required',
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'This ${_order.orderType} order is waiting for your approval. Please review the items and decide.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _approveOrder,
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _rejectOrder,
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red[700]!),
                                    foregroundColor: Colors.red[700],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Status update — for active orders
                  if (_order.status == 'processing' || _order.status == 'ready')
                    _buildCard(
                      title: 'Update Status',
                      child: Column(
                        children: _statusOptions
                            .where((s) => s['value'] != _order.status)
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _updateStatus(s['value']!),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Colors.blue[700]!,
                                      ),
                                      foregroundColor: Colors.blue[700],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text('Mark as ${s['label']}'),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (_order.status == 'processing' || _order.status == 'ready')
                    const SizedBox(height: 12),

                  // Cancel button — owner only for active orders
                  if (widget.isOwner &&
                      _order.status != 'completed' &&
                      _order.status != 'cancelled' &&
                      _order.status != 'rejected')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red[700]!),
                          foregroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel Order',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (widget.isOwner &&
                      (_order.status == 'completed' ||
                          _order.status == 'cancelled' ||
                          _order.status == 'rejected')) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteOrder,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Delete Order',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red[700]!),
                          foregroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    final configs = {
      'pending_approval': {
        'color': Colors.orange[50]!,
        'border': Colors.orange.shade200,
        'text': Colors.orange[800]!,
        'label': 'Pending Approval',
      },
      'processing': {
        'color': Colors.blue[50]!,
        'border': Colors.blue.shade200,
        'text': Colors.blue[800]!,
        'label': 'Processing',
      },
      'ready': {
        'color': Colors.green[50]!,
        'border': Colors.green.shade200,
        'text': Colors.green[800]!,
        'label': 'Ready for Pickup',
      },
      'completed': {
        'color': Colors.grey[100]!,
        'border': Colors.grey.shade300,
        'text': Colors.grey[700]!,
        'label': 'Completed',
      },
      'rejected': {
        'color': Colors.red[50]!,
        'border': Colors.red.shade200,
        'text': Colors.red[800]!,
        'label': 'Rejected',
      },
      'cancelled': {
        'color': Colors.grey[100]!,
        'border': Colors.grey.shade300,
        'text': Colors.grey[700]!,
        'label': 'Cancelled',
      },
    };
    final config = configs[_order.status] ?? configs['completed']!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config['color'] as Color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config['border'] as Color),
      ),
      child: Text(
        'Status: ${config['label']}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: config['text'] as Color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                item['productImageUrl'] != null &&
                    item['productImageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item['productImageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(
                        child: Text('👕', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('👕', style: TextStyle(fontSize: 16)),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['productName']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item['color']} • ${item['size']} × ${item['quantity']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (item['isPlain'] == false)
                  Text(
                    'Custom Design',
                    style: TextStyle(fontSize: 10, color: Colors.purple[600]),
                  ),
              ],
            ),
          ),
          Text(
            '₱${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
