import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';

/// Manage Payments — used by Owner and Worker/Cashier.

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
  final _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Payment confirm dialog ──────────────────────────────────────────────────

  Future<void> _confirmInPersonPayment(OrderModel order) async {
    final noteController = TextEditingController();
    final amountController = TextEditingController(
      text: order.remainingBalance.toStringAsFixed(2),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order.orderId.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Total: ₱${order.totalPrice.toStringAsFixed(2)}  |  '
              'Balance: ₱${order.remainingBalance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount Received (₱)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Note (e.g. "Paid in full at pickup")',
                border: const OutlineInputBorder(),
                isDense: true,
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm you have physically received this amount.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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

    final amountReceived =
        double.tryParse(amountController.text) ?? order.remainingBalance;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String confirmerName = 'Staff';
      try {
        final user = await _authService.getUserById(uid);
        confirmerName = user?.name ?? confirmerName;
      } catch (_) {}

      await _orderService.confirmManualPayment(
        orderId: order.orderId,
        totalPrice: order.totalPrice,
        amountReceived: amountReceived,
        confirmedByUid: uid,
        confirmedByName: confirmerName,
        note: noteController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cash payment of ₱${amountReceived.toStringAsFixed(2)} '
            'confirmed for #${order.orderId.substring(0, 6).toUpperCase()}',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // ── Audit log bottom sheet ──────────────────────────────────────────────────

  void _showAuditLog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment History — #${order.orderId.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _orderService.getPaymentEvents(order.orderId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snap.data ?? [];
                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        'No payment events yet',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildAuditTile(events[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTile(Map<String, dynamic> ev) {
    final ts = ev['timestamp'] as int?;
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
    final type = ev['type'] as String? ?? '';
    final source = ev['source'] as String? ?? '';
    final amount = (ev['amount'] as num?)?.toDouble() ?? 0;
    final method = ev['method'] as String? ?? '';
    final by = ev['confirmedBy'] as String? ?? '';
    final note = ev['note'] as String? ?? '';
    final pmId = ev['paymongoPaymentId'] as String? ?? '';
    final isAuto = source == 'paymongo_auto';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAuto ? Icons.flash_on : Icons.person,
                size: 15,
                color: isAuto ? Colors.blue[700] : Colors.green[700],
              ),
              const SizedBox(width: 6),
              Text(
                type == 'full_payment'
                    ? 'Full Payment Received'
                    : 'Partial Payment Received',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isAuto ? Colors.blue[700] : Colors.green[700],
                ),
              ),
              const Spacer(),
              if (dt != null)
                Text(
                  _fmtTs(dt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _aRow('Amount', '₱${amount.toStringAsFixed(2)}'),
          _aRow('Method', _mLabel(method)),
          if (by.isNotEmpty) _aRow(isAuto ? 'Confirmed by' : 'Staff', by),
          if (pmId.isNotEmpty)
            Row(
              children: [
                Text(
                  'PayMongo ID: ',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Expanded(
                  child: Text(
                    pmId,
                    style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pmId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.copy, size: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: $note',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  String _mLabel(String m) {
    switch (m) {
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'Maya';
      case 'card':
        return 'Card';
      case 'cash':
        return 'Cash';
      case 'partial_cash':
        return 'Cash (Partial)';
      default:
        return m.isNotEmpty ? m : 'Unknown';
    }
  }

  // ── Main build ──────────────────────────────────────────────────────────────

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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unpaid / Partial'),
            Tab(text: 'Paid'),
            Tab(text: 'Pending Online'),
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

          final unpaid = active
              .where(
                (o) =>
                    o.resolvedPaymentStatus == 'unpaid' ||
                    o.resolvedPaymentStatus == 'partial',
              )
              .toList();
          final paid = active
              .where((o) => o.resolvedPaymentStatus == 'paid')
              .toList();
          final pending = active
              .where((o) => o.resolvedPaymentStatus == 'pending_online')
              .toList();

          final totalReceived = active.fold<double>(
            0,
            (s, o) => s + o.amountPaid,
          );
          final totalBalance = unpaid.fold<double>(
            0,
            (s, o) => s + o.remainingBalance,
          );

          return Column(
            children: [
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
                    _sum(
                      'Received',
                      '₱${totalReceived.toStringAsFixed(0)}',
                      Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _sum(
                      'Balance Due',
                      '₱${totalBalance.toStringAsFixed(0)}',
                      totalBalance > 0 ? Colors.yellow[200]! : Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white30),
                    _sum('Pending Online', '${pending.length}', Colors.white),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _list(active),
                    _list(unpaid),
                    _list(paid),
                    _list(pending),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sum(String label, String value, Color vc) => Column(
    children: [
      Text(
        value,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: vc),
      ),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ],
  );

  Widget _list(List<OrderModel> orders) {
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _card(orders[i]),
    );
  }

  Widget _card(OrderModel order) {
    final ps = order.resolvedPaymentStatus;
    final isOnline = order.isOnlinePayment;

    Color bc;
    switch (ps) {
      case 'paid':
        bc = Colors.green.shade200;
        break;
      case 'partial':
        bc = Colors.orange.shade200;
        break;
      case 'pending_online':
        bc = Colors.blue.shade200;
        break;
      default:
        bc = Colors.red.shade100;
    }

    return GestureDetector(
      onTap: () => _showAuditLog(order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bc),
        ),
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
                    _b(
                      isOnline
                          ? '${order.paymentChannelDisplay} Online'
                          : 'In-Person',
                      isOnline ? Colors.blue[50]! : Colors.grey[100]!,
                      isOnline ? Colors.blue[700]! : Colors.grey[700]!,
                    ),
                    const SizedBox(width: 6),
                    _psBadge(ps),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.items
                  .map((i) => '${i['productName']} ×${i['quantity']}')
                  .join(', '),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Amounts
            Row(
              children: [
                Expanded(
                  child: _amt(
                    'Total',
                    '₱${order.totalPrice.toStringAsFixed(0)}',
                    Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _amt(
                    'Paid',
                    '₱${order.amountPaid.toStringAsFixed(0)}',
                    Colors.green[700]!,
                  ),
                ),
                Expanded(
                  child: _amt(
                    'Balance',
                    '₱${order.remainingBalance.toStringAsFixed(0)}',
                    order.remainingBalance > 0 && ps != 'pending_online'
                        ? Colors.orange[700]!
                        : Colors.grey[400]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment meta
            if (order.paymentConfirmedAt != null) ...[
              _meta(
                Icons.check_circle_outline,
                Colors.green[600]!,
                'Paid ${_fmtTs(order.paymentConfirmedAtDateTime!)}',
              ),
              if (order.paymentConfirmedBy != null &&
                  order.paymentConfirmedBy!.isNotEmpty)
                _meta(
                  order.paymentConfirmedBy == 'system'
                      ? Icons.flash_on
                      : Icons.person_outline,
                  Colors.grey[500]!,
                  order.paymentConfirmedBy == 'system'
                      ? 'Auto-confirmed by PayMongo'
                      : 'Confirmed by ${order.paymentConfirmedBy}',
                ),
            ],
            if (isOnline &&
                order.paymongoPaymentId != null &&
                order.paymongoPaymentId!.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: order.paymongoPaymentId!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PayMongo ID copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.tag, size: 12, color: Colors.blue[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.paymongoPaymentId!,
                        style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.copy, size: 11, color: Colors.grey[400]),
                  ],
                ),
              ),
            if (order.paymentNote != null && order.paymentNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Note: ${order.paymentNote}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Footer
            Row(
              children: [
                _b(
                  order.statusDisplay,
                  Colors.grey[100]!,
                  Colors.grey[600]!,
                  fs: 10,
                ),
                const SizedBox(width: 6),
                _b(
                  order.paymentType == 'full' ? 'Full Payment' : 'Half & Half',
                  Colors.grey[100]!,
                  Colors.grey[600]!,
                  fs: 10,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.history, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(
                      'History',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                if ((ps == 'unpaid' || ps == 'partial') &&
                    !isOnline &&
                    widget.canConfirmPayments)
                  ElevatedButton.icon(
                    onPressed: () => _confirmInPersonPayment(order),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(
                      ps == 'partial' ? 'Confirm Balance' : 'Confirm Cash',
                      style: const TextStyle(fontSize: 11),
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
                if (ps == 'pending_online' && isOnline)
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

  Widget _psBadge(String ps) {
    Color bg, fg;
    String label;
    switch (ps) {
      case 'paid':
        bg = Colors.green[50]!;
        fg = Colors.green[700]!;
        label = '✓ Paid';
        break;
      case 'partial':
        bg = Colors.orange[50]!;
        fg = Colors.orange[700]!;
        label = 'Partial';
        break;
      case 'pending_online':
        bg = Colors.blue[50]!;
        fg = Colors.blue[700]!;
        label = 'Awaiting';
        break;
      default:
        bg = Colors.red[50]!;
        fg = Colors.red[700]!;
        label = 'Unpaid';
    }
    return _b(label, bg, fg);
  }

  Widget _b(String text, Color bg, Color fg, {double fs = 9}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: fs, color: fg, fontWeight: FontWeight.w600),
    ),
  );

  Widget _amt(String label, String value, Color vc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      Text(
        value,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: vc),
      ),
    ],
  );

  Widget _meta(IconData icon, Color ic, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 12, color: ic),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  String _fmtTs(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
