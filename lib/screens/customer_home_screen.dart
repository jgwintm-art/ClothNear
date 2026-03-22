import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer/browse_stores_screen.dart';
import '../services/cart_service.dart';
import 'customer/cart/cart_screen.dart';
import 'customer/orders/order_status_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'ClothNear',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        // ✅ CHANGED: actions now has 3 buttons instead of just logout
        // Added cart icon with badge and orders icon
        actions: [
          // ✅ NEW: Cart icon with live badge counter
          StreamBuilder<int>(
            stream: CartService().getCartCount(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.blue[700],
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ✅ NEW: Orders icon to view order status
          IconButton(
            icon: Icon(Icons.receipt_long_outlined, color: Colors.blue[700]),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrderStatusScreen(),
              ),
            ),
          ),
          // ✅ UNCHANGED: Logout button — same as before
          IconButton(
            icon: Icon(Icons.logout, color: Colors.blue[700]),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: const BrowseStoresScreen(),
    );
  }
}
