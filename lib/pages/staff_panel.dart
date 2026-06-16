import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../services/product_catalog_service.dart';
import '../services/product_write_service.dart';
import '../utils/image_compressor.dart';
import '../widgets/audience_fields.dart';
import '../widgets/color_input_field.dart';
import '../widgets/sale_pricing_fields.dart';
import '../widgets/size_input_field.dart';
import '../widgets/staff_choice_dropdown.dart';

enum _FieldChoice { unset, notDetermined, specified }

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
  final _priceController = TextEditingController();
  String _sizesEncoded = '';
  String _colorsEncoded = '';
  int _sizeInputKey = 0;
  int _colorInputKey = 0;
  final _discountPercentController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockQtyController = TextEditingController();

  Uint8List? _imageBytes;
  bool _isCompressing = false;
  bool _isUploading = false;

  String? _formSeason;
  String? _formAgeGroup;
  String? _formSex;
  String? _formType;
  _FieldChoice _colorChoice = _FieldChoice.unset;
  _FieldChoice _stockChoice = _FieldChoice.unset;

  bool get _strictForm => widget.userRole == 'employee';

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
    final sizes = ProductCatalog.sizesFromField(_sizesEncoded);
    final priceParsed = double.tryParse(_priceController.text.trim());

    if (!ProductCatalog.isValidProductId(productId)) return 'product_id_invalid';
    if (title.isEmpty || description.isEmpty || sizes.isEmpty || priceParsed == null || _imageBytes == null) {
      return sizes.isEmpty ? 'sizes_required' : 'staff_validation_required';
    }

    if (_strictForm) {
      if (_formSeason == null || _formAgeGroup == null || _formSex == null || _formType == null) {
        return 'staff_validation_select_all';
      }
      if (_colorChoice == _FieldChoice.unset) return 'staff_validation_colors';
      if (_stockChoice == _FieldChoice.unset) return 'staff_validation_stock';
      if (_stockChoice == _FieldChoice.specified) {
        final stockQtyText = _stockQtyController.text.trim();
        if (stockQtyText.isEmpty) return 'staff_validation_stock';
        final stockQtyParsed = int.tryParse(stockQtyText);
        if (stockQtyParsed == null || stockQtyParsed < 0) return 'stock_qty_invalid';
      }
    }

    final salePricing = ProductCatalog.resolveSalePricing(
      regularPrice: priceParsed,
      salePriceText: _salePriceController.text.trim(),
      discountPercentText: _discountPercentController.text.trim(),
    );
    if (salePricing.errorKey != null) return salePricing.errorKey;

    if (!_strictForm) {
      final stockQtyText = _stockQtyController.text.trim();
      if (stockQtyText.isNotEmpty) {
        final stockQtyParsed = int.tryParse(stockQtyText);
        if (stockQtyParsed == null || stockQtyParsed < 0) return 'stock_qty_invalid';
      }
    }

    return null;
  }

  void _onColorsEncodedChanged(String value) {
    _colorsEncoded = value;
    if (!_strictForm) return;
    setState(() {
      if (ProductCatalog.isNotDetermined(value)) {
        _colorChoice = _FieldChoice.notDetermined;
      } else if (ProductCatalog.colorsFromField(value).isNotEmpty) {
        _colorChoice = _FieldChoice.specified;
      } else {
        _colorChoice = _FieldChoice.unset;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isCompressing = true);

      final rawBytes = await picked.readAsBytes();
      final compressed = await ImageCompressor.compressForUpload(rawBytes);

      if (!mounted) return;

      setState(() {
        _imageBytes = compressed ?? rawBytes;
        _isCompressing = false;
      });
    } catch (e) {
      debugPrint('Image picking failed: $e');
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  void _clearImage() {
    setState(() => _imageBytes = null);
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
    final sizes = ProductCatalog.sizesFromField(_sizesEncoded);
    final size = ProductCatalog.encodeSizes(sizes);
    final priceParsed = double.parse(_priceController.text.trim());

    final colors = _resolveColorsForSave();
    final salePricing = ProductCatalog.resolveSalePricing(
      regularPrice: priceParsed,
      salePriceText: _salePriceController.text.trim(),
      discountPercentText: _discountPercentController.text.trim(),
    );
    final soldPriceParsed = salePricing.soldPrice;
    final discountPercent = salePricing.discountPercent;
    final stockQtyParsed = _resolveStockQtyForSave();

    setState(() => _isUploading = true);

    try {
      if (await ProductWriteService.productDocExists(productId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('product_id_taken'))));
        }
        return;
      }

      final storageRef = FirebaseStorage.instance.ref().child('product_images/$productId.jpg');
      final uploadTask = storageRef.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      final isAdmin = widget.userRole == 'admin';
      final season = _formSeason ?? 'summer';
      final ageGroup = _formAgeGroup ?? 'adult';
      final sex = _formSex ?? 'female';
      final type = _formType ?? 'clothes';

      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'productId': productId,
        'title': title,
        'description': description,
        'size': size,
        if (colors.isNotEmpty) 'colors': colors,
        'price': priceParsed,
        if (discountPercent != null) ...{
          'discountPercent': discountPercent,
          'soldPrice': soldPriceParsed,
        },
        'imageUrl': imageUrl,
        'season': season,
        'ageGroup': ageGroup,
        'sex': sex,
        'type': type,
        'favoriteCount': 0,
        'viewCount': 0,
        if (stockQtyParsed != null) 'stockQty': stockQtyParsed,
        'visibility': isAdmin,
        'approved': isAdmin,
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
      setState(() {
        _sizesEncoded = '';
        _colorsEncoded = '';
        _sizeInputKey++;
        _colorInputKey++;
        _imageBytes = null;
        if (_strictForm) {
          _formSeason = null;
          _formAgeGroup = null;
          _formSex = null;
          _formType = null;
          _colorChoice = _FieldChoice.unset;
          _stockChoice = _FieldChoice.unset;
        }
      });
      _priceController.clear();
      _discountPercentController.clear();
      _salePriceController.clear();
      _stockQtyController.clear();

      if (mounted) {
        final message = isAdmin
            ? S.fmt('staff_published_success', {'id': productId})
            : S.fmt('staff_submitted_success', {'id': productId});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('staff_upload_failed', {'error': '$e'}))));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _resolveColorsForSave() {
    if (_strictForm && _colorChoice == _FieldChoice.notDetermined) {
      return ProductCatalog.notDetermined;
    }
    return ProductCatalog.encodeColors(ProductCatalog.colorsFromField(_colorsEncoded));
  }

  int? _resolveStockQtyForSave() {
    if (_strictForm) {
      if (_stockChoice == _FieldChoice.notDetermined) return null;
      return int.tryParse(_stockQtyController.text.trim());
    }
    final stockQtyText = _stockQtyController.text.trim();
    if (stockQtyText.isEmpty) return null;
    return int.tryParse(stockQtyText);
  }

  Widget _stockChoiceSection() {
    if (!_strictForm) {
      return TextField(
        controller: _stockQtyController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: S.of('field_stock_qty'),
          hintText: S.of('field_stock_qty_hint'),
          isDense: true,
        ),
      );
    }

    final chipStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('field_stock_qty'),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(ProductCatalog.notDeterminedLabel(), style: chipStyle),
              selected: _stockChoice == _FieldChoice.notDetermined,
              onSelected: (_) => setState(() {
                _stockChoice = _FieldChoice.notDetermined;
                _stockQtyController.clear();
              }),
            ),
            ChoiceChip(
              label: Text(S.of('field_stock_set_qty'), style: chipStyle),
              selected: _stockChoice == _FieldChoice.specified,
              onSelected: (_) => setState(() => _stockChoice = _FieldChoice.specified),
            ),
          ],
        ),
        if (_stockChoice == _FieldChoice.specified) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _stockQtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: S.of('field_stock_qty_hint'),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _discountPercentController.dispose();
    _salePriceController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageBytes != null;

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
          TextField(
            controller: _productIdController,
            decoration: InputDecoration(
              labelText: S.of('field_product_id'),
              hintText: S.of('field_product_id_hint'),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: (_isUploading || _isCompressing) ? null : _pickImage,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.creamDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.creamDark),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isCompressing
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))
                        : hasImage
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: _clearImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, color: AppColors.inkMuted),
                                  const SizedBox(height: 4),
                                  Text(S.of('staff_image_label'), style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: S.of('field_title'), isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      decoration: InputDecoration(labelText: S.of('field_description'), isDense: true),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      decoration: InputDecoration(labelText: S.of('field_price'), isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    SalePricingFields(
                      dense: true,
                      regularPriceController: _priceController,
                      salePriceController: _salePriceController,
                      discountPercentController: _discountPercentController,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _stockChoiceSection(),
          const SizedBox(height: 16),
          SizeInputField(
            key: ValueKey('size_$_sizeInputKey'),
            dense: true,
            onEncodedChanged: (value) => _sizesEncoded = value,
          ),
          const SizedBox(height: 16),
          ColorInputField(
            key: ValueKey('color_$_colorInputKey'),
            dense: true,
            allowNotDetermined: _strictForm,
            notDeterminedSelected: _colorChoice == _FieldChoice.notDetermined,
            onEncodedChanged: _onColorsEncodedChanged,
            onNotDeterminedSelected: () => setState(() => _colorChoice = _FieldChoice.notDetermined),
            onColorsSpecified: () => setState(() => _colorChoice = _FieldChoice.specified),
          ),
          const SizedBox(height: 16),
          AudienceFields(
            dense: true,
            requireExplicitChoice: _strictForm,
            ageGroup: _formAgeGroup,
            sex: _formSex,
            onAgeGroupChanged: (v) => setState(() => _formAgeGroup = v),
            onSexChanged: (v) => setState(() => _formSex = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StaffChoiceDropdown(
                  dense: true,
                  label: S.of('field_season'),
                  value: _formSeason,
                  options: ProductCatalog.seasons,
                  optionLabel: ProductCatalog.label,
                  requireExplicitChoice: _strictForm,
                  onChanged: (v) => setState(() => _formSeason = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StaffChoiceDropdown(
                  dense: true,
                  label: S.of('field_category'),
                  value: _formType,
                  options: ProductCatalog.types,
                  optionLabel: ProductCatalog.label,
                  requireExplicitChoice: _strictForm,
                  onChanged: (v) => setState(() => _formType = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
