import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../models/variant_inventory.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';
import 'product_image_carousel.dart';
import 'product_variant_picker.dart';

class AddToCartSheet extends StatefulWidget {
  final String productDocId;
  final String productId;
  final String title;
  final String imageUrl;
  final List<String> imageUrls;
  final Map<String, String> imageColorByUrl;
  final String sizeField;
  final String colorField;
  final double price;
  final double? soldPrice;
  final VariantInventoryMap variantInventory;

  const AddToCartSheet({
    super.key,
    required this.productDocId,
    required this.productId,
    required this.title,
    required this.imageUrl,
    this.imageUrls = const [],
    this.imageColorByUrl = const {},
    required this.sizeField,
    this.colorField = '',
    required this.price,
    this.soldPrice,
    this.variantInventory = const {},
  });

  static Future<void> show(
    BuildContext context, {
    required String productDocId,
    required String productId,
    required String title,
    required String imageUrl,
    List<String> imageUrls = const [],
    Map<String, String> imageColorByUrl = const {},
    required String sizeField,
    String colorField = '',
    required double price,
    double? soldPrice,
    VariantInventoryMap variantInventory = const {},
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
        imageUrls: imageUrls,
        imageColorByUrl: imageColorByUrl,
        sizeField: sizeField,
        colorField: colorField,
        price: price,
        soldPrice: soldPrice,
        variantInventory: variantInventory,
      ),
    );
  }

  @override
  State<AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<AddToCartSheet> {
  late String _displayImageUrl;

  List<String> get _urls {
    if (widget.imageUrls.isNotEmpty) return widget.imageUrls;
    if (widget.imageUrl.isNotEmpty) return [widget.imageUrl];
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _displayImageUrl = _urls.isNotEmpty ? _urls.first : widget.imageUrl;
  }

  double get _unitPrice {
    if (widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price) {
      return widget.soldPrice!;
    }
    return widget.price;
  }

  void _onColorSelected(String color) {
    final index = ProductCatalog.imageIndexForColor(_urls, widget.imageColorByUrl, color);
    if (index == null || index < 0 || index >= _urls.length) return;
    final url = _urls[index];
    if (url == _displayImageUrl) return;
    setState(() => _displayImageUrl = url);
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
            if (_displayImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: ProductImageSettings.catalogImageAspectRatio,
                  child: ProductNetworkImage(
                    url: _displayImageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: ProductImageSettings.displayCacheSize,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              '\$${_unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.coral),
            ),
            const SizedBox(height: 20),
            ProductVariantPicker(
              productDocId: widget.productDocId,
              productId: widget.productId,
              title: widget.title,
              imageUrl: _displayImageUrl.isNotEmpty ? _displayImageUrl : widget.imageUrl,
              sizeField: widget.sizeField,
              colorField: widget.colorField,
              price: widget.price,
              soldPrice: widget.soldPrice,
              variantInventory: widget.variantInventory,
              onColorSelected: _onColorSelected,
              onAdded: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.of('added_to_cart'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
