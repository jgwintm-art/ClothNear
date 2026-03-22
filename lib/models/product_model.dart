class ProductVariant {
  final double price;
  final int stock;

  ProductVariant({required this.price, required this.stock});

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      price: (map['price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'price': price, 'stock': stock};
  }
}

class ProductModel {
  final String productId;
  final String storeId;
  final String name;
  final String type;
  final List<String> colors;
  final List<String> sizes;
  final double basePrice;
  final Map<String, ProductVariant> variants;
  final List<String> presetDesigns;
  final String imageUrl;
  final bool isCustomizable;

  ProductModel({
    required this.productId,
    required this.storeId,
    required this.name,
    required this.type,
    required this.colors,
    required this.sizes,
    required this.basePrice,
    required this.variants,
    this.presetDesigns = const [],
    this.imageUrl = '',
    this.isCustomizable = false,
  });

  static String variantKey(String color, String size) {
    return '${color.toLowerCase()}_${size.toLowerCase()}';
  }

  ProductVariant? getVariant(String color, String size) {
    return variants[variantKey(color, size)];
  }

  List<String> availableSizesForColor(String color) {
    return sizes.where((size) {
      final variant = getVariant(color, size);
      return variant != null;
    }).toList();
  }

  String get priceRange {
    if (variants.isEmpty) {
      return '₱${basePrice.toStringAsFixed(0)}';
    }
    final prices = variants.values.map((v) => v.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    if (minPrice == maxPrice) {
      return '₱${minPrice.toStringAsFixed(0)}';
    }
    return '₱${minPrice.toStringAsFixed(0)} - ₱${maxPrice.toStringAsFixed(0)}';
  }

  String priceRangeForColor(String color) {
    final colorVariants = variants.entries
        .where((e) => e.key.startsWith(color.toLowerCase()))
        .map((e) => e.value.price)
        .toList();
    if (colorVariants.isEmpty) return priceRange;
    final minPrice = colorVariants.reduce((a, b) => a < b ? a : b);
    final maxPrice = colorVariants.reduce((a, b) => a > b ? a : b);
    if (minPrice == maxPrice) {
      return '₱${minPrice.toStringAsFixed(0)}';
    }
    return '₱${minPrice.toStringAsFixed(0)} - ₱${maxPrice.toStringAsFixed(0)}';
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, ProductVariant> variants = {};
    if (map['variants'] != null) {
      (map['variants'] as Map<String, dynamic>).forEach((key, value) {
        variants[key] = ProductVariant.fromMap(value as Map<String, dynamic>);
      });
    }

    return ProductModel(
      productId: id,
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      colors: List<String>.from(map['colors'] ?? []),
      sizes: List<String>.from(map['sizes'] ?? []),
      basePrice: (map['basePrice'] ?? 0).toDouble(),
      variants: variants,
      presetDesigns: List<String>.from(map['presetDesigns'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      isCustomizable: map['isCustomizable'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> variantsMap = {};
    variants.forEach((key, value) {
      variantsMap[key] = value.toMap();
    });

    return {
      'storeId': storeId,
      'name': name,
      'type': type,
      'colors': colors,
      'sizes': sizes,
      'basePrice': basePrice,
      'variants': variantsMap,
      'presetDesigns': presetDesigns,
      'imageUrl': imageUrl,
      'isCustomizable': isCustomizable,
    };
  }
}
