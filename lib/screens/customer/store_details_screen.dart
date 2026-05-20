import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../models/store_model.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import 'product/product_details_screen.dart';

class StoreDetailsScreen extends StatelessWidget {
  final StoreModel store;

  const StoreDetailsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.blue[700],
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: store.imageUrl.isNotEmpty
                  ? Image.network(
                      store.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.blue[100],
                      child: Center(
                        child: Icon(Icons.store, size: 64, color: Colors.blue[300]),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store name
                  Text(
                    store.storeName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Store info — compact row
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.location,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.contact,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    store.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Business Hours
                  if (store.businessHours.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            store.businessHours,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),

                  // Social Media
                  if (store.facebookUrl.isNotEmpty ||
                      store.instagramUrl.isNotEmpty ||
                      store.tiktokUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          if (store.facebookUrl.isNotEmpty)
                            _buildSocialIcon(Icons.facebook, 'Facebook', store.facebookUrl),
                          if (store.instagramUrl.isNotEmpty)
                            _buildSocialIcon(Icons.camera_alt, 'Instagram', store.instagramUrl),
                          if (store.tiktokUrl.isNotEmpty)
                            _buildSocialIcon(Icons.video_library, 'TikTok', store.tiktokUrl),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Products section
                  const Text(
                    'Available Products',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Product grid
                  StreamBuilder<List<ProductModel>>(
                    stream: ProductService().getProductsByStore(store.storeId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'No products available yet',
                              style: TextStyle(color: Colors.blue[400]),
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final product = snapshot.data![index];
                          return _buildProductCard(context, product);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.blue[700]),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
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

    final hasOutOfStock = product.variants.values.any((v) => v.stock == 0);
    final hasLowStock = product.variants.values.any(
      (v) => v.stock > 0 && v.stock <= 5,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ UPDATED: show real product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: Colors.blue[50],
                          child: const Center(
                            child: Text('👕', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.blue[50],
                        child: const Center(
                          child: Text('👕', style: TextStyle(fontSize: 40)),
                        ),
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasOutOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OOS',
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (hasLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Low',
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Price
                  Text(
                    product.priceRange,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Sizes
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: product.sizes.take(4).map((size) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          size,
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),

                  // Color dots + customizable badge
                  Row(
                    children: [
                      ...product.colors.take(4).map((colorName) {
                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: colorMap[colorName] ?? Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      // ✅ NEW: customizable badge
                      if (product.isCustomizable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Custom',
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
