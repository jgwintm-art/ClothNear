import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/product_model.dart';
import '../../../services/product_service.dart';
import '../../../services/store_service.dart';
import '../../../services/pricing_service.dart';
import '../../../services/ai_pricing_service.dart';
import '../../../config/env_config.dart';

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
                  // FIX: use __ for second unused parameter (avoids linter warning)
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ProductPricingCard(
                      product: products[index],
                      storeId: _storeId!,
                      pricingService: _pricingService,
                    );
                  },
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-product pricing card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductPricingCard extends StatefulWidget {
  final ProductModel product;
  final String storeId;
  final PricingService pricingService;

  const _ProductPricingCard({
    required this.product,
    required this.storeId,
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

  // AI suggestion state
  bool _showAiPanel = false;
  bool _isLoadingAi = false;
  String? _aiError;
  Map<String, String> _aiSuggestions = {};
  String _aiReasoning = '';

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

  // ── Save prices ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final newBase = double.tryParse(_basePriceController.text);
    if (newBase == null) {
      _showSnack('Invalid base price.', Colors.red);
      return;
    }
    final variantPrices = <String, double>{};
    for (final entry in _variantControllers.entries) {
      final price = double.tryParse(entry.value.text);
      if (price == null) {
        _showSnack('Invalid price for variant ${entry.key}.', Colors.red);
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
      _showSnack('Prices updated for ${widget.product.name}.', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error saving: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyBasePriceToAll() {
    final base = _basePriceController.text;
    for (final c in _variantControllers.values) {
      c.text = base;
    }
    setState(() => _hasChanges = true);
  }

  // ── AI Suggestions ─────────────────────────────────────────────────────────

  Future<void> _loadAiSuggestions() async {
    setState(() {
      _isLoadingAi = true;
      _aiError = null;
      _aiSuggestions = {};
      _aiReasoning = '';
    });
    try {
      final result = await AiPricingService().getSuggestionsForProduct(
        product: widget.product,
        storeId: widget.storeId,
      );
      if (!mounted) return;
      setState(() {
        _aiSuggestions = Map.from(result)..remove('reasoning');
        _aiReasoning = result['reasoning'] ?? '';
        _isLoadingAi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString().replaceAll('Exception: ', '');
        _isLoadingAi = false;
      });
    }
  }

  /// Apply a single AI suggested price (uses midpoint of range) to a variant.
  void _applyAiSuggestion(String variantKey, String suggestion) {
    // suggestion is like "₱250 - ₱300" — take midpoint
    final numbers = RegExp(r'[\d.]+')
        .allMatches(suggestion)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    if (numbers.isEmpty) return;
    final mid = numbers.length >= 2
        ? ((numbers[0] + numbers[1]) / 2).roundToDouble()
        : numbers[0];
    _variantControllers[variantKey]?.text = mid.toStringAsFixed(0);
    setState(() => _hasChanges = true);
  }

  void _applyAllAiSuggestions() {
    for (final entry in _aiSuggestions.entries) {
      _applyAiSuggestion(entry.key, entry.value);
    }
    // Also update base price from all suggestions midpoint
    if (_aiSuggestions.isNotEmpty) {
      final all = _variantControllers.values
          .map((c) => double.tryParse(c.text) ?? 0)
          .where((v) => v > 0)
          .toList();
      if (all.isNotEmpty) {
        final avg = all.reduce((a, b) => a + b) / all.length;
        _basePriceController.text = avg.roundToDouble().toStringAsFixed(0);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }



  // ── Build ──────────────────────────────────────────────────────────────────

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
          // ── Collapsed header ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
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
                              // FIX: use __ for second unused parameter
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

          // ── Expanded content ──────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Base price + apply-to-all
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
                                  // AI suggestion badge (if loaded)
                                  if (_aiSuggestions.containsKey(entry.key))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: GestureDetector(
                                        onTap: () => _applyAiSuggestion(
                                          entry.key,
                                          _aiSuggestions[entry.key]!,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal[50],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.teal[300]!,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'AI',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal[700],
                                                ),
                                              ),
                                              Text(
                                                _aiSuggestions[entry.key]!,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.teal[700],
                                                ),
                                              ),
                                            ],
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

                  const SizedBox(height: 16),

                  // ── AI Price Suggestions panel ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() => _showAiPanel = !_showAiPanel);
                            if (_showAiPanel && _aiSuggestions.isEmpty) {
                              _loadAiSuggestions();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: Colors.teal[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI Price Suggestions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showAiPanel
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.teal[700],
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showAiPanel) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: _buildAiPanel(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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

  Widget _buildDeployBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Build ${EnvConfig.buildId} · Gemini '
        '${EnvConfig.isGeminiConfigured ? "configured" : "NOT configured"}',
        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAiPanel() {
    if (_isLoadingAi) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildDeployBadge(),
              const CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                'Analyzing sales data and market trends...',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiError != null) {
      return Column(
        children: [
          _buildDeployBadge(),
          Icon(Icons.error_outline, color: Colors.red[400], size: 36),
          const SizedBox(height: 8),
          Text(
            _aiError!,
            style: TextStyle(fontSize: 12, color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadAiSuggestions,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal[700],
              side: BorderSide(color: Colors.teal[300]!),
            ),
          ),
        ],
      );
    }

    if (_aiSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDeployBadge(),
            OutlinedButton.icon(
          onPressed: _loadAiSuggestions,
          icon: const Icon(Icons.auto_awesome, size: 14),
          label: const Text(
            'Generate Suggestions',
            style: TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal[700],
            side: BorderSide(color: Colors.teal[300]!),
          ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDeployBadge(),
        // Reasoning
        if (_aiReasoning.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal[100]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: Colors.teal[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _aiReasoning,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Suggestions table
        Text(
          'Suggested Ranges',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(height: 8),
        ..._aiSuggestions.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatVariantLabel(entry.key),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _applyAiSuggestion(entry.key, entry.value),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.teal[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.arrow_downward,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Apply all button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loadAiSuggestions,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal[700],
                  side: BorderSide(color: Colors.teal[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _applyAllAiSuggestions();
                  _showSnack(
                    'All AI suggestions applied. Review and Save.',
                    Colors.teal[700]!,
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Apply All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatVariantLabel(String key) {
    final parts = key.split('_');
    if (parts.length < 2) return key.toUpperCase();
    final color =
        parts[0][0].toUpperCase() + parts[0].substring(1).toLowerCase();
    final size = parts[1].toUpperCase();
    return '$color — $size';
  }
}
