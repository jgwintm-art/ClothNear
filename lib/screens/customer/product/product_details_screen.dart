import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cart_model.dart';
import '../../../services/cart_service.dart';
import '../cart/cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  ProductVariant? get _selectedVariant {
    if (_selectedColor == null || _selectedSize == null) return null;
    return widget.product.getVariant(_selectedColor!, _selectedSize!);
  }

  bool get _isCombinationValid => _selectedVariant != null;

  bool _isSizeAvailable(String size) {
    if (_selectedColor == null) return false;
    final variant = widget.product.getVariant(_selectedColor!, size);
    return variant != null && variant.stock > 0;
  }

  bool _isSizeExistsForColor(String size) {
    if (_selectedColor == null) return false;
    return widget.product.getVariant(_selectedColor!, size) != null;
  }

  String get _displayPrice {
    if (_selectedVariant != null) {
      return '₱${_selectedVariant!.price.toStringAsFixed(0)}';
    }
    if (_selectedColor != null) {
      return widget.product.priceRangeForColor(_selectedColor!);
    }
    return widget.product.priceRange;
  }

  void _selectColor(String color) {
    setState(() {
      _selectedColor = color;
      _selectedSize = null;
      _quantity = 1;
    });
  }

  void _selectSize(String size) {
    if (!_isSizeAvailable(size)) return;
    setState(() {
      _selectedSize = size;
      _quantity = 1;
    });
  }

  // ✅ FIXED: addToCart now passes uid as first arg
  // CartItemModel uses storeStoreName instead of customerUid
  Future<void> _addToCart() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cartItem = CartItemModel(
      cartItemId: '',
      productId: widget.product.productId,
      storeId: widget.product.storeId,
      productName: widget.product.name,
      color: _selectedColor!,
      size: _selectedSize!,
      price: _selectedVariant!.price,
      quantity: _quantity,
      storeStoreName: '',
    );
    await CartService().addToCart(uid, cartItem);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart!'),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorMap = {
      'Black': Colors.black,
      'White': Colors.white,
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Gray': Colors.grey,
      'Yellow': Colors.yellow,
      'Navy': const Color(0xFF000080),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: Colors.blue[50],
                  leading: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, color: Colors.blue[700]),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.blue[50],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          const Text('👕', style: TextStyle(fontSize: 100)),
                          if (_selectedColor != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedColor!}${_selectedSize != null ? ' • $_selectedSize' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price section
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Colors.white,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedVariant != null)
                                  Text(
                                    widget.product.priceRange,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  _displayPrice,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (_selectedVariant != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  '${_selectedVariant!.stock} pcs left',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Text(
                                _selectedColor == null
                                    ? 'Select variant'
                                    : 'Select size',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Product name
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Divider(height: 1),

                      // Color selection
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Color',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedColor != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedColor!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ] else
                                  Text(
                                    ' — select one',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: widget.product.colors.map((color) {
                                final isSelected = _selectedColor == color;
                                return GestureDetector(
                                  onTap: () => _selectColor(color),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: colorMap[color] ?? Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue[700]!
                                            : Colors.grey.shade300,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color:
                                                color == 'White' ||
                                                    color == 'Yellow'
                                                ? Colors.black
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Size selection
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Size',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedColor == null)
                                  Text(
                                    ' — select color first',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  )
                                else if (_selectedSize != null)
                                  Text(
                                    ' — $_selectedSize',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  )
                                else
                                  Text(
                                    ' — select one',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: widget.product.sizes.map((size) {
                                final isSelected = _selectedSize == size;
                                final isAvailable = _isSizeAvailable(size);
                                final exists = _isSizeExistsForColor(size);
                                final isDisabled =
                                    _selectedColor == null ||
                                    !exists ||
                                    !isAvailable;

                                return GestureDetector(
                                  onTap: () => _selectSize(size),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue[700]
                                              : isDisabled
                                              ? Colors.grey[100]
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.blue[700]!
                                                : isDisabled
                                                ? Colors.grey.shade200
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            size,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.white
                                                  : isDisabled
                                                  ? Colors.grey[400]
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (exists && !isAvailable)
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _StrikethroughPainter(),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Quantity
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isCombinationValid
                                    ? Colors.black
                                    : Colors.grey[400],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed:
                                        _isCombinationValid && _quantity > 1
                                        ? () => setState(() => _quantity--)
                                        : null,
                                    icon: const Icon(Icons.remove),
                                    iconSize: 18,
                                    color: Colors.blue[700],
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '$_quantity',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        _isCombinationValid &&
                                            _quantity <
                                                (_selectedVariant?.stock ?? 0)
                                        ? () => setState(() => _quantity++)
                                        : null,
                                    icon: const Icon(Icons.add),
                                    iconSize: 18,
                                    color: Colors.blue[700],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Stock info
                      if (_isCombinationValid)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_selectedVariant!.stock} pcs available',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Max order: ${_selectedVariant!.stock}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCombinationValid ? _addToCart : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isCombinationValid
                            ? Colors.blue[700]!
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: _isCombinationValid
                            ? Colors.blue[700]
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCombinationValid
                        ? () async {
                            await _addToCart();
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CartScreen(),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCombinationValid
                          ? Colors.blue[700]
                          : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Order Now',
                      style: TextStyle(
                        color: _isCombinationValid ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class _StrikethroughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(4, size.height - 4),
      Offset(size.width - 4, 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
