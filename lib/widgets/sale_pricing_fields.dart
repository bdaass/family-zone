import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

/// Optional sale price ($) and discount (%) — fill either one; both stay in sync.
class SalePricingFields extends StatefulWidget {
  final TextEditingController regularPriceController;
  final TextEditingController salePriceController;
  final TextEditingController discountPercentController;
  final bool dense;

  const SalePricingFields({
    super.key,
    required this.regularPriceController,
    required this.salePriceController,
    required this.discountPercentController,
    this.dense = false,
  });

  @override
  State<SalePricingFields> createState() => _SalePricingFieldsState();
}

class _SalePricingFieldsState extends State<SalePricingFields> {
  bool _syncing = false;

  double? get _regularPrice => double.tryParse(widget.regularPriceController.text.trim());

  void _syncFromPercent() {
    if (_syncing) return;
    final price = _regularPrice;
    final percent = ProductCatalog.parseDiscountPercent(widget.discountPercentController.text);
    if (price == null) return;

    _syncing = true;
    if (percent != null) {
      widget.salePriceController.text =
          ProductCatalog.soldPriceFromPercent(price, percent).toStringAsFixed(2);
    } else if (widget.discountPercentController.text.trim().isEmpty) {
      widget.salePriceController.clear();
    }
    _syncing = false;
  }

  void _syncFromSalePrice() {
    if (_syncing) return;
    final price = _regularPrice;
    final sale = double.tryParse(widget.salePriceController.text.trim());
    if (price == null) return;

    _syncing = true;
    if (sale != null && sale > 0 && sale < price) {
      final percent = ProductCatalog.percentFromPrices(price, sale);
      widget.discountPercentController.text = percent?.toString() ?? '';
    } else if (widget.salePriceController.text.trim().isEmpty) {
      widget.discountPercentController.clear();
    }
    _syncing = false;
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final gap = widget.dense ? 8.0 : 12.0;
    final preview = _previewLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.of('field_sale_section'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: widget.salePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: S.of('field_sale_price'),
                  hintText: S.of('field_sale_price_empty_hint'),
                  isDense: widget.dense,
                ),
                onChanged: (_) {
                  _syncFromSalePrice();
                  _refresh();
                },
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: TextField(
                controller: widget.discountPercentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: S.of('field_discount_percent'),
                  hintText: S.of('field_discount_percent_hint'),
                  suffixText: '%',
                  isDense: widget.dense,
                ),
                onChanged: (_) {
                  _syncFromPercent();
                  _refresh();
                },
              ),
            ),
          ],
        ),
        if (preview != null)
          Padding(
            padding: EdgeInsets.only(top: gap - 2),
            child: Text(
              preview,
              style: TextStyle(
                fontSize: widget.dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: AppColors.coral,
              ),
            ),
          ),
      ],
    );
  }

  String? _previewLabel() {
    final price = _regularPrice;
    if (price == null) return null;

    final resolved = ProductCatalog.resolveSalePricing(
      regularPrice: price,
      salePriceText: widget.salePriceController.text,
      discountPercentText: widget.discountPercentController.text,
    );
    if (resolved.errorKey != null || resolved.soldPrice == null) return null;

    final parts = <String>[
      S.fmt('field_discount_preview', {'price': resolved.soldPrice!.toStringAsFixed(2)}),
    ];
    if (resolved.discountPercent != null) {
      parts.add(S.fmt('field_discount_percent_preview', {'percent': '${resolved.discountPercent}'}));
    }
    return parts.join(' · ');
  }
}
