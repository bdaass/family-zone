import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/product_image_service.dart';
import '../theme/app_theme.dart';
import 'audience_fields.dart';
import 'product_images_field.dart';
import 'sale_pricing_fields.dart';
import 'staff_choice_dropdown.dart';
import 'staff_form_section.dart';
import 'variant_inventory_field.dart';
import '../models/variant_inventory.dart';

class EditProductSheet extends StatefulWidget {
  final String productId;
  final String title;
  final String description;
  final String staffNotes;
  final String size;
  final String colors;
  final double price;
  final int? discountPercent;
  final double? soldPrice;
  final String season;
  final String ageGroup;
  final String sex;
  final String type;
  final VariantInventoryMap variantInventory;
  final List<String> imageUrls;
  final Map<String, String> initialImageColorByUrl;
  final bool hasBarcode;
  final String? barcodeImageUrl;
  final bool showBarcodePreview;

  final bool showApprovalNotice;

  const EditProductSheet({
    super.key,
    required this.productId,
    required this.title,
    required this.description,
    this.staffNotes = '',
    required this.size,
    this.colors = '',
    required this.price,
    this.discountPercent,
    this.soldPrice,
    required this.season,
    required this.ageGroup,
    required this.sex,
    required this.type,
    this.variantInventory = const {},
    this.imageUrls = const [],
    this.initialImageColorByUrl = const {},
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
  late final TextEditingController _staffNotesController;
  late final TextEditingController _priceController;
  late VariantInventoryMap _variantInventory;
  late final TextEditingController _discountPercentController;
  late final TextEditingController _salePriceController;
  late String _season;
  late String _ageGroup;
  late String _sex;
  late String _type;
  List<String> _keptImageUrls = [];
  List<Uint8List> _newProductImages = [];
  List<String> _removedImageUrls = [];
  Uint8List? _barcodeImage;
  Map<String, String> _colorByKeptUrl = {};
  List<String?> _colorsForNewImages = [];

  @override
  void initState() {
    super.initState();
    _keptImageUrls = List<String>.from(widget.imageUrls);
    _variantInventory = {
      for (final branch in StoreConfig.locations)
        branch.id: Map<String, Map<String, int>>.from(
          (widget.variantInventory[branch.id] ?? {}).map(
            (color, sizes) => MapEntry(color, Map<String, int>.from(sizes)),
          ),
        ),
    };
    _productIdController = TextEditingController(text: widget.productId);
    _titleController = TextEditingController(text: widget.title);
    _descController = TextEditingController(text: widget.description);
    _staffNotesController = TextEditingController(text: widget.staffNotes);
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

  List<String> _imageColorOptions() {
    final seen = <String>{};
    final out = <String>[];
    void add(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) return;
      out.add(trimmed);
    }

    for (final color in ProductCatalog.colorsFromField(widget.colors)) {
      add(color);
    }
    for (final color in VariantInventory.uniqueColors(_variantInventory)) {
      add(color);
    }
    return out;
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _staffNotesController.dispose();
    _priceController.dispose();
    _discountPercentController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  void _save() {
    final productId = _productIdController.text.trim();
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final staffNotes = _staffNotesController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final discountText = _discountPercentController.text.trim();
    final saleText = _salePriceController.text.trim();

    if (!ProductCatalog.isValidProductId(productId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('product_id_invalid'))));
      return;
    }
    if (title.isEmpty || description.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('edit_validation_required'))));
      return;
    }

    final inventoryError = VariantInventoryFieldValidation.validate(
      inventory: _variantInventory,
      requireExplicitChoice: false,
      acknowledgedBranches: ProductCatalog.branchIds.toSet(),
    );
    if (inventoryError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(inventoryError))));
      return;
    }

    final inventorySave = ProductCatalog.resolveVariantInventoryForSave(_variantInventory);
    final size = inventorySave.size;
    final colors = inventorySave.colors;
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

    final inventoryFields = ProductCatalog.variantInventoryFieldsForWrite(_variantInventory);

    final result = <String, dynamic>{
      'productId': productId,
      'title': title,
      'description': description,
      'staffNotes': staffNotes,
      'size': inventoryFields['size'],
      if ((inventoryFields['colors'] as String).isEmpty)
        'colors': FieldValue.delete()
      else
        'colors': inventoryFields['colors'],
      'variantInventory': inventoryFields['variantInventory'],
      'stockQty': inventoryFields['stockQty'],
      'branchStock': inventoryFields['branchStock'],
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
      colorByKeptUrl: _colorByKeptUrl,
      colorsForNewImages: _colorsForNewImages,
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
                TextField(
                  controller: _staffNotesController,
                  decoration: InputDecoration(
                    labelText: S.of('field_staff_notes'),
                    hintText: S.of('field_staff_notes_hint'),
                  ),
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
                  initialImageColorByUrl: widget.initialImageColorByUrl,
                  availableColors: _imageColorOptions(),
                  hasExistingBarcode: widget.hasBarcode,
                  existingBarcodeUrl: widget.barcodeImageUrl,
                  storageProductId: widget.productId,
                  showBarcodePreview: widget.showBarcodePreview,
                  onKeptUrlsChanged: (urls) => _keptImageUrls = urls,
                  onNewImagesChanged: (images) => _newProductImages = images,
                  onBarcodeImageChanged: (bytes) => _barcodeImage = bytes,
                  onRemovedUrlsChanged: (urls) => _removedImageUrls = urls,
                  onColorByKeptUrlChanged: (map) => _colorByKeptUrl = map,
                  onColorsForNewImagesChanged: (colors) => _colorsForNewImages = colors,
                ),
              ],
            ),
            StaffFormSection(
              title: S.of('staff_section_inventory'),
              icon: Icons.storefront_outlined,
              accent: AppColors.gold,
              children: [
                VariantInventoryField(
                  initialInventory: _variantInventory,
                  onChanged: (values) => setState(() => _variantInventory = values),
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
