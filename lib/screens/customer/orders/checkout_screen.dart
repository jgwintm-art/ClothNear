import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cart_model.dart';
import '../../../models/order_model.dart';
import '../../../services/order_service.dart';
import '../../../services/cart_service.dart';
import '../../../services/store_service.dart';
import 'order_status_screen.dart';

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
  final _instructionsController = TextEditingController();

  String _orderType = 'normal';
  String _paymentType = 'full';
  String _paymentMethod = 'in_person';
  bool _isLoading = false;

  double get _amountToPay {
    if (_paymentType == 'full') return widget.totalAmount;
    return widget.totalAmount / 2;
  }

  double get _remainingBalance {
    if (_paymentType == 'full') return 0;
    return widget.totalAmount - _amountToPay;
  }

  String get _initialStatus {
    if (_orderType == 'rush' || _orderType == 'bulk') {
      return 'pending_approval';
    }
    return 'processing';
  }

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storeId = widget.items.first.storeId;

      final store = await _storeService.getStoreById(storeId);
      final storeName = store?.storeName ?? '';

      final orderItems = widget.items
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

      final order = OrderModel(
        orderId: '',
        customerUid: uid,
        storeId: storeId,
        storeName: storeName,
        items: orderItems,
        totalPrice: widget.totalAmount,
        amountPaid: _amountToPay,
        remainingBalance: _remainingBalance,
        paymentType: _paymentType,
        orderType: _orderType,
        status: _initialStatus,
        designType: _paymentMethod,
        specialInstructions: _instructionsController.text,
        createdAt: DateTime.now(),
      );

      await _orderService.placeOrder(order);
      await _cartService.clearCart(uid);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OrderStatusScreen()),
          (route) => route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _orderType == 'normal'
                  ? 'Order placed successfully!'
                  : 'Order submitted! Waiting for owner approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

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
            // Order type
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order requires owner approval before processing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Payment amount
            _buildSectionTitle('Payment Amount'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentAmountCard(
                    'full',
                    'Full Payment',
                    '₱${widget.totalAmount.toStringAsFixed(0)}',
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

            // Payment method
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
                    'Coming soon',
                    Icons.payment_outlined,
                    Colors.blue,
                    comingSoon: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Order items summary
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
                          // Product image
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${widget.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                  if (_paymentType == 'half') ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Due now',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₱${_amountToPay.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance on pickup',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₱${_remainingBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Special instructions
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

            // Place order button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _orderType == 'normal'
                            ? 'Place Order — ₱${_amountToPay.toStringAsFixed(0)}'
                            : 'Submit for Approval',
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
    bool comingSoon = false,
  }) {
    final isSelected = _paymentMethod == method && !comingSoon;
    return GestureDetector(
      onTap: comingSoon
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Online payment coming soon in Phase 6!'),
                duration: Duration(seconds: 2),
              ),
            )
          : () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: comingSoon
              ? Colors.grey[50]
              : isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: comingSoon
                ? Colors.grey.shade200
                : isSelected
                ? color
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: comingSoon ? Colors.grey[300] : color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: comingSoon
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
                color: comingSoon ? Colors.grey[300] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (comingSoon)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                ),
              ),
          ],
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
