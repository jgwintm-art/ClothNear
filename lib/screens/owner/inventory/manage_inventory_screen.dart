import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/product_model.dart';
import '../../../services/product_service.dart';
import '../../../services/store_service.dart';
import 'add_edit_item_screen.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  final _productService = ProductService();
  final _storeService = StoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    final store = await _storeService.getStoreByOwner(ownerUid).first;
    if (store != null && mounted) {
      setState(() => _storeId = store.storeId);
    }
  }

  // Get all low stock variants for a product (stock > 0 but <= 5)
  List<String> _getLowStockVariants(ProductModel product) {
    List<String> lowVariants = [];
    product.variants.forEach((key, variant) {
      if (variant.stock > 0 && variant.stock <= 5) {
        final parts = key.split('_');
        final color = parts.isNotEmpty
            ? parts[0][0].toUpperCase() + parts[0].substring(1)
            : key;
        final size = parts.length > 1 ? parts[1].toUpperCase() : '';
        lowVariants.add('$color $size: ${variant.stock} pcs left');
      }
    });
    return lowVariants;
  }

  // Get all out of stock variants for a product (stock == 0)
  List<String> _getOutOfStockVariants(ProductModel product) {
    List<String> outVariants = [];
    product.variants.forEach((key, variant) {
      if (variant.stock == 0) {
        final parts = key.split('_');
        final color = parts.isNotEmpty
            ? parts[0][0].toUpperCase() + parts[0].substring(1)
            : key;
        final size = parts.length > 1 ? parts[1].toUpperCase() : '';
        outVariants.add('$color $size: Out of stock');
      }
    });
    return outVariants;
  }

  // Get total stock across all variants
  int _getTotalStock(ProductModel product) {
    return product.variants.values.fold(0, (sum, v) => sum + v.stock);
  }

  // Get product status: 'out', 'low', 'good'
  String _getProductStatus(ProductModel product) {
    final totalStock = _getTotalStock(product);
    if (totalStock == 0) return 'out';
    final hasLowVariants = product.variants.values.any(
      (v) => v.stock > 0 && v.stock <= 5,
    );
    final hasOutVariants = product.variants.values.any((v) => v.stock == 0);
    if (hasOutVariants || hasLowVariants) return 'low';
    return 'good';
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _productService.deleteProduct(product.productId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted')));
      }
    }
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
          'Manage Inventory',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: Colors.blue[700], size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditItemScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _storeId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: StreamBuilder<List<ProductModel>>(
                    stream: _productService.getProductsByStore(_storeId!),
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
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add your first product',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final products = snapshot.data!;
                      final filtered = products
                          .where(
                            (p) => p.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                      // Calculate stats at variant level
                      final totalStock = products.fold<int>(
                        0,
                        (sum, p) => sum + _getTotalStock(p),
                      );

                      final lowStockVariantCount = products.fold<int>(
                        0,
                        (sum, p) => sum + _getLowStockVariants(p).length,
                      );

                      final outOfStockVariantCount = products.fold<int>(
                        0,
                        (sum, p) => sum + _getOutOfStockVariants(p).length,
                      );

                      return Column(
                        children: [
                          // Stats row — 4 cards
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildStatCard(
                                  'Products',
                                  products.length.toString(),
                                  Colors.blue,
                                  Colors.blue[50]!,
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  'Total Stock',
                                  totalStock.toString(),
                                  Colors.green,
                                  Colors.green[50]!,
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  'Low Stock',
                                  lowStockVariantCount.toString(),
                                  Colors.orange,
                                  Colors.orange[50]!,
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  'Out of Stock',
                                  outOfStockVariantCount.toString(),
                                  Colors.red,
                                  Colors.red[50]!,
                                ),
                              ],
                            ),
                          ),

                          // Product list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildProductItem(filtered[index]);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color textColor,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(ProductModel product) {
    final status = _getProductStatus(product);
    final totalStock = _getTotalStock(product);
    final lowVariants = _getLowStockVariants(product);
    final outVariants = _getOutOfStockVariants(product);
    final allAffectedVariants = [...outVariants, ...lowVariants];

    // Border and accent colors based on status
    Color borderColor;
    Color accentColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (status) {
      case 'out':
        borderColor = Colors.red.shade300;
        accentColor = Colors.red;
        badgeBg = Colors.red[50]!;
        badgeText = Colors.red[800]!;
        badgeLabel = 'Fully out of stock';
        break;
      case 'low':
        borderColor = Colors.orange.shade300;
        accentColor = Colors.orange;
        badgeBg = Colors.orange[50]!;
        badgeText = Colors.orange[800]!;
        badgeLabel =
            '${allAffectedVariants.length} variant${allAffectedVariants.length > 1 ? 's' : ''} affected';
        break;
      default:
        borderColor = Colors.green.shade200;
        accentColor = Colors.green[800]!;
        badgeBg = Colors.green[50]!;
        badgeText = Colors.green[800]!;
        badgeLabel = 'All stocked';
    }

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('👕', style: TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Product details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + badge
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: badgeText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Price
                              Text(
                                product.priceRange,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Stock
                              Text(
                                'Total Stock: $totalStock pcs  •  Sizes: ${product.sizes.join(', ')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: status == 'out'
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Color dots
                              Row(
                                children: product.colors.map((colorName) {
                                  return Container(
                                    width: 14,
                                    height: 14,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: colorMap[colorName] ?? Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        // Edit/Delete buttons
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddEditItemScreen(product: product),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outlined,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteProduct(product),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Variant alert pills
                    if (allAffectedVariants.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Variant alerts:',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: allAffectedVariants.take(4).map((
                                variant,
                              ) {
                                final isOut = variant.contains('Out of stock');
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOut
                                        ? Colors.red[50]
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOut
                                          ? Colors.red.shade200
                                          : Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    variant,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isOut
                                          ? Colors.red[800]
                                          : Colors.orange[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // Show "+X more" if more than 4 affected variants
                          if (allAffectedVariants.length > 4)
                            Text(
                              '+${allAffectedVariants.length - 4} more',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
