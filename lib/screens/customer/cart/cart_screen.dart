import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cart_model.dart';
import '../../../services/cart_service.dart';
import '../orders/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Tracks which cart item IDs are selected for checkout.
  final Set<String> _selectedIds = {};
  bool _selectionInitialised = false;

  /// Called OUTSIDE build() via addPostFrameCallback to avoid
  /// mutating state during a build pass (which causes silent crashes).
  void _syncSelection(List<CartItemModel> items) {
    if (!_selectionInitialised) {
      // First load — select everything by default.
      setState(() {
        _selectedIds.addAll(items.map((i) => i.cartItemId));
        _selectionInitialised = true;
      });
    } else {
      // Subsequent updates — prune IDs for items that no longer exist.
      final currentIds = items.map((i) => i.cartItemId).toSet();
      final stale = _selectedIds.difference(currentIds);
      if (stale.isNotEmpty) {
        setState(() => _selectedIds.removeAll(stale));
      }
    }
  }

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

          // Sync selection AFTER the current build frame completes —
          // never mutate state during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncSelection(items);
          });

          // Derive selected items from the current _selectedIds set.
          // Use a safe intersection so stale IDs never cause issues.
          final selectedItems = items
              .where((i) => _selectedIds.contains(i.cartItemId))
              .toList();

          final subtotal = items.fold<double>(
            0,
            (sum, item) => sum + item.totalPrice,
          );

          final selectedSubtotal = selectedItems.fold<double>(
            0,
            (sum, item) => sum + item.totalPrice,
          );

          final allSelected =
              items.isNotEmpty && _selectedIds.length == items.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Select-all row ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: allSelected,
                            activeColor: Colors.blue[700],
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedIds.addAll(
                                    items.map((i) => i.cartItemId),
                                  );
                                } else {
                                  _selectedIds.clear();
                                }
                              });
                            },
                          ),
                          Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedIds.length}/${items.length} selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...items.map(
                      (item) => _buildCartItem(
                        context,
                        uid,
                        cartService,
                        item,
                        isSelected: _selectedIds.contains(item.cartItemId),
                        onToggle: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedIds.add(item.cartItemId);
                            } else {
                              _selectedIds.remove(item.cartItemId);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Order summary ───────────────────────────────────────
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
                                'Cart Total (${items.length} item${items.length > 1 ? 's' : ''})',
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
                          if (_selectedIds.length != items.length) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected (${_selectedIds.length} item${_selectedIds.length != 1 ? 's' : ''})',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '₱${selectedSubtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Checkout Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₱${selectedSubtotal.toStringAsFixed(2)}',
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

              // ── Checkout button ─────────────────────────────────────────
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
                    onPressed: selectedItems.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                items: selectedItems,
                                totalAmount: selectedSubtotal,
                              ),
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      selectedItems.isEmpty
                          ? 'Select items to checkout'
                          : 'Proceed to Checkout (${selectedItems.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: selectedItems.isEmpty
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

  Widget _buildCartItem(
    BuildContext context,
    String uid,
    CartService cartService,
    CartItemModel item, {
    required bool isSelected,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Checkbox ──────────────────────────────────────────────────────
          Checkbox(
            value: isSelected,
            activeColor: Colors.blue[700],
            onChanged: (checked) => onToggle(checked ?? false),
          ),

          // ── Product image ─────────────────────────────────────────────────
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

          // ── Item details ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          item.isPlain ? Colors.grey[100] : Colors.purple[50],
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
          ),

          // ── Quantity + price + remove ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () =>
                      cartService.removeFromCart(uid, item.cartItemId),
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
          ),
        ],
      ),
    );
  }
}
