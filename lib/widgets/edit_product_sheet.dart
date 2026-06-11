import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import 'audience_fields.dart';
import 'size_input_field.dart';

class EditProductSheet extends StatefulWidget {
  final String productId;
  final String title;
  final String description;
  final String size;
  final double price;
  final double? soldPrice;
  final String season;
  final String ageGroup;
  final String sex;
  final String type;

  const EditProductSheet({
    super.key,
    required this.productId,
    required this.title,
    required this.description,
    required this.size,
    required this.price,
    this.soldPrice,
    required this.season,
    required this.ageGroup,
    required this.sex,
    required this.type,
  });

  @override
  State<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<EditProductSheet> {
  late final TextEditingController _productIdController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late String _sizesEncoded;
  late final TextEditingController _soldPriceController;
  late String _season;
  late String _ageGroup;
  late String _sex;
  late String _type;

  @override
  void initState() {
    super.initState();
    _productIdController = TextEditingController(text: widget.productId);
    _titleController = TextEditingController(text: widget.title);
    _descController = TextEditingController(text: widget.description);
    _sizesEncoded = widget.size;
    _priceController = TextEditingController(text: widget.price.toStringAsFixed(2));
    _soldPriceController = TextEditingController(
      text: widget.soldPrice != null ? widget.soldPrice!.toStringAsFixed(2) : '',
    );
    _season = ProductCatalog.seasons.contains(widget.season) ? widget.season : 'summer';
    _ageGroup = ProductCatalog.normalizeAgeGroup(widget.ageGroup);
    _sex = ProductCatalog.normalizeSex(widget.sex);
    _type = ProductCatalog.normalizeType(widget.type);
    if (!ProductCatalog.types.contains(_type)) _type = 'clothes';
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _soldPriceController.dispose();
    super.dispose();
  }

  void _save() {
    final productId = _productIdController.text.trim();
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final sizes = ProductCatalog.sizesFromField(_sizesEncoded);
    final size = ProductCatalog.encodeSizes(sizes);
    final price = double.tryParse(_priceController.text.trim());
    final soldPriceText = _soldPriceController.text.trim();
    final soldPrice = soldPriceText.isEmpty ? null : double.tryParse(soldPriceText);

    if (!ProductCatalog.isValidProductId(productId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('product_id_invalid'))));
      return;
    }
    if (title.isEmpty || description.isEmpty || sizes.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sizes.isEmpty ? S.of('sizes_required') : S.of('edit_validation_required'))),
      );
      return;
    }
    if (soldPriceText.isNotEmpty && (soldPrice == null || soldPrice >= price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('sale_price_invalid'))),
      );
      return;
    }

    final result = <String, dynamic>{
      'productId': productId,
      'title': title,
      'description': description,
      'size': size,
      'price': price,
      'season': _season,
      'ageGroup': _ageGroup,
      'sex': _sex,
      'type': _type,
      ...ProductCatalog.searchIndexFields(
        title: title,
        description: description,
        productId: productId,
        size: size,
        price: price,
        soldPrice: soldPrice,
        season: _season,
        ageGroup: _ageGroup,
        sex: _sex,
        type: _type,
      ),
    };
    if (soldPrice == null) {
      result['soldPrice'] = FieldValue.delete();
    } else {
      result['soldPrice'] = soldPrice;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(S.of('edit_item_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 20),
            TextField(
              controller: _productIdController,
              decoration: InputDecoration(
                labelText: S.of('field_product_id'),
                hintText: S.of('field_product_id_hint'),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(controller: _titleController, decoration: InputDecoration(labelText: S.of('field_title'))),
            const SizedBox(height: 12),
            TextField(controller: _descController, decoration: InputDecoration(labelText: S.of('field_description')), maxLines: 3),
            const SizedBox(height: 12),
            SizeInputField(
              initialValue: _sizesEncoded,
              onEncodedChanged: (value) => _sizesEncoded = value,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: S.of('field_regular_price')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _soldPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: S.of('field_sale_price'),
                hintText: S.of('field_sale_price_empty_hint'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _season,
              decoration: InputDecoration(labelText: S.of('field_season')),
              items: ProductCatalog.seasons.map((s) => DropdownMenuItem(value: s, child: Text(ProductCatalog.label(s)))).toList(),
              onChanged: (v) => setState(() => _season = v!),
            ),
            const SizedBox(height: 12),
            AudienceFields(
              ageGroup: _ageGroup,
              sex: _sex,
              onAgeGroupChanged: (v) => setState(() => _ageGroup = v),
              onSexChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(labelText: S.of('field_category')),
              items: ProductCatalog.types.map((t) => DropdownMenuItem(value: t, child: Text(ProductCatalog.label(t)))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _save,
                child: Text(S.of('save_changes'), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
