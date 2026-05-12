import 'package:flutter/material.dart';
import '../../../../models/worker_model.dart';
import '../../../../services/worker_service.dart';

class WorkerDetailScreen extends StatefulWidget {
  final WorkerModel worker;
  final String storeId;

  const WorkerDetailScreen({
    super.key,
    required this.worker,
    required this.storeId,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final _workerService = WorkerService();
  late Map<String, bool> _permissions;
  late bool _isActive;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, bool>.from(widget.worker.permissions);
    _isActive = widget.worker.isActive;
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await _workerService.updatePermissions(
        widget.storeId,
        widget.worker.uid,
        _permissions,
      );
      await _workerService.toggleWorkerActive(
        widget.storeId,
        widget.worker.uid,
        _isActive,
      );
      if (!mounted) return;
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker settings saved.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // signal refresh to parent
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Worker'),
        content: Text(
          'Are you sure you want to remove ${widget.worker.name}? '
          'Their login will stop working immediately.\n\n'
          'Note: Their Firebase Auth account will remain (Spark plan limitation) '
          'but they will be unable to access any store data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _workerService.deleteWorker(widget.storeId, widget.worker.uid);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.worker.name} has been removed.'),
          backgroundColor: Colors.orange[700],
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }

  Widget _buildPermissionTile({
    required String label,
    required String subtitle,
    required String key,
    required IconData icon,
  }) {
    return SwitchListTile(
      value: _permissions[key] ?? false,
      onChanged: (val) {
        setState(() => _permissions[key] = val);
        _markChanged();
      },
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      secondary: Icon(icon, color: Colors.blue[700]),
      activeThumbColor: Colors.blue[700],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Worker Details'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Remove Worker',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Worker info card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        widget.worker.name.isNotEmpty
                            ? widget.worker.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.worker.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.worker.email,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.worker.firstLogin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.orange[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    'Awaiting first login',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Active status card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: SwitchListTile(
                value: _isActive,
                onChanged: (val) {
                  setState(() => _isActive = val);
                  _markChanged();
                },
                title: const Text(
                  'Account Active',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isActive
                      ? 'Worker can log in and access the dashboard.'
                      : 'Worker is blocked from logging in.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                secondary: Icon(
                  _isActive ? Icons.check_circle_outline : Icons.block,
                  color: _isActive ? Colors.green[600] : Colors.red[400],
                ),
                activeThumbColor: Colors.green[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Permissions card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Controls what this worker can do on the dashboard.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const Divider(height: 20),
                    _buildPermissionTile(
                      label: 'Update Order Status',
                      subtitle:
                          'Mark orders as Processing, Ready, or Completed',
                      key: 'canUpdateOrderStatus',
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                    _buildPermissionTile(
                      label: 'Confirm In-Person Payments',
                      subtitle: 'Mark cash payments as received on pickup',
                      key: 'canConfirmPayments',
                      icon: Icons.payments_outlined,
                    ),
                    _buildPermissionTile(
                      label: 'View Inventory',
                      subtitle: 'View product stock levels and availability',
                      key: 'canViewInventory',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
