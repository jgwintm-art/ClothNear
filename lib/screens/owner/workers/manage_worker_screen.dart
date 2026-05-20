import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clothnear/models/worker_model.dart';
import 'package:clothnear/services/worker_service.dart';

import 'create_worker_sheet.dart';
import 'worker_detail_screen.dart';

class ManageWorkerScreen extends StatefulWidget {
  final String storeId;

  const ManageWorkerScreen({super.key, required this.storeId});

  @override
  State<ManageWorkerScreen> createState() => _ManageWorkerScreenState();
}

class _ManageWorkerScreenState extends State<ManageWorkerScreen> {
  final _workerService = WorkerService();

  void _openCreateSheet() async {
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          CreateWorkerSheet(storeId: widget.storeId, ownerUid: ownerUid),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker list updated.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openWorkerDetail(WorkerModel worker) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkerDetailScreen(worker: worker, storeId: widget.storeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Manage Workers'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Worker'),
      ),

      body: StreamBuilder<List<WorkerModel>>(
        stream: _workerService.getStoreWorkers(ownerUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load workers.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final workers = snapshot.data ?? [];

          if (workers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No workers yet.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add Worker" to create an account\nfor your employee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: Colors.blue[700],
                child: Row(
                  children: [
                    _buildStat(
                      label: 'Total',
                      value: '${workers.length}',
                      icon: Icons.people,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      label: 'Active',
                      value: '${workers.where((w) => w.isActive).length}',
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      label: 'Pending Login',
                      value: '${workers.where((w) => w.firstLogin).length}',
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: workers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final worker = workers[index];
                    return _WorkerCard(
                      worker: worker,
                      onTap: () => _openWorkerDetail(worker),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final VoidCallback onTap;

  const _WorkerCard({required this.worker, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final permissionLabels = <String>[];
    if (worker.canUpdateOrderStatus) permissionLabels.add('Orders');
    if (worker.canConfirmPayments) permissionLabels.add('Payments');
    if (worker.canViewInventory) permissionLabels.add('Inventory');
    if (worker.canProcessSales) permissionLabels.add('POS Sales');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: worker.isActive ? Colors.grey[200]! : Colors.red[100]!,
        ),
      ),
      color: worker.isActive ? Colors.white : Colors.red[50],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: worker.isActive
                    ? Colors.blue[100]
                    : Colors.grey[200],
                child: Text(
                  worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: worker.isActive
                        ? Colors.blue[700]
                        : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            worker.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: worker.isActive
                                ? Colors.green[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: worker.isActive
                                  ? Colors.green[300]!
                                  : Colors.red[300]!,
                            ),
                          ),
                          child: Text(
                            worker.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: worker.isActive
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      worker.email,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (permissionLabels.isEmpty)
                      Text(
                        'No permissions granted',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[600],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 4,
                        children: permissionLabels
                            .map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (worker.firstLogin) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.orange[600],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Awaiting first login',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
