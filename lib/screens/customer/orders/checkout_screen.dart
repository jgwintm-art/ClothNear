import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/cart_model.dart';
import '../../../models/order_model.dart';
import '../../../services/order_service.dart';
import '../../../services/cart_service.dart';
import '../../../services/store_service.dart';
import '../../../services/paymongo_service.dart';
import '../../../services/inventory_service.dart';
import '../../../config/env_config.dart';
import 'order_status_screen.dart';
import 'payment_pending_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> items;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.totalAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _orderService = OrderService();
  final _cartService = CartService();
  final _storeService = StoreService();
  final _inventoryService = InventoryService();
  final _instructionsController = TextEditingController();

  String _orderType = 'normal';
  String _paymentType = 'full'; // 'full' | 'half'
  String _paymentMethod = 'in_person'; // 'in_person' | 'online'
  String _paymentChannel = 'gcash'; // 'gcash' | 'paymaya' | 'card'
  bool _isLoading = false;

  /// Live total computed from the actual items list.

  double get _computedTotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _amountToPay {
    if (_paymentType == 'full') return _computedTotal;
    return _computedTotal / 2;
  }

  double get _remainingBalance {
    if (_paymentType == 'full') return 0;
    return _computedTotal - _amountToPay;
  }

  String get _initialStatus {
    if (_orderType == 'rush' || _orderType == 'bulk') {
      return 'pending_approval';
    }
    // Online payments hold in payment_pending until PayMongo confirms
    if (_paymentMethod == 'online') return 'payment_pending';
    return 'processing';
  }

  // ── Stock pre-check ───────────────────────────────────────────────────────

  /// Validates stock availability before attempting order placement.
  /// Returns true if stock is sufficient, false (after showing a dialog) if not.
  Future<bool> _checkStockBeforePlacing() async {
    final items = _buildOrderItems();
    final result = await _inventoryService.checkStock(items);
    if (result.isOk) return true;

    // Show a clear dialog listing all stockout issues.
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Some items are unavailable'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please update your cart and try again:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              ...result.errors.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.userMessage,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  // ── In-person order placement (unchanged from existing flow) ─────────────

  Future<void> _placeInPersonOrder() async {
    if (widget.items.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Stock pre-check before creating the order document.
      final stockOk = await _checkStockBeforePlacing();
      if (!stockOk) {
        setState(() => _isLoading = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storeId = widget.items.first.storeId;
      final store = await _storeService.getStoreById(storeId);

      final order = OrderModel(
        orderId: '',
        customerUid: uid,
        storeId: storeId,
        storeName: store?.storeName ?? '',
        items: _buildOrderItems(),
        totalPrice: _computedTotal,
        amountPaid: _paymentType == 'full' ? 0.0 : 0.0,
        // In-person: amountPaid stays 0 until worker confirms at pickup
        remainingBalance: _computedTotal,
        paymentType: _paymentType,
        orderType: _orderType,
        status: _initialStatus,
        designType: 'in_person',
        specialInstructions: _instructionsController.text,
        createdAt: DateTime.now(),
      );

      await _orderService.placeOrder(order);
      // For in-person orders, remove items from the cart immediately.
      await _cartService.removeItemsFromCart(
        uid,
        widget.items.map((e) => e.cartItemId).toList(),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
        (route) => route.isFirst,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _orderType == 'normal'
                ? 'Order placed! Pay at pickup.'
                : 'Order submitted for owner approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on InsufficientStockException catch (e) {
      if (mounted) {
        _showErrorDialog('Stock Unavailable', e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Online (PayMongo) order placement ─────────────────────────────────────

  Future<void> _placeOnlineOrder() async {
    if (widget.items.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Stock pre-check before creating the PayMongo link.
      final stockOk = await _checkStockBeforePlacing();
      if (!stockOk) {
        setState(() => _isLoading = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storeId = widget.items.first.storeId;
      final store = await _storeService.getStoreById(storeId);

      // 1. Create a PayMongo payment link for the amount due now
      final amountCentavos = PayMongoService.pesosToCentavos(_amountToPay);
      final itemSummary = widget.items
          .map((i) => '${i.productName} ×${i.quantity}')
          .join(', ');
      final description =
          'ClothNear — ${store?.storeName ?? 'Store'}: $itemSummary';

      final link = await PayMongoService.createPaymentLink(
        amountInCentavos: amountCentavos,
        description: description,
        remarks: 'ClothNear order for $uid',
      );

      // 2. Save the order to Firestore with status 'payment_pending'
      final order = OrderModel(
        orderId: '',
        customerUid: uid,
        storeId: storeId,
        storeName: store?.storeName ?? '',
        items: _buildOrderItems(),
        totalPrice: _computedTotal,
        amountPaid: 0.0, // confirmed after PayMongo webhook/poll
        remainingBalance: _computedTotal,
        paymentType: _paymentType,
        orderType: _orderType,
        status: 'payment_pending',
        designType: 'online',
        specialInstructions: _instructionsController.text,
        createdAt: DateTime.now(),
        paymongoLinkId: link.linkId,
        paymongoCheckoutUrl: link.checkoutUrl,
        paymentChannel: _paymentChannel,
        paymongoPaymentStatus: 'unpaid',
      );

      final orderId = await _orderService.placeOrder(order);

      // 3. Open PayMongo checkout in browser
      final checkoutUri = Uri.parse(link.checkoutUrl);
      if (await canLaunchUrl(checkoutUri)) {
        await launchUrl(checkoutUri, mode: LaunchMode.externalApplication);
      }

      // 4. Navigate to PaymentPendingScreen which polls for confirmation
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(
            orderId: orderId,
            paymongoLinkId: link.linkId,
            amountPaid: _amountToPay,
            totalAmount: _computedTotal,
            paymentType: _paymentType,
            paymentChannel: _paymentChannel,
            orderItems: _buildOrderItems(),
          ),
        ),
        (route) => route.isFirst,
      );
    } on InsufficientStockException catch (e) {
      if (mounted) {
        _showErrorDialog('Stock Unavailable', e.userMessage);
      }
    } on PayMongoException catch (e) {
      if (mounted) {
        _showErrorDialog('Payment Error', e.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create payment: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePlaceOrder() async {
    if (_paymentMethod == 'online') {
      await _placeOnlineOrder();
    } else {
      await _placeInPersonOrder();
    }
  }

  List<Map<String, dynamic>> _buildOrderItems() {
    return widget.items
        .map(
          (item) => {
            'productId': item.productId,
            'productName': item.productName,
            'color': item.color,
            'size': item.size,
            'quantity': item.quantity,
            'price': item.price,
            'totalPrice': item.totalPrice,
            'isPlain': item.isPlain,
            'customDesignUrl': item.customDesignUrl,
            'productImageUrl': item.productImageUrl,
          },
        )
        .toList();
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          'Checkout',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Order type ─────────────────────────────────────────────────
            _buildSectionTitle('Order Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildOrderTypeCard(
                  'normal',
                  'Normal',
                  'Standard',
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildOrderTypeCard(
                  'rush',
                  'Rush',
                  'Needs approval',
                  Icons.bolt_outlined,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildOrderTypeCard(
                  'bulk',
                  'Bulk',
                  'Needs approval',
                  Icons.layers_outlined,
                  Colors.green,
                ),
              ],
            ),
            if (_orderType != 'normal') ...[
              const SizedBox(height: 8),
              _buildInfoBanner(
                'This order requires owner approval before processing.',
                Colors.orange,
              ),
            ],

            const SizedBox(height: 20),

            // ── Payment amount ──────────────────────────────────────────────
            _buildSectionTitle('Payment Amount'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentAmountCard(
                    'full',
                    'Full Payment',
                    '₱${_computedTotal.toStringAsFixed(0)}',
                    'Pay everything now',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentAmountCard(
                    'half',
                    'Half Payment',
                    '₱${_amountToPay.toStringAsFixed(0)}',
                    '₱${_remainingBalance.toStringAsFixed(0)} on pickup',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Payment method ──────────────────────────────────────────────
            _buildSectionTitle('Payment Method'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodCard(
                    'in_person',
                    'Pay In-Person',
                    'Cash on pickup',
                    Icons.storefront_outlined,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethodCard(
                    'online',
                    'Pay Online',
                    EnvConfig.isPayMongoConfigured
                        ? 'GCash, Maya, Card'
                        : 'Not configured',
                    Icons.payment_outlined,
                    Colors.blue,
                    disabled: !EnvConfig.isPayMongoConfigured,
                  ),
                ),
              ],
            ),

            // ── Payment channel (only when online is selected) ──────────────
            if (_paymentMethod == 'online') ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Payment Channel'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildChannelCard('gcash', 'GCash', '💚', Colors.green),
                  const SizedBox(width: 8),
                  _buildChannelCard('paymaya', 'Maya', '💙', Colors.blue),
                  const SizedBox(width: 8),
                  _buildChannelCard('card', 'Card', '💳', Colors.purple),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoBanner(
                'You will be redirected to PayMongo\'s secure checkout page. '
                'Return to the app after completing your payment.',
                Colors.blue,
              ),
            ],

            if (_paymentMethod == 'in_person' && _paymentType == 'half') ...[
              const SizedBox(height: 8),
              _buildInfoBanner(
                'You pay ₱${_amountToPay.toStringAsFixed(0)} as a deposit. '
                'The remaining ₱${_remainingBalance.toStringAsFixed(0)} is due at pickup.',
                Colors.green,
              ),
            ],

            const SizedBox(height: 20),

            // ── Items summary ───────────────────────────────────────────────
            _buildSectionTitle('Items'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ...widget.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: item.productImageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.productImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const Center(
                                            child: Text(
                                              '👕',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                          ),
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      '👕',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.color} • ${item.size} • ×${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                Text(
                                  item.isPlain ? 'Plain' : 'Custom Design',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: item.isPlain
                                        ? Colors.grey[500]
                                        : Colors.purple[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${item.totalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  _buildTotalRow(
                    'Total',
                    '₱${_computedTotal.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  if (_paymentType == 'half') ...[
                    const SizedBox(height: 4),
                    _buildTotalRow(
                      _paymentMethod == 'online'
                          ? 'Pay now (online)'
                          : 'Deposit due now',
                      '₱${_amountToPay.toStringAsFixed(2)}',
                      color: Colors.blue[700]!,
                    ),
                    _buildTotalRow(
                      'Balance at pickup',
                      '₱${_remainingBalance.toStringAsFixed(2)}',
                      color: Colors.grey[500]!,
                    ),
                  ],
                  if (_paymentType == 'full' && _paymentMethod == 'online') ...[
                    const SizedBox(height: 4),
                    _buildTotalRow(
                      'Paying online now',
                      '₱${_amountToPay.toStringAsFixed(2)}',
                      color: Colors.blue[700]!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Special instructions ────────────────────────────────────────
            _buildSectionTitle('Special Instructions (Optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. specific placement, color notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[700]!),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Place order button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _buildButtonLabel(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _buildButtonLabel() {
    if (_orderType != 'normal') return 'Submit for Approval';
    if (_paymentMethod == 'online') {
      return 'Pay ₱${_amountToPay.toStringAsFixed(0)} via ${_channelLabel(_paymentChannel)}';
    }
    return 'Place Order — Pay at Pickup';
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'Maya';
      case 'card':
        return 'Card';
      default:
        return 'Online';
    }
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildInfoBanner(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isBold ? Colors.red[600] : Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTypeCard(
    String type,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _orderType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orderType = type),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentAmountCard(
    String type,
    String title,
    String amount,
    String subtitle,
  ) {
    final isSelected = _paymentType == type;
    return GestureDetector(
      onTap: () => setState(() => _paymentType = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.red[600] : Colors.grey[600],
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    String method,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool disabled = false,
  }) {
    final isSelected = _paymentMethod == method && !disabled;
    return Expanded(
      child: GestureDetector(
        onTap: disabled
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(EnvConfig.paymongoConfigHint),
                  duration: const Duration(seconds: 4),
                ),
              )
            : () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.grey[50]
                : isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: disabled
                  ? Colors.grey.shade200
                  : isSelected
                  ? color
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: disabled
                    ? Colors.grey[300]
                    : isSelected
                    ? color
                    : Colors.grey,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: disabled
                      ? Colors.grey[400]
                      : isSelected
                      ? color
                      : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: disabled ? Colors.grey[300] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCard(
    String channel,
    String label,
    String emoji,
    Color color,
  ) {
    final isSelected = _paymentChannel == channel;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentChannel = channel),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }
}
