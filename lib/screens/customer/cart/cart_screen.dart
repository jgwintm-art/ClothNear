import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cart_model.dart';
import '../../../services/cart_service.dart';
import '../../../services/product_service.dart';
import 'design_selection_screen.dart';
import '../orders/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _productService = ProductService();
  String? _designUrl;
  bool _isPresetDesign = true;

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: uid fetched here and passed to all CartService calls
    final uid = FirebaseAuth.instance.currentUser!.uid;

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
          'My Cart',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<CartItemModel>>(
        // ✅ FIXED: passing uid to getCartItems
        stream: _cartService.getCartItems(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse stores to add items',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!;
          final subtotal = items.fold<double>(
            0,
            (sum, item) => sum + item.totalPrice,
          );

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Cart items
                    ...items.map((item) => _buildCartItem(uid, item)),
                    const SizedBox(height: 16),

                    // Design section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Design for Order',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_designUrl != null)
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isPresetDesign
                                        ? 'Preset design selected ✓'
                                        : 'Custom design uploaded ✓',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openDesignSelection(items),
                                  child: const Text('Change'),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openDesignSelection(items),
                                icon: const Icon(Icons.palette_outlined),
                                label: const Text('Choose Design'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blue[700]!),
                                  foregroundColor: Colors.blue[700],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal (${items.length} items)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₱${subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Half payment: ₱${(subtotal / 2).toStringAsFixed(2)} now',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Checkout button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _designUrl != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                items: items,
                                designUrl: _designUrl!,
                                isPresetDesign: _isPresetDesign,
                                totalAmount: subtotal,
                              ),
                            ),
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _designUrl == null
                          ? 'Choose a Design First'
                          : 'Proceed to Checkout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _designUrl == null
                            ? Colors.grey[500]
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDesignSelection(List<CartItemModel> items) async {
    List<String> presetDesigns = [];
    if (items.isNotEmpty) {
      final product = await _productService.getProductById(
        items.first.productId,
      );
      presetDesigns = product?.presetDesigns ?? [];
    }

    if (!mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DesignSelectionScreen(
          presetDesigns: presetDesigns,
          currentDesignUrl: _designUrl,
          currentIsPreset: _designUrl != null ? _isPresetDesign : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _designUrl = result['designUrl'] as String;
        _isPresetDesign = result['isPreset'] as bool;
      });
    }
  }

  // ✅ FIXED: uid now passed to removeFromCart and updateQuantity
  Widget _buildCartItem(String uid, CartItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Product icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('👕', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.color} • ${item.size}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${item.price.toStringAsFixed(0)} each',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ],
            ),
          ),

          // Quantity + price column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ✅ FIXED: removeFromCart now passes uid
              GestureDetector(
                onTap: () => _cartService.removeFromCart(uid, item.cartItemId),
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
              const SizedBox(height: 8),
              // Qty selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      // ✅ FIXED: updateQuantity now passes uid
                      onTap: () => _cartService.updateQuantity(
                        uid,
                        item.cartItemId,
                        item.quantity - 1,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '−',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      // ✅ FIXED: updateQuantity now passes uid
                      onTap: () => _cartService.updateQuantity(
                        uid,
                        item.cartItemId,
                        item.quantity + 1,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '+',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₱${item.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
