import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothnear/models/order_model.dart';
import 'package:clothnear/models/product_model.dart';
import 'package:clothnear/services/inventory_service.dart';
import 'package:clothnear/services/order_service.dart';
import 'package:clothnear/services/product_service.dart';
import 'package:clothnear/services/worker_pos_cart_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
//
// CRITICAL FIX: WorkerPOSScreen is a plain StatelessWidget that wraps its
// subtree in a ProviderScope. This is the ONLY place in the app where
// posCartProvider lives — it is scoped to this screen and is automatically
// disposed when the worker exits the POS flow, giving each new sale a clean
// cart. Without this ProviderScope, any ConsumerWidget below would attempt to
// read posCartProvider from the root ProviderScope (which doesn't exist in
// main.dart) causing a ProviderNotFoundException at runtime → blank gray screen.
// ─────────────────────────────────────────────────────────────────────────────

class WorkerPOSScreen extends StatelessWidget {
  final String storeId;
  final String storeName;
  final String workerUid;
  final String workerName;

  const WorkerPOSScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.workerUid,
    required this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _POSNavigator(
        storeId: storeId,
        storeName: storeName,
        workerUid: workerUid,
        workerName: workerName,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal navigator — manages the 3 steps via IndexedStack
// ─────────────────────────────────────────────────────────────────────────────

class _POSNavigator extends ConsumerStatefulWidget {
  final String storeId;
  final String storeName;
  final String workerUid;
  final String workerName;

  const _POSNavigator({
    required this.storeId,
    required this.storeName,
    required this.workerUid,
    required this.workerName,
  });

  @override
  ConsumerState<_POSNavigator> createState() => _POSNavigatorState();
}

class _POSNavigatorState extends ConsumerState<_POSNavigator> {
  // Steps: 0 = browse, 1 = cart, 2 = payment, 3 = success
  //
  // The success screen (step 3) lives INSIDE this widget so it remains a
  // descendant of the ProviderScope created by WorkerPOSScreen. Navigating
  // away from WorkerPOSScreen with pushReplacement would destroy that
  // ProviderScope, causing provider disposal mid-flight and leaving a dead
  // route on the stack. Keeping success in-tree means:
  //   • "New Sale"  → reset to step 0, clearCart() — no route push/pop
  //   • "Done"      → Navigator.pop(context) once — back to WorkerHomeScreen
  int _step = 0;

  // Sale result data — populated by _goToSuccess(), read by step 3.
  String _successOrderId = '';
  double _successTotal = 0;
  double _successTendered = 0;
  double _successChange = 0;

  void _goTo(int step) => setState(() => _step = step);

  void _goToSuccess({
    required String orderId,
    required double total,
    required double tendered,
    required double change,
  }) {
    setState(() {
      _successOrderId = orderId;
      _successTotal = total;
      _successTendered = tendered;
      _successChange = change;
      _step = 3;
    });
  }

  void _startNewSale() {
    ref.read(posCartProvider.notifier).clearCart();
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(posCartProvider);

    // On the success screen, the system back button should pop to home — allow.
    final canPop = _step == 0 || _step == 3;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && _step < 3) _goTo(_step - 1);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        // Hide the AppBar entirely on the success screen — it has its own layout.
        appBar: _step == 3
            ? null
            : AppBar(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_step == 0) {
                      Navigator.pop(context);
                    } else {
                      _goTo(_step - 1);
                    }
                  },
                ),
                title: Text(
                  ['New Sale', 'Cart Review', 'Payment'][_step],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                actions: [
                  if (_step == 0)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_outlined),
                          onPressed: cartState.isEmpty ? null : () => _goTo(1),
                        ),
                        if (cartState.itemCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${cartState.itemCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: List.generate(3, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _step ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
        body: IndexedStack(
          index: _step,
          children: [
            _ProductBrowserStep(
              storeId: widget.storeId,
              onGoToCart: () => _goTo(1),
            ),
            _CartReviewStep(onConfirm: () => _goTo(2), onBack: () => _goTo(0)),
            _PaymentStep(
              storeId: widget.storeId,
              storeName: widget.storeName,
              workerName: widget.workerName,
              onBack: () => _goTo(1),
              onSaleComplete: _goToSuccess,
            ),
            // Step 3 — success. Always present in the stack so IndexedStack
            // never receives an out-of-range index. The data fields default to
            // empty/zero until _goToSuccess() populates them.
            _POSSaleSuccessScreen(
              orderId: _successOrderId,
              total: _successTotal,
              tendered: _successTendered,
              change: _successChange,
              onNewSale: _startNewSale,
              onDone: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Product Browser
// ─────────────────────────────────────────────────────────────────────────────

class _ProductBrowserStep extends StatefulWidget {
  final String storeId;
  final VoidCallback onGoToCart;

  const _ProductBrowserStep({required this.storeId, required this.onGoToCart});

  @override
  State<_ProductBrowserStep> createState() => _ProductBrowserStepState();
}

class _ProductBrowserStepState extends State<_ProductBrowserStep> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.purple[700],
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search products…',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: ProductService().getProductsByStore(widget.storeId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final all = snap.data ?? [];
              final products = _query.isEmpty
                  ? all
                  : all
                        .where(
                          (p) =>
                              p.name.toLowerCase().contains(_query) ||
                              p.type.toLowerCase().contains(_query),
                        )
                        .toList();

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty
                            ? 'No products in this store.'
                            : 'No products match "$_query".',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: products.length,
                itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card
//
// FIX: _showVariantSheet passes the WidgetRef captured from build() into the
// sheet builder via ProviderScope.overrides so the sheet's ConsumerWidget can
// read the same posCartProvider instance. But the simpler correct approach
// here is to pass a plain callback from build() — this avoids passing ref
// across BuildContext boundaries into modal routes.
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalStock = product.variants.values.fold<int>(
      0,
      (sum, v) => sum + v.stock,
    );

    return GestureDetector(
      onTap: () => _showVariantSheet(context, ref),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 36,
                    color: Colors.purple[300],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                product.type,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.priceRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: totalStock > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$totalStock in stock',
                      style: TextStyle(
                        fontSize: 10,
                        color: totalStock > 0
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVariantSheet(BuildContext context, WidgetRef ref) {
    // CRITICAL FIX: capture the notifier reference BEFORE entering the modal
    // builder. The modal's builder receives a different BuildContext that is
    // no longer a descendant of this ConsumerWidget's scope. Reading
    // posCartProvider inside builder(_) would fail because that context
    // has no ref. Instead we pass the notifier directly as a callback.
    final notifier = ref.read(posCartProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VariantSelectorSheet(
        product: product,
        onAddToCart: (item) {
          notifier.addItem(item);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.productName} added to cart'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.purple[700],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Variant selector bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _VariantSelectorSheet extends StatefulWidget {
  final ProductModel product;
  final ValueChanged<CartItem> onAddToCart;

  const _VariantSelectorSheet({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_VariantSelectorSheet> createState() => _VariantSelectorSheetState();
}

class _VariantSelectorSheetState extends State<_VariantSelectorSheet> {
  String? _selectedColor;
  String? _selectedSize;
  int _qty = 1;

  List<String> get _colors => widget.product.colors;

  List<String> get _sizesForColor {
    if (_selectedColor == null) return [];
    return widget.product.availableSizesForColor(_selectedColor!);
  }

  int _stockFor(String color, String size) {
    return widget.product.getVariant(color, size)?.stock ?? 0;
  }

  double get _selectedPrice {
    if (_selectedColor != null && _selectedSize != null) {
      return widget.product
              .getVariant(_selectedColor!, _selectedSize!)
              ?.price ??
          widget.product.basePrice;
    }
    return widget.product.basePrice;
  }

  bool get _canAdd {
    if (_selectedColor == null || _selectedSize == null) return false;
    return _stockFor(_selectedColor!, _selectedSize!) >= _qty;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.product.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '₱${_selectedPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.purple[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Color',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) {
                final selected = _selectedColor == color;
                return ChoiceChip(
                  label: Text(color),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedColor = color;
                    _selectedSize = null;
                    _qty = 1;
                  }),
                  selectedColor: Colors.purple[100],
                  labelStyle: TextStyle(
                    color: selected ? Colors.purple[700] : Colors.grey[700],
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Size',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _sizesForColor.map((size) {
                final stock = _stockFor(_selectedColor!, size);
                final selected = _selectedSize == size;
                return ChoiceChip(
                  label: Text(stock > 0 ? size : '$size (out)'),
                  selected: selected,
                  onSelected: stock > 0
                      ? (_) => setState(() {
                          _selectedSize = size;
                          _qty = 1;
                        })
                      : null,
                  selectedColor: Colors.purple[100],
                  disabledColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: stock == 0
                        ? Colors.grey[400]
                        : selected
                        ? Colors.purple[700]
                        : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.purple[700],
                ),
                Text(
                  '$_qty',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed:
                      (_selectedSize != null &&
                          _qty < _stockFor(_selectedColor!, _selectedSize!))
                      ? () => setState(() => _qty++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.purple[700],
                ),
                if (_selectedSize != null)
                  Text(
                    '/ ${_stockFor(_selectedColor!, _selectedSize!)} avail',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _canAdd
                    ? () => widget.onAddToCart(
                        CartItem(
                          productId: widget.product.productId,
                          productName: widget.product.name,
                          color: _selectedColor!,
                          size: _selectedSize!,
                          quantity: _qty,
                          unitPrice: _selectedPrice,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  _canAdd
                      ? 'Add to Cart  •  ₱${(_selectedPrice * _qty).toStringAsFixed(2)}'
                      : 'Select color and size',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Cart Review
// ─────────────────────────────────────────────────────────────────────────────

class _CartReviewStep extends ConsumerWidget {
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _CartReviewStep({required this.onConfirm, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(posCartProvider);

    if (cartState.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to products'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartState.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final item = cartState.items[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
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
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${item.color} · ${item.size}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${item.unitPrice.toStringAsFixed(2)} each',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => ref
                                .read(posCartProvider.notifier)
                                .updateQuantity(i, item.quantity - 1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => ref
                                .read(posCartProvider.notifier)
                                .updateQuantity(i, item.quantity + 1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${item.lineTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red[400],
                            ),
                            onPressed: () => ref
                                .read(posCartProvider.notifier)
                                .removeItem(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cartState.itemCount} item(s)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Total: ₱${cartState.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Confirm Sale'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Payment & Completion
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentStep extends ConsumerStatefulWidget {
  final String storeId;
  final String storeName;
  final String workerName;
  final VoidCallback onBack;
  final void Function({
    required String orderId,
    required double total,
    required double tendered,
    required double change,
  })
  onSaleComplete;

  const _PaymentStep({
    required this.storeId,
    required this.storeName,
    required this.workerName,
    required this.onBack,
    required this.onSaleComplete,
  });

  @override
  ConsumerState<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<_PaymentStep> {
  final _tenderedCtrl = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  double _tendered = 0.0;

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    super.dispose();
  }

  double get _change {
    final cartState = ref.read(posCartProvider);
    return (_tendered - cartState.total).clamp(0.0, double.infinity);
  }

  bool get _canComplete {
    final cartState = ref.read(posCartProvider);
    return _tendered >= cartState.total && !_isProcessing;
  }

  Future<void> _completeSale() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final cartState = ref.read(posCartProvider);

    try {
      // Pre-flight stock check before creating the Firestore document.
      final stockResult = await InventoryService().checkStock(
        cartState.orderItems,
      );
      if (!stockResult.isOk) {
        setState(() {
          _error = stockResult.errors.map((e) => e.userMessage).join('\n');
          _isProcessing = false;
        });
        return;
      }

      // CRITICAL FIX: OrderModel requires designType as a required named param.
      // The original code omitted it → compile error / type mismatch at runtime.
      // Walk-in POS sales have no custom design, so 'none' is the correct value.
      final order = OrderModel(
        orderId: '',
        customerUid: 'walk_in',
        storeId: widget.storeId,
        storeName: widget.storeName,
        items: cartState.orderItems,
        totalPrice: cartState.total,
        amountPaid: cartState.total,
        remainingBalance: 0.0,
        paymentType: 'full',
        orderType: 'walk_in',
        status: 'processing',
        designType: 'none', // required field — omitted in original
        designUrl: '',
        designName: '',
        specialInstructions: '',
        createdAt: DateTime.now(),
        // Payment audit fields
        paymentMethod: 'cash',
        paymentConfirmedAt: DateTime.now().millisecondsSinceEpoch,
        paymentConfirmedBy: widget.workerName,
      );

      // placeOrder deducts inventory (status == 'processing' triggers it).
      final orderId = await OrderService().placeOrder(order);

      // Snapshot all values needed for the success screen BEFORE clearing
      // the cart. clearCart() triggers a provider state change; reading
      // cartState after it would return zero values.
      final saleTotal = cartState.total;
      final change = _change;
      final tendered = _tendered;

      // Clear cart state — safe: all values already snapshotted above.
      ref.read(posCartProvider.notifier).clearCart();

      if (!mounted) return;
      // Hand control back to _POSNavigatorState via callback.
      // _POSNavigatorState.setState() transitions to step 3 (success)
      // without touching the Navigator route stack at all.
      widget.onSaleComplete(
        orderId: orderId,
        total: saleTotal,
        tendered: tendered,
        change: change,
      );
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(posCartProvider);
    final total = cartState.total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Divider(height: 20),
                  ...cartState.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} (${item.color}/${item.size}) ×${item.quantity}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '₱${item.lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '₱${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Received',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _tenderedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _tendered = double.tryParse(v) ?? 0.0),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₱ ',
                      prefixStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 24,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.purple[700]!,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (_tendered >= total && _tendered > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Change',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₱${_change.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_tendered > 0 && _tendered < total) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Short by ₱${(total - _tendered).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _canComplete ? _completeSale : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_isProcessing ? 'Processing…' : 'Complete Sale'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────────────────────────────────────

class _POSSaleSuccessScreen extends StatelessWidget {
  final String orderId;
  final double total;
  final double tendered;
  final double change;
  // Callbacks injected by _POSNavigatorState — no Navigator calls here.
  final VoidCallback onNewSale;
  final VoidCallback onDone;

  const _POSSaleSuccessScreen({
    required this.orderId,
    required this.total,
    required this.tendered,
    required this.change,
    required this.onNewSale,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 60,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sale Complete!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Walk-in sale recorded successfully.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _summaryRow(
                        'Order ID',
                        '#${orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase()}',
                      ),
                      const Divider(height: 20),
                      _summaryRow(
                        'Total',
                        '₱${total.toStringAsFixed(2)}',
                        valueStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _summaryRow(
                        'Cash Received',
                        '₱${tendered.toStringAsFixed(2)}',
                      ),
                      _summaryRow(
                        'Change',
                        '₱${change.toStringAsFixed(2)}',
                        valueStyle: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 20),
                      _summaryRow('Payment', 'Cash — Paid in full'),
                      _summaryRow('Order Type', 'Walk-in Sale'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDone,
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Done'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onNewSale,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('New Sale'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style:
                valueStyle ??
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
