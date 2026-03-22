import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/product_model.dart';
import '../../../services/product_service.dart';
import '../../../services/store_service.dart';
import '../../../services/cloudinary_service.dart';

class AddEditItemScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditItemScreen({super.key, this.product});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _productService = ProductService();
  final _storeService = StoreService();
  bool _isLoading = false;
  bool _isUploadingImage = false;

  List<String> _selectedSizes = [];
  List<String> _selectedColors = [];
  final Map<String, TextEditingController> _variantPriceControllers = {};
  final Map<String, TextEditingController> _variantStockControllers = {};

  // ✅ NEW: product image and customizable flag
  String _productImageUrl = '';
  bool _isCustomizable = false;

  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'Black', 'color': const Color(0xFF000000)},
    {'name': 'White', 'color': const Color(0xFFFFFFFF)},
    {'name': 'Red', 'color': const Color(0xFFFF0000)},
    {'name': 'Blue', 'color': const Color(0xFF0000FF)},
    {'name': 'Green', 'color': const Color(0xFF008000)},
    {'name': 'Gray', 'color': const Color(0xFF808080)},
    {'name': 'Yellow', 'color': const Color(0xFFFFFF00)},
    {'name': 'Navy', 'color': const Color(0xFF000080)},
  ];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.product!.name;
      _typeController.text = widget.product!.type;
      _basePriceController.text = widget.product!.basePrice.toString();
      _selectedSizes = List.from(widget.product!.sizes);
      _selectedColors = List.from(widget.product!.colors);
      _productImageUrl = widget.product!.imageUrl;
      _isCustomizable = widget.product!.isCustomizable;
      _initVariantControllers();
    }
  }

  void _initVariantControllers() {
    for (final color in _selectedColors) {
      for (final size in _selectedSizes) {
        final key = ProductModel.variantKey(color, size);
        final existing = widget.product?.variants[key];
        _variantPriceControllers[key] = TextEditingController(
          text: existing?.price.toString() ?? _basePriceController.text,
        );
        _variantStockControllers[key] = TextEditingController(
          text: existing?.stock.toString() ?? '0',
        );
      }
    }
  }

  void _updateVariantControllers() {
    for (final color in _selectedColors) {
      for (final size in _selectedSizes) {
        final key = ProductModel.variantKey(color, size);
        if (!_variantPriceControllers.containsKey(key)) {
          _variantPriceControllers[key] = TextEditingController(
            text: _basePriceController.text,
          );
          _variantStockControllers[key] = TextEditingController(text: '0');
        }
      }
    }
  }

  void _toggleSize(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        _selectedSizes.remove(size);
      } else {
        _selectedSizes.add(size);
      }
      _updateVariantControllers();
    });
  }

  void _toggleColor(String color) {
    setState(() {
      if (_selectedColors.contains(color)) {
        _selectedColors.remove(color);
      } else {
        _selectedColors.add(color);
      }
      _updateVariantControllers();
    });
  }

  Future<void> _uploadProductImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null) return;
      setState(() => _isUploadingImage = true);

      final file = result.files.single;
      String url;

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        url = await CloudinaryService.uploadBytes(file.bytes!, file.name);
      } else if (file.path != null && file.path!.isNotEmpty) {
        url = await CloudinaryService.uploadFile(file.path!);
      } else {
        throw Exception('Could not read file — please try again');
      }

      setState(() {
        _productImageUrl = url;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty ||
        _typeController.text.isEmpty ||
        _basePriceController.text.isEmpty ||
        _selectedSizes.isEmpty ||
        _selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ownerUid = FirebaseAuth.instance.currentUser!.uid;
      final store = await _storeService.getStoreByOwner(ownerUid).first;
      if (store == null) throw Exception('Store not found');

      Map<String, ProductVariant> variants = {};
      for (final color in _selectedColors) {
        for (final size in _selectedSizes) {
          final key = ProductModel.variantKey(color, size);
          variants[key] = ProductVariant(
            price:
                double.tryParse(_variantPriceControllers[key]?.text ?? '') ??
                double.parse(_basePriceController.text),
            stock: int.tryParse(_variantStockControllers[key]?.text ?? '') ?? 0,
          );
        }
      }

      final product = ProductModel(
        productId: widget.product?.productId ?? '',
        storeId: store.storeId,
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        colors: _selectedColors,
        sizes: _selectedSizes,
        basePrice: double.parse(_basePriceController.text),
        variants: variants,
        imageUrl: _productImageUrl,
        isCustomizable: _isCustomizable,
      );

      if (_isEditing) {
        await _productService.updateProduct(
          widget.product!.productId,
          product.toMap(),
        );
      } else {
        await _productService.addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Product updated!' : 'Product added successfully!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          _isEditing ? 'Edit Item' : 'Add New Item',
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
            // ✅ NEW: Product Image Upload Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Product Image'),
                  const SizedBox(height: 4),
                  Text(
                    'Upload a photo of your product',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _uploadProductImage,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _productImageUrl.isNotEmpty
                              ? Colors.blue[700]!
                              : Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _isUploadingImage
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Uploading image...'),
                                ],
                              ),
                            )
                          : _productImageUrl.isNotEmpty
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    _productImageUrl,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        _buildImagePlaceholder(),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _productImageUrl = ''),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _uploadProductImage,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[700],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Change Photo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildImagePlaceholder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Basic Info Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Basic Information'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Product Name',
                    hint: 'e.g. Plain T-Shirt',
                    icon: Icons.checkroom_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _typeController,
                    label: 'Clothing Type',
                    hint: 'e.g. T-Shirt, Hoodie, Polo',
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _basePriceController,
                    label: 'Base Price (₱)',
                    hint: 'Default price for all variants',
                    icon: Icons.price_change_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isCustomizable
                          ? Colors.blue[50]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isCustomizable
                            ? Colors.blue[200]!
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: _isCustomizable
                              ? Colors.blue[700]
                              : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Allow Custom Design',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isCustomizable
                                      ? Colors.blue[700]
                                      : Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Customers can upload their own design',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isCustomizable,
                          onChanged: (value) =>
                              setState(() => _isCustomizable = value),
                          activeThumbColor: Colors.blue[700],
                          activeTrackColor: Colors.blue[200],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sizes Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Available Sizes'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSizes.map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return GestureDetector(
                        onTap: () => _toggleSize(size),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[700] : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue[700]!
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            size,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Colors Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Available Colors'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableColors.map((colorMap) {
                      final colorName = colorMap['name'] as String;
                      final color = colorMap['color'] as Color;
                      final isSelected = _selectedColors.contains(colorName);
                      return GestureDetector(
                        onTap: () => _toggleColor(colorName),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
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
                                      color:
                                          colorName == 'White' ||
                                              colorName == 'Yellow'
                                          ? Colors.black
                                          : Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              colorName,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
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
            const SizedBox(height: 16),

            // Variants Card
            if (_selectedColors.isNotEmpty && _selectedSizes.isNotEmpty)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Variant Price & Stock'),
                    const SizedBox(height: 4),
                    Text(
                      'Set price and stock for each combination',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),
                    ..._selectedColors.map((color) {
                      final colorData = _availableColors.firstWhere(
                        (c) => c['name'] == color,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: colorData['color'] as Color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  color,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._selectedSizes.map((size) {
                            final key = ProductModel.variantKey(color, size);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        size,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _variantPriceControllers[key],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Price ₱',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.blue[700]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _variantStockControllers[key],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Stock',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.blue[700]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditing ? 'Update Item' : 'Save Item',
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

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to upload product image',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG, PNG recommended',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.blue[700],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue[700]!),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _basePriceController.dispose();
    for (final c in _variantPriceControllers.values) {
      c.dispose();
    }
    for (final c in _variantStockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
