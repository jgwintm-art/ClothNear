import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/product_model.dart';
import '../../../models/cart_model.dart';
import '../../../services/cart_service.dart';
import '../../../services/cloudinary_service.dart';
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

  // ✅ NEW: design choice — null = not chosen yet
  // true = plain, false = custom
  bool? _isPlain;
  String _customDesignUrl = '';
  String _customDesignFileName = '';
  bool _isUploadingDesign = false;

  ProductVariant? get _selectedVariant {
    if (_selectedColor == null || _selectedSize == null) return null;
    return widget.product.getVariant(_selectedColor!, _selectedSize!);
  }

  bool get _isCombinationValid => _selectedVariant != null;

  // ✅ NEW: cart ready when combination valid + design chosen (if customizable)
  bool get _isReadyToAdd {
    if (!_isCombinationValid) return false;
    if (!widget.product.isCustomizable) return true;
    if (_isPlain == null) return false;
    if (_isPlain == false && _customDesignUrl.isEmpty) return false;
    return true;
  }

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

  // ✅ NEW: upload custom design to Cloudinary
  Future<void> _uploadCustomDesign() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null) return;
      setState(() => _isUploadingDesign = true);

      final file = result.files.single;
      String url;

      if (file.path != null) {
        url = await CloudinaryService.uploadFile(file.path!);
      } else if (file.bytes != null) {
        url = await CloudinaryService.uploadBytes(file.bytes!, file.name);
      } else {
        throw Exception('Could not read file');
      }

      setState(() {
        _customDesignUrl = url;
        _customDesignFileName = file.name;
        _isUploadingDesign = false;
      });
    } catch (e) {
      setState(() => _isUploadingDesign = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

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
      // ✅ NEW: pass design info
      isPlain: _isPlain ?? true,
      customDesignUrl: _customDesignUrl,
      productImageUrl: widget.product.imageUrl,
    );
    await CartService().addToCart(uid, cartItem);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart!'),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 3),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorMap = {
      'Black': const Color(0xFF000000),
      'White': const Color(0xFFFFFFFF),
      'Red': const Color(0xFFFF0000),
      'Blue': const Color(0xFF0000FF),
      'Green': const Color(0xFF008000),
      'Gray': const Color(0xFF808080),
      'Yellow': const Color(0xFFFFFF00),
      'Navy': const Color(0xFF000080),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ✅ UPDATED: shows real product image if available
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
                    background: widget.product.imageUrl.isNotEmpty
                        ? Image.network(
                            widget.product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
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

                      // Product name + customizable badge
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.product.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // ✅ NEW: customizable badge
                            if (widget.product.isCustomizable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purple.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      size: 12,
                                      color: Colors.purple[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Customizable',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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

                      // ✅ NEW: Design section — only shows if customizable
                      if (widget.product.isCustomizable) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Design',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '— choose an option',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Plain or Custom toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _isPlain = true;
                                        _customDesignUrl = '';
                                        _customDesignFileName = '';
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isPlain == true
                                              ? Colors.blue[700]
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: _isPlain == true
                                                ? Colors.blue[700]!
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.checkroom_outlined,
                                              color: _isPlain == true
                                                  ? Colors.white
                                                  : Colors.grey[500],
                                              size: 22,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Plain',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _isPlain == true
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'No design',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _isPlain == true
                                                    ? Colors.blue[100]
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _isPlain = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isPlain == false
                                              ? Colors.blue[700]
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: _isPlain == false
                                                ? Colors.blue[700]!
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.upload_file_outlined,
                                              color: _isPlain == false
                                                  ? Colors.white
                                                  : Colors.grey[500],
                                              size: 22,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Custom Design',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _isPlain == false
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'Upload your design',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _isPlain == false
                                                    ? Colors.blue[100]
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // ✅ NEW: Upload area — only shows if Custom is chosen
                              if (_isPlain == false) ...[
                                const SizedBox(height: 12),
                                if (_customDesignUrl.isEmpty)
                                  GestureDetector(
                                    onTap: _isUploadingDesign
                                        ? null
                                        : _uploadCustomDesign,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: _isUploadingDesign
                                          ? const Center(
                                              child: Column(
                                                children: [
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 8),
                                                  Text('Uploading...'),
                                                ],
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                Icon(
                                                  Icons.cloud_upload_outlined,
                                                  size: 36,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Tap to upload design',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'PNG, JPG, PDF up to 10MB',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  )
                                else
                                  // ✅ Show uploaded file preview
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green[700],
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _customDesignFileName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Design uploaded ✓',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _uploadCustomDesign,
                                          child: const Text('Change'),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() {
                                            _customDesignUrl = '';
                                            _customDesignFileName = '';
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ NEW: hint text if not ready
                if (!_isReadyToAdd && _isCombinationValid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.product.isCustomizable && _isPlain == null
                          ? 'Please choose Plain or Custom Design above'
                          : widget.product.isCustomizable &&
                                _isPlain == false &&
                                _customDesignUrl.isEmpty
                          ? 'Please upload your custom design above'
                          : '',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isReadyToAdd ? _addToCart : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isReadyToAdd
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
                            color: _isReadyToAdd
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
                        onPressed: _isReadyToAdd
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
                          backgroundColor: _isReadyToAdd
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
                            color: _isReadyToAdd ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.blue[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text('👕', style: TextStyle(fontSize: 80)),
          if (_selectedColor != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedColor!}${_selectedSize != null ? ' • $_selectedSize' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
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
