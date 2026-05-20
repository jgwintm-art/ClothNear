import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_model.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import 'worker/worker_orders_screen.dart';
import 'worker/worker_inventory_screen.dart';
import 'worker/worker_pos_screen.dart';
import 'shared/manage_payments_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  WorkerModel? _worker;
  StoreModel? _store;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
  }

  Future<void> _loadWorkerData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in.');

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) throw Exception('Worker account not found.');

      final data = userDoc.data()!;

      // Lazy migration: backfill any permission keys that did not exist when
      // this worker account was originally created (e.g. canUsePOS for
      // accounts created before the POS feature was added).
      // WorkerModel._migratePermissions() defines the canonical key set.
      // We compare against the raw Firestore map and write only missing keys
      // so we never overwrite values the owner has already set.
      final rawPerms = Map<String, dynamic>.from(data['permissions'] ?? {});
      const knownDefaults = {
        'canUpdateOrderStatus': false,
        'canConfirmPayments': false,
        'canViewInventory': false,
        'canUsePOS': false,
      };
      final missingKeys = knownDefaults.keys
          .where((k) => !rawPerms.containsKey(k))
          .toList();
      if (missingKeys.isNotEmpty) {
        final batch = _firestore.batch();
        final missingUpdate = {
          for (final k in missingKeys) 'permissions.$k': false,
        };
        // Backfill /users/{uid}
        batch.update(_firestore.collection('users').doc(uid), missingUpdate);
        // Backfill /stores/{storeId}/workers/{uid} if storeId is known
        final storeId = data['storeId'] as String?;
        if (storeId != null && storeId.isNotEmpty) {
          batch.update(
            _firestore
                .collection('stores')
                .doc(storeId)
                .collection('workers')
                .doc(uid),
            missingUpdate,
          );
        }
        await batch.commit();
        // Merge the defaults into the local data map so the model below
        // picks up the backfilled values without needing a second Firestore read.
        for (final k in missingKeys) {
          (data['permissions'] as Map)[k] = false;
        }
      }

      // Deserialize as WorkerModel — all typed getters (canUsePOS, etc.)
      // and _migratePermissions are now in scope.
      final worker = WorkerModel.fromMap(data, uid);

      if (!worker.isActive) {
        await _authService.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      if (worker.storeId.isEmpty) {
        throw Exception('Worker is not assigned to any store.');
      }

      final storeDoc = await _firestore
          .collection('stores')
          .doc(worker.storeId)
          .get();
      if (!storeDoc.exists) throw Exception('Assigned store not found.');

      final store = StoreModel.fromMap(storeDoc.data()!, storeDoc.id);

      setState(() {
        _worker = worker;
        _store = store;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _logout,
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final worker = _worker!;
    final store = _store!;

    final menuItems = <_WorkerMenuItem>[];

    // View Orders — requires canUpdateOrderStatus
    if (worker.canUpdateOrderStatus) {
      menuItems.add(
        _WorkerMenuItem(
          icon: Icons.receipt_long_outlined,
          label: 'View Orders',
          color: Colors.blue[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerOrdersScreen(
                storeId: store.storeId,
                canUpdateStatus: true,
                canConfirmPayments: worker.canConfirmPayments,
              ),
            ),
          ),
        ),
      );
    }

    // Manage Payments — requires canConfirmPayments
    if (worker.canConfirmPayments) {
      menuItems.add(
        _WorkerMenuItem(
          icon: Icons.payments_outlined,
          label: 'Manage Payments',
          color: Colors.green[700]!,
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
      );
    }

    // View Inventory — requires canViewInventory
    if (worker.canViewInventory) {
      menuItems.add(
        _WorkerMenuItem(
          icon: Icons.inventory_2_outlined,
          label: 'View Inventory',
          color: Colors.orange[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerInventoryScreen(storeId: store.storeId),
            ),
          ),
        ),
      );
    }

    // Point of Sale — requires canUsePOS
    if (worker.canUsePOS) {
      menuItems.add(
        _WorkerMenuItem(
          icon: Icons.point_of_sale_outlined,
          label: 'Point of Sale',
          color: Colors.purple[700]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerPOSScreen(
                storeId: store.storeId,
                storeName: store.storeName,
                workerUid: worker.uid,
                workerName: worker.name,
              ),
            ),
          ),
        ),
      );
    }

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
              'Worker Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              store.storeName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Worker greeting banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.blue[700],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${worker.name.split(' ').first}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${menuItems.length} feature${menuItems.length != 1 ? 's' : ''} available',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu grid or no-access state
          Expanded(
            child: menuItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No features available.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your store owner has not granted\nany permissions to your account yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(20),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: menuItems
                        .map((item) => _WorkerMenuCard(item: item))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkerMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WorkerMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _WorkerMenuCard extends StatelessWidget {
  final _WorkerMenuItem item;
  const _WorkerMenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
