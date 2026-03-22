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
  final String designUrl;
  final bool isPresetDesign;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.designUrl,
    required this.isPresetDesign,
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

      // Get store name
      final store = await _storeService.getStoreById(storeId);
      final storeName = store?.storeName ?? '';

      // Convert cart items to Map list matching OrderModel format
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
        designType: widget.isPresetDesign ? 'preset' : 'custom',
        designUrl: widget.designUrl,
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
            // Order type section
            _buildSectionTitle('Order Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildOrderTypeCard(
                  'normal',
                  'Normal',
                  'Standard processing',
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildOrderTypeCard(
                  'rush',
                  'Rush',
                  'Priority — needs approval',
                  Icons.bolt_outlined,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildOrderTypeCard(
                  'bulk',
                  'Bulk',
                  'Large qty — needs approval',
                  Icons.layers_outlined,
                  Colors.green,
                ),
              ],
            ),

            // Rush/Bulk warning
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
                        'This order requires owner approval before processing. You\'ll be notified once the owner responds.',
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

            // Payment type section
            _buildSectionTitle('Payment Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentTypeCard(
                    'full',
                    'Full Payment',
                    '₱${widget.totalAmount.toStringAsFixed(0)} now',
                    'No remaining balance',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentTypeCard(
                    'half',
                    'Half Payment',
                    '₱${_amountToPay.toStringAsFixed(0)} now',
                    '₱${_remainingBalance.toStringAsFixed(0)} on pickup',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Order summary
            _buildSectionTitle('Order Summary'),
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
                  _buildSummaryRow(
                    'Items',
                    '${widget.items.length} item${widget.items.length > 1 ? 's' : ''}',
                  ),
                  _buildSummaryRow(
                    'Order Type',
                    _orderType[0].toUpperCase() + _orderType.substring(1),
                  ),
                  _buildSummaryRow(
                    'Payment',
                    _paymentType == 'full' ? 'Full Payment' : 'Half Payment',
                  ),
                  _buildSummaryRow(
                    'Design',
                    widget.isPresetDesign ? 'Preset Design' : 'Custom Upload',
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
                          'Amount due now',
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
                hintText: 'e.g. specific placement of design, color notes...',
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
              const SizedBox(height: 2),
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

  Widget _buildPaymentTypeCard(
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
                fontSize: 12,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }
}
