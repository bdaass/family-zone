import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/variant_inventory.dart';
import '../theme/app_theme.dart';
import 'product_variant_picker.dart';

class AddToCartSheet extends StatelessWidget {
  final String productDocId;
  final String productId;
  final String title;
  final String imageUrl;
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
        sizeField: sizeField,
        colorField: colorField,
        price: price,
        soldPrice: soldPrice,
        variantInventory: variantInventory,
      ),
    );
  }

  double get _unitPrice {
    if (soldPrice != null && soldPrice! > 0 && soldPrice! < price) return soldPrice!;
    return price;
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              '\$${_unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.coral),
            ),
            const SizedBox(height: 20),
            ProductVariantPicker(
              productDocId: productDocId,
              productId: productId,
              title: title,
              imageUrl: imageUrl,
              sizeField: sizeField,
              colorField: colorField,
              price: price,
              soldPrice: soldPrice,
              variantInventory: variantInventory,
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
