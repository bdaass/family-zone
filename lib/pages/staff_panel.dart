import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/user_facing_error.dart';
import '../services/product_catalog_service.dart';
import '../services/product_image_service.dart';
import '../services/staff_storage_auth.dart';
import '../services/product_write_service.dart';
import '../widgets/audience_fields.dart';
import '../widgets/product_images_field.dart';
import '../widgets/sale_pricing_fields.dart';
import '../widgets/staff_form_section.dart';
import '../widgets/staff_choice_dropdown.dart';
import '../widgets/variant_inventory_field.dart';
import '../models/variant_inventory.dart';


class StaffManagementPanel extends StatefulWidget {
  final String userRole;
  const StaffManagementPanel({super.key, required this.userRole});

  @override
  State<StaffManagementPanel> createState() => _StaffManagementPanelState();
}

class _StaffManagementPanelState extends State<StaffManagementPanel> {
  final _productIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _staffNotesController = TextEditingController();
  final _priceController = TextEditingController();
  int _productImagesKey = 0;
  int _variantInventoryKey = 0;
  final _discountPercentController = TextEditingController();
  final _salePriceController = TextEditingController();

  List<String> _keptImageUrls = [];
  List<Uint8List> _newProductImages = [];
  List<String?> _colorsForNewImages = [];
  Uint8List? _barcodeImage;
  VariantInventoryMap _variantInventory = VariantInventory.empty();
  Set<String> _variantInventoryAcknowledged = {};
  bool _isUploading = false;

  String? _formSeason;
  String? _formAgeGroup;
  String? _formSex;
  String? _formType;

  bool get _strictForm => widget.userRole == 'employee';

  List<String> get _photoColorOptions => ProductCatalog.imageTagColorOptions(
        extraColors: VariantInventory.uniqueColors(_variantInventory),
      );

  @override
  void initState() {
    super.initState();
    if (!_strictForm) {
      _formSeason = 'summer';
      _formAgeGroup = 'adult';
      _formSex = 'female';
      _formType = 'clothes';
    }
  }

  String? _validateBeforeSubmit() {
    final productId = _productIdController.text.trim();
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final priceParsed = double.tryParse(_priceController.text.trim());

    if (!ProductCatalog.isValidProductId(productId)) return 'product_id_invalid';
    if (title.isEmpty || description.isEmpty || priceParsed == null) {
      return 'staff_validation_required';
    }

    final imageError = ProductImagesFieldValidation.validate(
      keptUrls: _keptImageUrls,
      newImages: _newProductImages,
      barcodeImage: _barcodeImage,
      hadBarcode: false,
    );
    if (imageError != null) return imageError;

    if (_strictForm) {
      if (_formSeason == null || _formAgeGroup == null || _formSex == null || _formType == null) {
        return 'staff_validation_select_all';
      }
    }

    final inventoryError = VariantInventoryFieldValidation.validate(
      inventory: _variantInventory,
      requireExplicitChoice: _strictForm,
      acknowledgedBranches: _variantInventoryAcknowledged,
    );
    if (inventoryError != null) return inventoryError;

    final salePricing = ProductCatalog.resolveSalePricing(
      regularPrice: priceParsed,
      salePriceText: _salePriceController.text.trim(),
      discountPercentText: _discountPercentController.text.trim(),
    );
    if (salePricing.errorKey != null) return salePricing.errorKey;

    return null;
  }

