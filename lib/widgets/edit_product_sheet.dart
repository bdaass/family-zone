import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/product_image_service.dart';
import '../theme/app_theme.dart';
import 'audience_fields.dart';
import 'branch_stock_field.dart';
import 'color_input_field.dart';
import 'product_images_field.dart';
import 'size_input_field.dart';
import 'sale_pricing_fields.dart';
import 'staff_choice_dropdown.dart';
import 'staff_form_section.dart';

class EditProductSheet extends StatefulWidget {
  final String productId;
  final String title;
  final String description;
  final String size;
  final String colors;
  final double price;
  final int? discountPercent;
  final double? soldPrice;
  final String season;
  final String ageGroup;
  final String sex;
  final String type;
  final Map<String, int?> branchStock;
  final List<String> imageUrls;
  final bool hasBarcode;
  final String? barcodeImageUrl;
  final bool showBarcodePreview;

  final bool showApprovalNotice;

  const EditProductSheet({
    super.key,
    required this.productId,
    required this.title,
    required this.description,
    required this.size,
    this.colors = '',
    required this.price,
    this.discountPercent,
    this.soldPrice,
    required this.season,
    required this.ageGroup,
    required this.sex,
    required this.type,
    this.branchStock = const {},
    this.imageUrls = const [],
    this.hasBarcode = false,
    this.barcodeImageUrl,
    this.showBarcodePreview = false,
    this.showApprovalNotice = false,
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
  late String _colorsEncoded;
  late final TextEditingController _discountPercentController;
  late final TextEditingController _salePriceController;
  late String _season;
  late String _ageGroup;
  late String _sex;
  late String _type;
  Map<String, int?> _branchStock = {};
  List<String> _keptImageUrls = [];
  List<Uint8List> _newProductImages = [];
  List<String> _removedImageUrls = [];
  Uint8List? _barcodeImage;

  @override
  void initState() {
    super.initState();
    _keptImageUrls = List<String>.from(widget.imageUrls);
    _branchStock = Map<String, int?>.from(widget.branchStock);
    _productIdController = TextEditingController(text: widget.productId);
    _titleController = TextEditingController(text: widget.title);
    _descController = TextEditingController(text: widget.description);
    _sizesEncoded = widget.size;
    _colorsEncoded = widget.colors;
    _priceController = TextEditingController(text: widget.price.toStringAsFixed(2));
    _discountPercentController = TextEditingController(
      text: widget.discountPercent?.toString() ?? '',
    );
    _salePriceController = TextEditingController(
      text: widget.soldPrice != null ? widget.soldPrice!.toStringAsFixed(2) : '',
    );
    final normalizedSeason = ProductCatalog.normalizeSeason(widget.season);
    _season = ProductCatalog.seasons.contains(normalizedSeason) ? normalizedSeason : 'summer';
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
    _discountPercentController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  void _save() {
    final productId = _productIdController.text.trim();
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final sizes = ProductCatalog.sizesFromField(_sizesEncoded);
    final size = ProductCatalog.encodeSizes(sizes);
    final colors = ProductCatalog.encodeColors(ProductCatalog.colorsFromField(_colorsEncoded));
    final price = double.tryParse(_priceController.text.trim());
    final discountText = _discountPercentController.text.trim();
    final saleText = _salePriceController.text.trim();

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
    final salePricing = ProductCatalog.resolveSalePricing(
      regularPrice: price,
      salePriceText: saleText,
      discountPercentText: discountText,
    );
    if (salePricing.errorKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(salePricing.errorKey!))),
      );
      return;
    }

    final soldPrice = salePricing.soldPrice;
    final discountPercent = salePricing.discountPercent;

    final branchStockError = BranchStockFieldValidation.validate(
      values: _branchStock,
      requireExplicitChoice: false,
      acknowledgedBranches: ProductCatalog.branchIds.toSet(),
    );
    if (branchStockError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(branchStockError))));
      return;
    }

    final imageError = ProductImagesFieldValidation.validate(
      keptUrls: _keptImageUrls,
      newImages: _newProductImages,
      barcodeImage: _barcodeImage,
      hadBarcode: widget.hasBarcode,
    );
    if (imageError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(imageError))));
      return;
    }

    final branchStockSave = ProductCatalog.resolveBranchStockForSave(_branchStock);

    final result = <String, dynamic>{
      'productId': productId,
      'title': title,
      'description': description,
      'size': size,
      'colors': colors.isEmpty ? FieldValue.delete() : colors,
      if (branchStockSave.branchStock == null) ...{
        'branchStock': FieldValue.delete(),
        'stockQty': FieldValue.delete(),
      } else ...{
        'branchStock': branchStockSave.branchStock,
        'stockQty': branchStockSave.stockQty,
      },
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
        colors: colors,
        price: price,
        soldPrice: soldPrice,
        season: _season,
        ageGroup: _ageGroup,
        sex: _sex,
        type: _type,
      ),
    };
    if (discountPercent == null) {
      result['discountPercent'] = FieldValue.delete();
      result['soldPrice'] = FieldValue.delete();
    } else {
      result['discountPercent'] = discountPercent;
      result['soldPrice'] = soldPrice;
    }
    result['_imageUpdate'] = ProductImageUpdate(
      keptImageUrls: _keptImageUrls,
      removedImageUrls: _removedImageUrls,
      newImages: _newProductImages,
      newBarcodeImage: _barcodeImage,
      hadBarcode: widget.hasBarcode || _barcodeImage != null,
    );
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
            if (widget.showApprovalNotice) ...[
              const SizedBox(height: 10),
              Text(
                S.of('staff_edit_approval_notice'),
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.35),
              ),
            ],
            const SizedBox(height: 20),
            StaffFormSection(
              title: S.of('staff_section_basics'),
              icon: Icons.edit_note_rounded,
              accent: AppColors.ink,
              children: [
                TextField(
                  controller: _productIdController,
                  decoration: InputDecoration(
                    labelText: S.of('field_product_id'),
                    hintText: S.of('field_product_id_hint'),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: S.of('field_title')),
                ),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: S.of('field_description')),
                  maxLines: 3,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_media'),
              icon: Icons.photo_library_outlined,
              accent: AppColors.violet,
              children: [
                ProductImagesField(
                  initialImageUrls: widget.imageUrls,
                  hasExistingBarcode: widget.hasBarcode,
                  existingBarcodeUrl: widget.barcodeImageUrl,
                  storageProductId: widget.productId,
                  showBarcodePreview: widget.showBarcodePreview,
                  onKeptUrlsChanged: (urls) => _keptImageUrls = urls,
                  onNewImagesChanged: (images) => _newProductImages = images,
                  onBarcodeImageChanged: (bytes) => _barcodeImage = bytes,
                  onRemovedUrlsChanged: (urls) => _removedImageUrls = urls,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_variants'),
              icon: Icons.straighten_rounded,
              accent: AppColors.coral,
              children: [
                SizeInputField(
                  initialValue: _sizesEncoded,
                  onEncodedChanged: (value) => _sizesEncoded = value,
                ),
                ColorInputField(
                  initialValue: _colorsEncoded,
                  onEncodedChanged: (value) => _colorsEncoded = value,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_inventory'),
              icon: Icons.storefront_outlined,
              accent: AppColors.gold,
              children: [
                BranchStockField(
                  initialValues: widget.branchStock,
                  onChanged: (values) => _branchStock = values,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_pricing'),
              icon: Icons.sell_outlined,
              accent: AppColors.coral,
              children: [
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: S.of('field_regular_price')),
                  onChanged: (_) => setState(() {}),
                ),
                SalePricingFields(
                  regularPriceController: _priceController,
                  salePriceController: _salePriceController,
                  discountPercentController: _discountPercentController,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_catalog'),
              icon: Icons.category_outlined,
              accent: AppColors.violet,
              children: [
                AudienceFields(
                  ageGroup: _ageGroup,
                  sex: _sex,
                  onAgeGroupChanged: (v) => setState(() => _ageGroup = v ?? _ageGroup),
                  onSexChanged: (v) => setState(() => _sex = v ?? _sex),
                ),
                StaffChoiceDropdown(
                  label: S.of('field_season'),
                  value: _season,
                  options: ProductCatalog.seasons,
                  optionLabel: ProductCatalog.label,
                  onChanged: (v) => setState(() => _season = v ?? _season),
                ),
                StaffChoiceDropdown(
                  label: S.of('field_category'),
                  value: _type,
                  options: ProductCatalog.types,
                  optionLabel: ProductCatalog.label,
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
