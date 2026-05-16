import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';

class WorkerInventoryScreen extends StatefulWidget {
  final String storeId;

  const WorkerInventoryScreen({super.key, required this.storeId});

  @override
  State<WorkerInventoryScreen> createState() => _WorkerInventoryScreenState();
}

class _WorkerInventoryScreenState extends State<WorkerInventoryScreen> {
  final _productService = ProductService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getLowStockVariants(ProductModel product) {
    final low = <String>[];
    product.variants.forEach((key, variant) {
      if (variant.stock > 0 && variant.stock <= 5) {
        final parts = key.split('_');
        final color = parts.isNotEmpty
            ? parts[0][0].toUpperCase() + parts[0].substring(1)
            : key;
        final size = parts.length > 1 ? parts[1].toUpperCase() : '';
        low.add('$color $size: ${variant.stock} left');
      }
    });
    return low;
  }

  List<String> _getOutOfStockVariants(ProductModel product) {
    final out = <String>[];
    product.variants.forEach((key, variant) {
      if (variant.stock == 0) {
        final parts = key.split('_');
        final color = parts.isNotEmpty
            ? parts[0][0].toUpperCase() + parts[0].substring(1)
            : key;
        final size = parts.length > 1 ? parts[1].toUpperCase() : '';
        out.add('$color $size');
      }
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'View Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<ProductModel>>(
              stream: _productService.getProductsByStore(widget.storeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  );
                }

                final products = (snapshot.data ?? []).where((p) {
                  if (_searchQuery.isEmpty) return true;
                  return p.name.toLowerCase().contains(_searchQuery) ||
                      p.type.toLowerCase().contains(_searchQuery);
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 72,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products in inventory'
                              : 'No products match "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Stock summary banner
                final totalProducts = products.length;
                final outOfStockCount = products.where((p) {
                  return p.variants.values.every((v) => v.stock == 0);
                }).length;
                final lowStockCount = products.where((p) {
                  return _getLowStockVariants(p).isNotEmpty;
                }).length;

                return Column(
                  children: [
                    // Summary banner
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Total', '$totalProducts', Colors.white),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white30,
                          ),
                          _buildStat(
                            'Low Stock',
                            '$lowStockCount',
                            Colors.yellow[200]!,
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white30,
                          ),
                          _buildStat(
                            'Out of Stock',
                            '$outOfStockCount',
                            Colors.red[200]!,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildProductCard(products[index]),
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

  Widget _buildStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final lowStock = _getLowStockVariants(product);
    final outOfStock = _getOutOfStockVariants(product);
    final totalStock = product.variants.values.fold(
      0,
      (sum, v) => sum + v.stock,
    );
    final hasWarning = lowStock.isNotEmpty || outOfStock.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: outOfStock.length == product.variants.length
              ? Colors.red[200]!
              : hasWarning
              ? Colors.orange[200]!
              : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: product.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.checkroom_outlined,
                          color: Colors.orange[300],
                        ),
                      ),
                    )
                  : Icon(Icons.checkroom_outlined, color: Colors.orange[300]),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: totalStock == 0
                              ? Colors.red[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$totalStock pcs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: totalStock == 0
                                ? Colors.red[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.type,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Text(
                    product.priceRange,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (outOfStock.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: outOfStock
                          .take(4)
                          .map(
                            (v) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                v,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (lowStock.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...lowStock
                        .take(3)
                        .map(
                          (v) => Text(
                            '⚠ $v',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
