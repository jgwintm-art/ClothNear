import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/store_service.dart';

import 'owner/register_store_screen.dart';
import 'owner/inventory/manage_inventory_screen.dart';
import 'owner/orders/view_orders_screen.dart';
import 'owner/workers/manage_worker_screen.dart';
import 'owner/pricing/manage_pricing_screen.dart';
import 'owner/analytics/ai_analytics_dashboard_screen.dart';
import 'shared/manage_payments_screen.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Owner Dashboard',
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
      body: StreamBuilder(
        stream: StoreService().getStoreByOwner(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'You don\'t have a store yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register your store to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterStoreScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Register Your Store',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          final store = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[100],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          store.storeName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.blue[100],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[100],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Manage Your Store',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: 'Manage Inventory',
                    subtitle: 'Add and manage your products',
                    color: Colors.blue,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageInventoryScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'View Orders',
                    subtitle: 'View and manage all orders',
                    color: Colors.orange,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ViewOrdersScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_alt_outlined,
                    title: 'Manage Workers',
                    subtitle: 'Add and manage store workers',
                    color: Colors.teal,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManageWorkerScreen(storeId: store.storeId),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.payments_outlined,
                    title: 'Manage Payments',
                    subtitle: 'View transactions & confirm payments',
                    color: Colors.green,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManagePaymentsScreen(
                          storeId: store.storeId,
                          canConfirmPayments: true,
                        ),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.price_change_outlined,
                    title: 'Manage Pricing',
                    subtitle: 'Edit prices + AI suggestions',
                    color: Colors.purple,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManagePricingScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'AI Analytics',
                    subtitle: 'Inventory, workforce, printers & forecasts',
                    color: Colors.teal,
                    isActive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiAnalyticsDashboardScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isActive ? color : Colors.grey,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.black : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.arrow_forward_ios : Icons.lock_outline,
              size: 14,
              color: isActive ? Colors.grey[400] : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
