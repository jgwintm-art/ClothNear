import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/order_model.dart';
import '../../../services/order_service.dart';

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Orders',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderService().getCustomerOrders(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Place an order to see it here',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(snapshot.data![index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusConfig = _getStatusConfig(order.status);

    return Container(
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
            // Left accent bar
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
                    // Header row
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

                    // Store name
                    Text(
                      order.storeName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),

                    // Items — using Map access since items is List<Map>
                    ...order.items.map(
                      (item) => Text(
                        '${item['productName']} × ${item['quantity']}  •  ${item['color']} ${item['size']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Price + payment + order type badges
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
                            order.paymentType == 'full'
                                ? 'Full Payment'
                                : 'Half Payment',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
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
                            order.orderType[0].toUpperCase() +
                                order.orderType.substring(1),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Design type badge
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          order.designType == 'preset'
                              ? Icons.palette_outlined
                              : Icons.upload_file_outlined,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.designType == 'preset'
                              ? 'Preset Design'
                              : 'Custom Upload',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),

                    // Remaining balance for half payment
                    if (order.paymentType == 'half' &&
                        order.remainingBalance > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Balance due on pickup: ₱${order.remainingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],

                    // Pending approval message
                    if (order.status == 'pending_approval') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Waiting for owner to review your ${order.orderType} order request.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],

                    // Rejected message
                    if (order.status == 'rejected') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'This order was rejected by the store.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],

                    // Progress bar for active orders
                    if (order.status == 'processing' ||
                        order.status == 'ready') ...[
                      const SizedBox(height: 8),
                      _buildProgressBar(order.status),
                    ],

                    // Date
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(order.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String status) {
    final steps = ['Placed', 'Processing', 'Ready', 'Done'];
    final currentStep = status == 'processing' ? 1 : 2;

    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (index) {
            final isCompleted = index <= currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.blue[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps
              .map(
                (step) => Text(
                  step,
                  style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                ),
              )
              .toList(),
        ),
      ],
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
          'label': 'Ready for Pickup!',
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
