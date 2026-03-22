import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cart_model.dart';
import '../../../services/cart_service.dart';
import '../orders/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cartService = CartService();

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
        stream: cartService.getCartItems(uid),
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
                    ...items.map(
                      (item) => _buildCartItem(context, uid, cartService, item),
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
                                'Subtotal (${items.length} item${items.length > 1 ? 's' : ''})',
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CheckoutScreen(items: items, totalAmount: subtotal),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Proceed to Checkout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  Widget _buildCartItem(
    BuildContext context,
    String uid,
    CartService cartService,
    CartItemModel item,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image or placeholder
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.productImageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.productImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Center(
                        child: Text('👕', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('👕', style: TextStyle(fontSize: 28)),
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
                const SizedBox(height: 2),
                Text(
                  '₱${item.price.toStringAsFixed(0)} each',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
                const SizedBox(height: 4),
                // Design badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.isPlain ? Colors.grey[100] : Colors.purple[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: item.isPlain
                          ? Colors.grey.shade300
                          : Colors.purple.shade200,
                    ),
                  ),
                  child: Text(
                    item.isPlain ? 'Plain' : 'Custom Design',
                    style: TextStyle(
                      fontSize: 9,
                      color: item.isPlain
                          ? Colors.grey[600]
                          : Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quantity + price + remove
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => cartService.removeFromCart(uid, item.cartItemId),
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => cartService.updateQuantity(
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
                      onTap: () => cartService.updateQuantity(
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
