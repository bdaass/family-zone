import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/cart_item.dart';
import '../models/product_catalog.dart';
import '../models/variant_inventory.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

/// Color, size, quantity picker with add-to-cart — used in product detail and quick-add sheet.
class ProductVariantPicker extends StatefulWidget {
  const ProductVariantPicker({
    super.key,
    required this.productDocId,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.sizeField,
    this.colorField = '',
    required this.price,
    this.soldPrice,
    this.variantInventory = const {},
    this.onAdded,
    this.onColorSelected,
  });

  final String productDocId;
  final String productId;
  final String title;
  final String imageUrl;
  final String sizeField;
  final String colorField;
  final double price;
  final double? soldPrice;
  final VariantInventoryMap variantInventory;
  final VoidCallback? onAdded;
  final ValueChanged<String>? onColorSelected;

  @override
  State<ProductVariantPicker> createState() => _ProductVariantPickerState();
}

class _ProductVariantPickerState extends State<ProductVariantPicker> {
  late List<String> _sizes;
  late List<String> _colors;
  late String _selectedSize;
  String _selectedColor = '';
  int _quantity = 1;
  bool _saving = false;

  bool get _usesVariantInventory => VariantInventory.hasAnyEntries(widget.variantInventory);

  int get _maxQuantity {
    if (!_usesVariantInventory) return 99;
    if (_selectedColor.isEmpty || _selectedSize.isEmpty) return 1;
    final total = VariantInventory.variantTotalQty(
      widget.variantInventory,
      color: _selectedColor,
      size: _selectedSize,
    );
    return total > 0 ? total : 1;
  }

  List<String> get _availableColors {
    if (_usesVariantInventory) {
      final withStock = VariantInventory.colorsWithStock(widget.variantInventory);
      if (withStock.isNotEmpty) return withStock;
    }
    return ProductCatalog.colorsForSelection(widget.colorField);
  }

  List<String> _availableSizesForColor(String color) {
    if (_usesVariantInventory) {
      final withStock = VariantInventory.sizesWithStockForColor(widget.variantInventory, color);
      if (withStock.isNotEmpty) return withStock;
    }
    return ProductCatalog.sizesForSelection(widget.sizeField);
  }

  double get _unitPrice {
    if (widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price) {
      return widget.soldPrice!;
    }
    return widget.price;
  }

  @override
  void initState() {
    super.initState();
    _colors = _availableColors;
    if (_colors.length == 1) {
      _selectedColor = _colors.first;
    }
    _sizes = _selectedColor.isNotEmpty
        ? _availableSizesForColor(_selectedColor)
        : ProductCatalog.sizesForSelection(widget.sizeField);
    _selectedSize = _sizes.isNotEmpty ? _sizes.first : '';
  }

  void _onColorSelected(String color) {
    setState(() {
      _selectedColor = color;
      _sizes = _availableSizesForColor(color);
      if (!_sizes.contains(_selectedSize)) {
        _selectedSize = _sizes.isNotEmpty ? _sizes.first : '';
      }
      if (_quantity > _maxQuantity) _quantity = _maxQuantity;
    });
    widget.onColorSelected?.call(color);
  }

  void _onSizeSelected(String size) {
    setState(() {
      _selectedSize = size;
      if (_quantity > _maxQuantity) _quantity = _maxQuantity;
    });
  }

  Future<void> _add() async {
    if (_saving) return;
    if (_colors.length > 1 && _selectedColor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('select_color_required'))));
      return;
    }
    if (_selectedSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('select_size_required'))));
      return;
    }
    if (_usesVariantInventory && _maxQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('out_of_stock'))));
      return;
    }
    setState(() => _saving = true);
    try {
      await CartService.instance.addItem(
        CartItem(
          productDocId: widget.productDocId,
          productId: widget.productId,
          title: widget.title,
          imageUrl: widget.imageUrl,
          selectedSize: _selectedSize,
          selectedColor: _selectedColor,
          quantity: _quantity,
          unitPrice: _unitPrice,
        ),
      );
      if (!mounted) return;
      widget.onAdded?.call();
      if (widget.onAdded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of('added_to_cart'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsColorFirst = _colors.length > 1;
    final colorReady = !needsColorFirst || _selectedColor.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_colors.isNotEmpty) ...[
          Text(
            _colors.length > 1 ? S.of('available_colors') : S.of('color'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) {
              final selected = _selectedColor == color;
              return ChoiceChip(
                label: Text(ProductCatalog.colorDisplayName(color)),
                selected: selected,
                onSelected: (_) => _onColorSelected(color),
                selectedColor: AppColors.coral,
                labelStyle: TextStyle(
                  color: selected ? AppColors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ],
        if (colorReady) ...[
          const SizedBox(height: 20),
          Text(
            _sizes.length > 1 ? S.of('available_sizes') : S.of('size'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sizes.map((size) {
              final selected = _selectedSize == size;
              final variantQty = _usesVariantInventory && _selectedColor.isNotEmpty
                  ? VariantInventory.variantTotalQty(
                      widget.variantInventory,
                      color: _selectedColor,
                      size: size,
                    )
                  : null;
              final outOfStock = variantQty == 0;
              return ChoiceChip(
                label: Text(size),
                selected: selected,
                onSelected: outOfStock ? null : (_) => _onSizeSelected(size),
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? AppColors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          S.of('quantity'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _qtyButton(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            _qtyButton(
              Icons.add,
              _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
            ),
            const Spacer(),
            Text(
              S.fmt('total_label', {'amount': (_unitPrice * _quantity).toStringAsFixed(2)}),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _add,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(S.of('add_to_cart'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.creamDark),
          ),
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.inkMuted : AppColors.ink),
        ),
      ),
    );
  }
}
