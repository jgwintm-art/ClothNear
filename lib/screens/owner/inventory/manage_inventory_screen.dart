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

                // Product list
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

                      // Summary stats
                      final products = snapshot.data!;
                      final filtered = products
                          .where(
                            (p) => p.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                      final totalStock = products.fold<int>(
                        0,
                        (sum, p) =>
                            sum +
                            p.variants.values.fold<int>(
                              0,
                              (s, v) => s + v.stock,
                            ),
                      );

                      final lowStockCount = products.where((p) {
                        final totalProductStock = p.variants.values.fold<int>(
                          0,
                          (s, v) => s + v.stock,
                        );
                        return totalProductStock > 0 && totalProductStock <= 5;
                      }).length;

                      return Column(
                        children: [
                          // Stats row
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildStatCard(
                                  'Products',
                                  products.length.toString(),
                                  Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  'Total Stock',
                                  totalStock.toString(),
                                  Colors.green,
                                ),
                                const SizedBox(width: 12),
                                _buildStatCard(
                                  'Low Stock',
                                  lowStockCount.toString(),
                                  lowStockCount > 0 ? Colors.red : Colors.green,
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(ProductModel product) {
    final totalStock = product.variants.values.fold<int>(
      0,
      (sum, v) => sum + v.stock,
    );
    final isLowStock = totalStock > 0 && totalStock <= 5;
    final isOutOfStock = totalStock == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock || isOutOfStock
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('👕', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isOutOfStock)
                        _buildBadge('Out of Stock', Colors.red)
                      else if (isLowStock)
                        _buildBadge('Low Stock', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceRange,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: $totalStock pcs',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLowStock || isOutOfStock
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Sizes
                  Text(
                    'Sizes: ${product.sizes.join(', ')}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  // Color dots
                  Row(
                    children: product.colors.map((colorName) {
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
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: colorMap[colorName] ?? Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Actions
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
                      builder: (context) => AddEditItemScreen(product: product),
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
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
