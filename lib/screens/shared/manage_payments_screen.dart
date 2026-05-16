import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

/// Manage Payments screen — used by both Owner and Worker/Cashier.
/// Shows all orders grouped by payment status.
/// Workers with canConfirmPayments can mark in-person payments as received.
class ManagePaymentsScreen extends StatefulWidget {
  final String storeId;
  final bool canConfirmPayments; // true for owners and permitted workers

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

  // Mark balance as received for in-person orders
  Future<void> _confirmPayment(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.orderId.substring(0, 6).toUpperCase()}'),
            const SizedBox(height: 8),
            Text(
              'Remaining balance: ₱${order.remainingBalance.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirm that you have received the remaining balance from the customer?',
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

    // Update the order: mark remaining balance as 0 and amountPaid = total
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
          'Payment confirmed for Order #${order.orderId.substring(0, 6).toUpperCase()}',
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
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
          // Only show orders that are not rejected/cancelled
          final active = all
              .where((o) => o.status != 'rejected' && o.status != 'cancelled')
              .toList();

          final balanceDue = active
              .where((o) => o.remainingBalance > 0)
              .toList();
          final fullyPaid = active
              .where((o) => o.remainingBalance <= 0)
              .toList();

          // Summary totals
          final totalRevenue = active.fold<double>(
            0,
            (runningTotal, order) => runningTotal + order.amountPaid,
          );

          final totalBalance = balanceDue.fold<double>(
            0,
            (runningTotal, order) => runningTotal + order.remainingBalance,
          );

          return Column(
            children: [
              // Revenue summary
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
                    _buildSummaryItem(
                      'Total Received',
                      '₱${totalRevenue.toStringAsFixed(0)}',
                      Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _buildSummaryItem(
                      'Balance Due',
                      '₱${totalBalance.toStringAsFixed(0)}',
                      totalBalance > 0 ? Colors.yellow[200]! : Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _buildSummaryItem(
                      'Orders',
                      '${active.length}',
                      Colors.white,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(active),
                    _buildPaymentList(balanceDue),
                    _buildPaymentList(fullyPaid),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
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

  Widget _buildPaymentList(List<OrderModel> orders) {
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
      itemBuilder: (context, index) => _buildPaymentCard(orders[index]),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    final hasBalance = order.remainingBalance > 0;
    final isFullyPaid = !hasBalance;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBalance ? Colors.orange[200]! : Colors.green[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderId.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isFullyPaid ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFullyPaid
                          ? Colors.green[300]!
                          : Colors.orange[300]!,
                    ),
                  ),
                  child: Text(
                    isFullyPaid ? 'Fully Paid' : 'Balance Due',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isFullyPaid
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Items summary
            Text(
              order.items
                  .map((i) => '${i['productName']} ×${i['quantity']}')
                  .join(', '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Payment breakdown
            Row(
              children: [
                Expanded(
                  child: _buildPaymentRow(
                    'Total',
                    '₱${order.totalPrice.toStringAsFixed(0)}',
                    Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _buildPaymentRow(
                    'Paid',
                    '₱${order.amountPaid.toStringAsFixed(0)}',
                    Colors.green[700]!,
                  ),
                ),
                Expanded(
                  child: _buildPaymentRow(
                    'Balance',
                    '₱${order.remainingBalance.toStringAsFixed(0)}',
                    hasBalance ? Colors.orange[700]! : Colors.grey[400]!,
                  ),
                ),
              ],
            ),

            // Payment type badge
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.paymentType == 'full'
                        ? 'Full Payment'
                        : 'Half & Half',
                    style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                ),
                const Spacer(),
                // Confirm payment button — only if balance due and has permission
                if (hasBalance && widget.canConfirmPayments)
                  ElevatedButton.icon(
                    onPressed: () => _confirmPayment(order),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text(
                      'Confirm Received',
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, Color valueColor) {
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
