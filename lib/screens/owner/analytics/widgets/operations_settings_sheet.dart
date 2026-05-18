import 'package:flutter/material.dart';
import '../../../../models/store_operations_model.dart';
import '../../../../services/store_operations_service.dart';

class OperationsSettingsSheet extends StatefulWidget {
  final String storeId;
  final StoreOperationsModel initial;

  const OperationsSettingsSheet({
    super.key,
    required this.storeId,
    required this.initial,
  });

  @override
  State<OperationsSettingsSheet> createState() =>
      _OperationsSettingsSheetState();
}

class _OperationsSettingsSheetState extends State<OperationsSettingsSheet> {
  final _service = StoreOperationsService();
  late final TextEditingController _printers;
  late final TextEditingController _threshold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _printers = TextEditingController(
      text: widget.initial.printerCount.toString(),
    );
    _threshold = TextEditingController(
      text: widget.initial.lowStockThreshold.toString(),
    );
  }

  @override
  void dispose() {
    _printers.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ops = StoreOperationsModel(
        printerCount: int.tryParse(_printers.text)?.clamp(1, 50) ?? 1,
        lowStockThreshold: int.tryParse(_threshold.text)?.clamp(1, 100) ?? 5,
        avgMinutesPerItem: widget.initial.avgMinutesPerItem,
        avgMinutesPerCustomItem: widget.initial.avgMinutesPerCustomItem,
        workerDailyCapacityMinutes: widget.initial.workerDailyCapacityMinutes,
        printerDailyCapacityMinutes: widget.initial.printerDailyCapacityMinutes,
      );
      await _service.saveOperations(widget.storeId, ops);
      if (mounted) Navigator.pop(context, ops);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for printer and inventory analytics. Stored in Firestore.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _printers,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of printers',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Low stock threshold (units)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & refresh analytics'),
            ),
          ),
        ],
      ),
    );
  }
}
