import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/product_model.dart';
import '../../../services/product_service.dart';
import '../../../services/store_service.dart';
import '../../../services/pricing_service.dart';

class ManagePricingScreen extends StatefulWidget {
  const ManagePricingScreen({super.key});

  @override
  State<ManagePricingScreen> createState() => _ManagePricingScreenState();
}

class _ManagePricingScreenState extends State<ManagePricingScreen> {
  final _productService = ProductService();
  final _storeService = StoreService();
  final _pricingService = PricingService();

  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final store = await _storeService.getStoreByOwner(uid).first;
    if (store != null && mounted) {
      setState(() => _storeId = store.storeId);
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
          icon: Icon(Icons.arrow_back, color: Colors.purple[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Pricing',
          style: TextStyle(
            color: Colors.purple[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _storeId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<ProductModel>>(
              stream: _productService.getProductsByStore(_storeId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.price_change_outlined,
                          size: 72,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add products in Manage Inventory first.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ProductPricingCard(
                      product: products[index],
                      pricingService: _pricingService,
                    );
                  },
                );
              },
            ),
    );
  }
}

// ─── Per-product pricing card ─────────────────────────────────────────────────

class _ProductPricingCard extends StatefulWidget {
  final ProductModel product;
  final PricingService pricingService;

  const _ProductPricingCard({
    required this.product,
    required this.pricingService,
  });

  @override
  State<_ProductPricingCard> createState() => _ProductPricingCardState();
}

class _ProductPricingCardState extends State<_ProductPricingCard> {
  late TextEditingController _basePriceController;
  final Map<String, TextEditingController> _variantControllers = {};
  bool _expanded = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _basePriceController = TextEditingController(
      text: widget.product.basePrice.toStringAsFixed(0),
    );
    widget.product.variants.forEach((key, variant) {
      _variantControllers[key] = TextEditingController(
        text: variant.price.toStringAsFixed(0),
      );
    });
  }

  @override
  void dispose() {
    _basePriceController.dispose();
    for (final c in _variantControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final newBase = double.tryParse(_basePriceController.text);
    if (newBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid base price.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Map<String, double> variantPrices = {};
    for (final entry in _variantControllers.entries) {
      final price = double.tryParse(entry.value.text);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid price for variant ${entry.key}.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      variantPrices[entry.key] = price;
    }

    setState(() => _isSaving = true);
    try {
      await widget.pricingService.updateAllVariantPrices(
        widget.product.productId,
        variantPrices,
        newBase,
      );
      if (!mounted) return;
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prices updated for ${widget.product.name}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Apply the base price to every variant controller at once.
  void _applyBasePriceToAll() {
    final base = _basePriceController.text;
    for (final c in _variantControllers.values) {
      c.text = base;
    }
    setState(() => _hasChanges = true);
  }

  String _formatVariantLabel(String key) {
    // key format: "black_m" → "Black — M"
    final parts = key.split('_');
    if (parts.length < 2) return key.toUpperCase();
    final color =
        parts[0][0].toUpperCase() + parts[0].substring(1).toLowerCase();
    final size = parts[1].toUpperCase();
    return '$color — $size';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasChanges ? Colors.purple[200]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Product image or placeholder
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: widget.product.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.checkroom_outlined,
                                color: Colors.purple[300],
                              ),
                            ),
                          )
                        : Icon(
                            Icons.checkroom_outlined,
                            color: Colors.purple[300],
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.product.priceRange,
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_hasChanges)
                          Text(
                            'Unsaved changes',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Base price row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base Price (₱)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _basePriceController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) =>
                                  setState(() => _hasChanges = true),
                              decoration: InputDecoration(
                                prefixText: '₱ ',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.purple[700]!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: OutlinedButton.icon(
                          onPressed: _applyBasePriceToAll,
                          icon: const Icon(Icons.sync_alt, size: 16),
                          label: const Text(
                            'Apply to all',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple[700],
                            side: BorderSide(color: Colors.purple[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Variant prices
                  if (_variantControllers.isNotEmpty) ...[
                    Text(
                      'Variant Prices',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...widget.product.colors.map((color) {
                      final colorVariants = _variantControllers.entries
                          .where((e) => e.key.startsWith(color.toLowerCase()))
                          .toList();
                      if (colorVariants.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              color,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple[700],
                              ),
                            ),
                          ),
                          ...colorVariants.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      _formatVariantLabel(entry.key),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: entry.value,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) =>
                                          setState(() => _hasChanges = true),
                                      decoration: InputDecoration(
                                        prefixText: '₱ ',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
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
                                            color: Colors.purple[700]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    }),
                  ],

                  const SizedBox(height: 8),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: (_hasChanges && !_isSaving) ? _save : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_isSaving ? 'Saving...' : 'Save Prices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