  Future<void> _submitProduct() async {
    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(validationError))));
      return;
    }

    final productId = _productIdController.text.trim();
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final staffNotes = _staffNotesController.text.trim();
    final priceParsed = double.parse(_priceController.text.trim());

    final inventorySave = ProductCatalog.resolveVariantInventoryForSave(_variantInventory);
    final size = inventorySave.size;
    final colors = inventorySave.colors;
    final salePricing = ProductCatalog.resolveSalePricing(
      regularPrice: priceParsed,
      salePriceText: _salePriceController.text.trim(),
      discountPercentText: _discountPercentController.text.trim(),
    );
    final soldPriceParsed = salePricing.soldPrice;
    final discountPercent = salePricing.discountPercent;

    setState(() => _isUploading = true);

    try {
      final staffRole = await StaffStorageAuth.prepareForUpload();

      if (await ProductWriteService.productDocExists(productId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('product_id_taken'))));
        }
        return;
      }

      final uploaded = await ProductImageService.uploadNewProductImages(
        productId: productId,
        productImages: _newProductImages,
        barcodeImage: _barcodeImage!,
      );

      final isAdmin = staffRole == 'admin';
      final season = _formSeason ?? 'summer';
      final ageGroup = _formAgeGroup ?? 'adult';
      final sex = _formSex ?? 'female';
      final type = _formType ?? 'clothes';

      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'productId': productId,
        'title': title,
        'description': description,
        'staffNotes': staffNotes,
        'size': size,
        if (colors.isNotEmpty) 'colors': colors,
        'price': priceParsed.toDouble(),
        if (discountPercent != null) ...{
          'discountPercent': discountPercent,
          'soldPrice': soldPriceParsed,
        },
        ...ProductCatalog.imageFieldsForWrite(
          imageUrls: uploaded.imageUrls,
          barcodeImageUrl: uploaded.barcodeUrl,
          imageColorByUrl: ProductCatalog.mergeImageColorsAfterUpload(
            appliedUrls: uploaded.imageUrls,
            keptUrls: const [],
            colorByKeptUrl: const {},
            colorsForNewImages: _colorsForNewImages,
          ),
        ),
        'season': season,
        'ageGroup': ageGroup,
        'sex': sex,
        'type': type,
        'favoriteCount': 0,
        'viewCount': 0,
        ...ProductCatalog.variantInventoryFieldsForWrite(_variantInventory),
        'visibility': isAdmin,
        'approved': isAdmin,
        'needsApproval': !isAdmin,
        'editPending': false,
        'sold': false,
        'created_at': FieldValue.serverTimestamp(),
        ...ProductCatalog.searchIndexFields(
          title: title,
          description: description,
          productId: productId,
          size: size,
          colors: colors,
          price: priceParsed,
          soldPrice: soldPriceParsed,
          season: season,
          ageGroup: ageGroup,
          sex: sex,
          type: type,
        ),
      });

      ProductCatalogService.instance.invalidate();

      _productIdController.clear();
      _titleController.clear();
      _descController.clear();
      _staffNotesController.clear();
      setState(() {
        _productImagesKey++;
        _variantInventoryKey++;
        _keptImageUrls = [];
        _newProductImages = [];
        _barcodeImage = null;
        _variantInventory = VariantInventory.empty();
        _variantInventoryAcknowledged = {};
        if (_strictForm) {
          _formSeason = null;
          _formAgeGroup = null;
          _formSex = null;
          _formType = null;
        }
      });
      _priceController.clear();
      _discountPercentController.clear();
      _salePriceController.clear();

      if (mounted) {
        final message = isAdmin
            ? S.fmt('staff_published_success', {'id': productId})
            : S.fmt('staff_submitted_success', {'id': productId});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e, st) {
      debugPrint('Staff add product failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e, fallbackKey: 'staff_upload_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamDark),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                S.fmt('staff_add_title', {'role': S.roleLabel(widget.userRole)}),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.ink, letterSpacing: 0.8),
              ),
            ],
          ),
          if (widget.userRole == 'employee')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                S.of('staff_approval_notice'),
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted.withValues(alpha: 0.9)),
              ),
            ),
          const SizedBox(height: 16),
          StaffFormSection(
            title: S.of('staff_section_basics'),
            icon: Icons.edit_note_rounded,
            accent: AppColors.ink,
            dense: true,
            children: [
              TextField(
                controller: _productIdController,
                decoration: InputDecoration(
                  labelText: S.of('field_product_id'),
                  hintText: S.of('field_product_id_hint'),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: S.of('field_title'), isDense: true),
              ),
              TextField(
                controller: _descController,
                decoration: InputDecoration(labelText: S.of('field_description'), isDense: true),
                maxLines: 2,
              ),
              TextField(
                controller: _staffNotesController,
                decoration: InputDecoration(
                  labelText: S.of('field_staff_notes'),
                  hintText: S.of('field_staff_notes_hint'),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          StaffFormSection(
            title: S.of('staff_section_inventory'),
            icon: Icons.storefront_outlined,
            accent: AppColors.gold,
            dense: true,
            children: [
              VariantInventoryField(
                key: ValueKey('variant_inventory_$_variantInventoryKey'),
                dense: true,
                requireExplicitChoice: _strictForm,
                onChanged: (values) => setState(() => _variantInventory = values),
                onAcknowledgedBranchesChanged: (ack) =>
                    setState(() => _variantInventoryAcknowledged = ack),
              ),
            ],
          ),
          StaffFormSection(
            title: S.of('staff_section_media'),
            icon: Icons.photo_library_outlined,
            accent: AppColors.violet,
            dense: true,
            children: [
              ProductImagesField(
                key: ValueKey('photos_$_productImagesKey'),
                dense: true,
                availableColors: _photoColorOptions,
                onKeptUrlsChanged: (urls) => _keptImageUrls = urls,
                onNewImagesChanged: (images) => _newProductImages = images,
                onBarcodeImageChanged: (bytes) => _barcodeImage = bytes,
                onRemovedUrlsChanged: (_) {},
                onColorByKeptUrlChanged: (_) {},
                onColorsForNewImagesChanged: (colors) => _colorsForNewImages = colors,
              ),
            ],
          ),
          StaffFormSection(
            title: S.of('staff_section_pricing'),
            icon: Icons.sell_outlined,
            accent: AppColors.coral,
            dense: true,
            children: [
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: S.of('field_price'), isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              SalePricingFields(
                dense: true,
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
            dense: true,
            children: [
              AudienceFields(
                dense: true,
                requireExplicitChoice: _strictForm,
                ageGroup: _formAgeGroup,
                sex: _formSex,
                onAgeGroupChanged: (v) => setState(() => _formAgeGroup = v),
                onSexChanged: (v) => setState(() => _formSex = v),
              ),
              StaffChoiceDropdown(
                dense: true,
                label: S.of('field_season'),
                value: _formSeason,
                options: ProductCatalog.seasons,
                optionLabel: ProductCatalog.label,
                requireExplicitChoice: _strictForm,
                onChanged: (v) => setState(() => _formSeason = v),
              ),
              StaffChoiceDropdown(
                dense: true,
                label: S.of('field_category'),
                value: _formType,
                options: ProductCatalog.types,
                optionLabel: ProductCatalog.label,
                requireExplicitChoice: _strictForm,
                onChanged: (v) => setState(() => _formType = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _isUploading
              ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
              : SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.coral.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submitProduct,
                      child: Text(
                        widget.userRole == 'admin' ? S.of('staff_publish') : S.of('staff_submit'),
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
