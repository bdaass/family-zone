import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/cart_item.dart';
import '../models/product_catalog.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

class AddToCartSheet extends StatefulWidget {
  final String productDocId;
  final String productId;
  final String title;
  final String imageUrl;
  final String sizeField;
  final String colorField;
  final double price;
  final double? soldPrice;

  const AddToCartSheet({
    super.key,
    required this.productDocId,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.sizeField,
    this.colorField = '',
    required this.price,
    this.soldPrice,
  });

  static Future<void> show(
    BuildContext context, {
    required String productDocId,
    required String productId,
    required String title,
    required String imageUrl,
    required String sizeField,
    String colorField = '',
    required double price,
    double? soldPrice,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddToCartSheet(
        productDocId: productDocId,
        productId: productId,
        title: title,
        imageUrl: imageUrl,
        sizeField: sizeField,
        colorField: colorField,
        price: price,
        soldPrice: soldPrice,
      ),
    );
  }

  @override
  State<AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<AddToCartSheet> {
  late final List<String> _sizes;
  late final List<String> _colors;
  late String _selectedSize;
  String _selectedColor = '';
  int _quantity = 1;
  bool _saving = false;

  double get _unitPrice {
    if (widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price) {
      return widget.soldPrice!;
    }
    return widget.price;
  }

  @override
  void initState() {
    super.initState();
    _sizes = ProductCatalog.sizesForSelection(widget.sizeField);
    _colors = ProductCatalog.colorsForSelection(widget.colorField);
    _selectedSize = _sizes.first;
    if (_colors.length == 1) {
      _selectedColor = _colors.first;
    }
  }

  Future<void> _add() async {
    if (_saving) return;
    if (_selectedSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('select_size_required'))));
      return;
    }
    if (_colors.length > 1 && _selectedColor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('select_color_required'))));
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
      if (mounted) {
        Navigator.pop(context);
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
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              '\$${_unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.coral),
            ),
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
                return ChoiceChip(
                  label: Text(size),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSize = size),
                  selectedColor: AppColors.ink,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
            if (_colors.isNotEmpty) ...[
              const SizedBox(height: 20),
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
                    onSelected: (_) => setState(() => _selectedColor = color),
                    selectedColor: AppColors.coral,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Text(S.of('quantity'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                _qtyButton(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                _qtyButton(Icons.add, () => setState(() => _quantity++)),
                const Spacer(),
                Text(
                  S.fmt('total_label', {'amount': (_unitPrice * _quantity).toStringAsFixed(2)}),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _add,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(S.of('add_to_cart'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
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
