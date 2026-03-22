import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/order_service.dart';
import '../services/store_service.dart';
import '../models/order_model.dart';
import 'owner/orders/order_details_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final _orderService = OrderService();
  final _storeService = StoreService();
  String? _storeId;
  String? _storeName;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    // Workers are linked to a store via their uid
    // For now we load the first active store
    // In a real app owners would assign workers to stores
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final store = await _storeService.getStoreByOwner(uid).first;
    if (store != null && mounted) {
      setState(() {
        _storeId = store.storeId;
        _storeName = store.storeName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Worker Dashboard',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.blue[700]),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Worker!',
                    style: TextStyle(fontSize: 13, color: Colors.blue[100]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _storeName ?? 'Loading store...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            if (_storeId != null)
              StreamBuilder<List<OrderModel>>(
                stream: _orderService.getStoreOrders(_storeId!),
                builder: (context, snapshot) {
                  final orders = snapshot.data ?? [];
                  final processingCount = orders
                      .where((o) => o.status == 'processing')
                      .length;
                  final readyCount = orders
                      .where((o) => o.status == 'ready')
                      .length;
                  final activeCount = orders
                      .where(
                        (o) =>
                            o.status != 'completed' &&
                            o.status != 'cancelled' &&
                            o.status != 'rejected',
                      )
                      .length;

                  return Row(
                    children: [
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
                        'Active',
                        activeCount.toString(),
                        Colors.orange,
                        Colors.orange[50]!,
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 20),

            // Menu items
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuItem(
              Icons.receipt_long_outlined,
              'View Orders',
              'See and update processing orders',
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _WorkerOrdersScreen(storeId: _storeId),
                ),
              ),
            ),

            _buildMenuItem(
              Icons.payments_outlined,
              'Manage Payments',
              'Coming in Phase 6',
              Colors.grey,
              null,
              comingSoon: true,
            ),

            const SizedBox(height: 20),

            // Recent active orders
            if (_storeId != null) ...[
              Text(
                'Active Orders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<OrderModel>>(
                stream: _orderService.getStoreOrders(_storeId!),
                builder: (context, snapshot) {
                  final orders = (snapshot.data ?? [])
                      .where(
                        (o) => o.status == 'processing' || o.status == 'ready',
                      )
                      .take(3)
                      .toList();

                  if (orders.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          'No active orders',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: orders
                        .map((order) => _buildActiveOrderCard(order))
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback? onTap, {
    bool comingSoon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: comingSoon ? Colors.grey : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: comingSoon ? Colors.grey[500] : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            comingSoon
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Soon',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  )
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final isReady = order.status == 'ready';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OrderDetailsScreen(order: order, isOwner: false),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isReady ? Colors.green.shade200 : Colors.blue.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: isReady ? Colors.green[700] : Colors.blue[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''}  •  ${order.orderType}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isReady ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isReady ? 'Ready' : 'Processing',
                style: TextStyle(
                  fontSize: 10,
                  color: isReady ? Colors.green[700] : Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Worker-specific orders view (no approve/reject/cancel)
class _WorkerOrdersScreen extends StatelessWidget {
  final String? storeId;

  const _WorkerOrdersScreen({required this.storeId});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

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
          'Orders',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: storeId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<OrderModel>>(
              stream: orderService.getStoreOrders(storeId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = (snapshot.data ?? [])
                    .where(
                      (o) => o.status == 'processing' || o.status == 'ready',
                    )
                    .toList();

                if (orders.isEmpty) {
                  return Center(
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
                          'No active orders',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrderDetailsScreen(order: order, isOwner: false),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: order.status == 'ready'
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.orderId.substring(0, 6).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${order.items.length} items  •  ${order.orderType}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  Text(
                                    '₱${order.totalPrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: order.status == 'ready'
                                    ? Colors.green[50]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.status == 'ready'
                                    ? 'Ready'
                                    : 'Processing',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: order.status == 'ready'
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
