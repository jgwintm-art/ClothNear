import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/paymongo_service.dart';
import '../../../services/order_service.dart';
import 'order_status_screen.dart';

/// Shown immediately after the customer is sent to PayMongo's checkout page.
///
/// Flow:
///  1. Customer pays on PayMongo (browser).
///  2. Customer returns to the app (manually or via redirect).
///  3. This screen polls PayMongo every 5 seconds for up to 10 minutes.
///  4. On confirmed payment: updates Firestore and navigates to OrderStatus.
///  5. Customer can also tap "I've paid" to trigger an immediate check.
class PaymentPendingScreen extends StatefulWidget {
  final String orderId;
  final String paymongoLinkId;
  final double amountPaid;
  final double totalAmount;
  final String paymentType; // 'full' | 'half'
  final String paymentChannel;

  const PaymentPendingScreen({
    super.key,
    required this.orderId,
    required this.paymongoLinkId,
    required this.amountPaid,
    required this.totalAmount,
    required this.paymentType,
    required this.paymentChannel,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  Timer? _pollTimer;
  bool _isChecking = false;
  bool _paymentConfirmed = false;
  String _statusMessage = 'Waiting for payment confirmation…';
  int _pollCount = 0;
  static const int _maxPolls = 120; // 10 minutes at 5-second intervals

  @override
  void initState() {
    super.initState();
    // Start polling 5 seconds after screen appears (give the browser time)
    Future.delayed(const Duration(seconds: 5), _startPolling);
  }

  void _startPolling() {
    if (!mounted) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pollCount >= _maxPolls) {
        _pollTimer?.cancel();
        return;
      }
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isChecking || !mounted) return;
    setState(() {
      _isChecking = true;
      _pollCount++;
    });

    try {
      final status = await PayMongoService.getLinkStatus(widget.paymongoLinkId);

      if (!mounted) return;

      if (status == 'paid') {
        _pollTimer?.cancel();
        await _confirmPaymentInFirestore();
      } else {
        setState(() {
          _isChecking = false;
          _statusMessage = _pollCount < 5
              ? 'Waiting for payment confirmation…'
              : 'Still waiting… complete payment in your browser.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _statusMessage = 'Could not check status. Retrying…';
        });
      }
    }
  }

  Future<void> _confirmPaymentInFirestore() async {
    try {
      await OrderService().confirmOnlinePayment(
        orderId: widget.orderId,
        amountPaid: widget.amountPaid,
        totalPrice: widget.totalAmount,
        paymentChannel: widget.paymentChannel,
      );

      if (!mounted) return;
      setState(() {
        _paymentConfirmed = true;
        _isChecking = false;
        _statusMessage = 'Payment confirmed!';
      });

      // Navigate to order status after a short celebratory pause
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _statusMessage =
              'Payment received but failed to update order. '
              'Contact support with Order ID: ${widget.orderId}';
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !mounted) return;

        final navigator = Navigator.of(context);

        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Leave this page?'),
            content: const Text(
              'Your order is saved. You can check payment status in My Orders.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (leave == true) {
          navigator.pop();
        }
      },

      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _paymentConfirmed
                      ? Container(
                          key: const ValueKey('confirmed'),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 60,
                            color: Colors.green[700],
                          ),
                        )
                      : Container(
                          key: const ValueKey('pending'),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: _isChecking
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    color: Colors.blue[700],
                                    strokeWidth: 3,
                                  ),
                                )
                              : Icon(
                                  Icons.payment_outlined,
                                  size: 52,
                                  color: Colors.blue[700],
                                ),
                        ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  _paymentConfirmed
                      ? 'Payment Confirmed! 🎉'
                      : 'Complete Your Payment',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Status message
                Text(
                  _statusMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Payment summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        'Order ID',
                        '#${widget.orderId.substring(0, 8).toUpperCase()}',
                      ),
                      const Divider(height: 16),
                      _infoRow(
                        'Amount to Pay',
                        '₱${widget.amountPaid.toStringAsFixed(2)}',
                        valueColor: Colors.red[600]!,
                      ),
                      _infoRow('Channel', _channelLabel(widget.paymentChannel)),
                      if (widget.paymentType == 'half') ...[
                        const Divider(height: 16),
                        _infoRow(
                          'Balance at pickup',
                          '₱${(widget.totalAmount - widget.amountPaid).toStringAsFixed(2)}',
                          valueColor: Colors.orange[700]!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                if (!_paymentConfirmed) ...[
                  // Primary: "I've paid" — triggers immediate check
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkPaymentStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        "I've Paid — Check Now",
                        style: TextStyle(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary: go to orders list anyway
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderStatusScreen(),
                        ),
                        (route) => route.isFirst,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View My Orders',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Checking automatically every 5 seconds.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'gcash':
        return 'GCash 💚';
      case 'paymaya':
        return 'Maya 💙';
      case 'card':
        return 'Card 💳';
      default:
        return 'Online';
    }
  }
}
