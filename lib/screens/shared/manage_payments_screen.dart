import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

/// Manage Payments — used by Owner and Worker/Cashier.
/// Shows all orders grouped by payment status.
/// Distinguishes online (PayMongo) from in-person payments.
/// Workers with canConfirmPayments can mark in-person balances as received.
class ManagePaymentsScreen extends StatefulWidget {
  final String storeId;
  final bool canConfirmPayments;

  const ManagePaymentsScreen({
    super.key,
    required this.storeId,
    required this.canConfirmPayments,
  });

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmInPersonPayment(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.orderId.substring(0, 6).toUpperCase()}'),
            const SizedBox(height: 8),
            Text(
              'Amount: ₱${order.remainingBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirm you have received this cash payment from the customer?',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: const Text(
              'Confirm Received',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.orderId)
        .update({
          'amountPaid': order.totalPrice,
          'remainingBalance': 0.0,
          'paymentConfirmed': true,
          'paymentConfirmedAt': DateTime.now().millisecondsSinceEpoch,
        });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cash payment confirmed for #${order.orderId.substring(0, 6).toUpperCase()}',
        ),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manage Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Balance Due'),
            Tab(text: 'Paid'),
          ],
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
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red[700]),
              ),
            );
          }

          final all = snapshot.data ?? [];
          final active = all
              .where((o) => o.status != 'rejected' && o.status != 'cancelled')
              .toList();

          final balanceDue = active
              .where(
                (o) => o.remainingBalance > 0 && o.status != 'payment_pending',
              )
              .toList();
          final fullyPaid = active
              .where(
                (o) =>
                    o.remainingBalance <= 0 ||
                    (o.isOnlinePayment && o.paymongoPaymentStatus == 'paid'),
              )
              .toList();
          final awaitingOnline = active
              .where((o) => o.status == 'payment_pending')
              .toList();

          final totalReceived = active.fold<double>(
            0,
            (s, o) => s + o.amountPaid,
          );
          final totalBalance = balanceDue.fold<double>(
            0,
            (s, o) => s + o.remainingBalance,
          );

          return Column(
            children: [
              // Summary bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                color: Colors.green[700],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      'Received',
                      '₱${totalReceived.toStringAsFixed(0)}',
                      Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _summaryItem(
                      'Balance Due',
                      '₱${totalBalance.toStringAsFixed(0)}',
                      totalBalance > 0 ? Colors.yellow[200]! : Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _summaryItem(
                      'Pending Online',
                      '${awaitingOnline.length}',
                      Colors.white,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(active),
                    _buildList(balanceDue),
                    _buildList(fullyPaid),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No payments found',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCard(orders[i]),
    );
  }

  Widget _buildCard(OrderModel order) {
    final hasBalance = order.remainingBalance > 0;
    final isPending = order.status == 'payment_pending';
    final isOnline = order.isOnlinePayment;
    final isPaid = order.isPaymentConfirmed;

    Color borderColor;
    if (isPending) {
      borderColor = Colors.blue[200]!;
    } else if (hasBalance) {
      borderColor = Colors.orange[200]!;
    } else {
      borderColor = Colors.green[200]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.orderId.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    // Online vs in-person badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.blue[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOnline
                            ? '${order.paymentChannelDisplay} Online'
                            : 'In-Person',
                        style: TextStyle(
                          fontSize: 9,
                          color: isOnline ? Colors.blue[700] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Payment status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.blue[50]
                            : isPaid
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPending
                              ? Colors.blue[200]!
                              : isPaid
                              ? Colors.green[200]!
                              : Colors.orange[200]!,
                        ),
                      ),
                      child: Text(
                        isPending
                            ? 'Awaiting Payment'
                            : isPaid
                            ? 'Paid'
                            : 'Balance Due',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? Colors.blue[700]
                              : isPaid
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Items
            Text(
              order.items
                  .map((i) => '${i['productName']} ×${i['quantity']}')
                  .join(', '),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Amount breakdown
            Row(
              children: [
                Expanded(
                  child: _amountItem(
                    'Total',
                    '₱${order.totalPrice.toStringAsFixed(0)}',
                    Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _amountItem(
                    'Paid',
                    '₱${order.amountPaid.toStringAsFixed(0)}',
                    Colors.green[700]!,
                  ),
                ),
                Expanded(
                  child: _amountItem(
                    'Balance',
                    '₱${order.remainingBalance.toStringAsFixed(0)}',
                    hasBalance && !isPending
                        ? Colors.orange[700]!
                        : Colors.grey[400]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Order status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.paymentType == 'full'
                        ? 'Full Payment'
                        : 'Half & Half',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
                const Spacer(),
                // Confirm button — only for in-person orders with balance
                if (hasBalance &&
                    !isOnline &&
                    !isPending &&
                    widget.canConfirmPayments)
                  ElevatedButton.icon(
                    onPressed: () => _confirmInPersonPayment(order),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text(
                      'Confirm Cash',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                // Online payment awaiting — read-only note
                if (isPending && isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'Auto-confirmed on pay',
                      style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
