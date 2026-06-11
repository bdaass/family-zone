import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/image_compressor.dart';

class StaffManagementPanel extends StatefulWidget {
  final String userRole;
  const StaffManagementPanel({super.key, required this.userRole});

  @override
  State<StaffManagementPanel> createState() => _StaffManagementPanelState();
}

class _StaffManagementPanelState extends State<StaffManagementPanel> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _sizeController = TextEditingController();
  final _priceController = TextEditingController();
  final _soldPriceController = TextEditingController();

  Uint8List? _imageBytes;
  bool _isCompressing = false;
  bool _isUploading = false;

  String _formSeason = 'summer';
  String _formGender = 'woman';
  String _formType = 'clothes';

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
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final size = _sizeController.text.trim();
    final priceParsed = double.tryParse(_priceController.text.trim());

    final soldPriceText = _soldPriceController.text.trim();
    final soldPriceParsed = soldPriceText.isEmpty ? null : double.tryParse(soldPriceText);

    if (title.isEmpty || description.isEmpty || size.isEmpty || priceParsed == null || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('staff_validation_required'))),
      );
      return;
    }
    if (soldPriceText.isNotEmpty && (soldPriceParsed == null || soldPriceParsed >= priceParsed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('sale_price_invalid'))),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('products').doc();
      final productId = docRef.id;

      final storageRef = FirebaseStorage.instance.ref().child('product_images/$productId.jpg');
      final uploadTask = storageRef.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      final isAdmin = widget.userRole == 'admin';

      await docRef.set({
        'productId': productId,
        'title': title,
        'description': description,
        'size': size,
        'price': priceParsed,
        if (soldPriceParsed != null) 'soldPrice': soldPriceParsed,
        'imageUrl': imageUrl,
        'season': _formSeason,
        'sex': _formGender,
        'type': _formType,
        'favoriteCount': 0,
        'visibility': isAdmin,
        'approved': isAdmin,
        'sold': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _descController.clear();
      _sizeController.clear();
      _priceController.clear();
      _soldPriceController.clear();
      setState(() => _imageBytes = null);

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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sizeController,
                            decoration: InputDecoration(labelText: S.of('field_size'), isDense: true, hintText: S.of('field_size_hint')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            decoration: InputDecoration(labelText: S.of('field_price'), isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _soldPriceController,
                      decoration: InputDecoration(
                        labelText: S.of('field_sale_price'),
                        isDense: true,
                        hintText: S.of('field_sale_price_hint'),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _formSeason,
                  items: ProductCatalog.seasons
                      .map((s) => DropdownMenuItem(value: s, child: Text(ProductCatalog.label(s), style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _formSeason = v!),
                  decoration: InputDecoration(labelText: S.of('field_season'), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _formGender,
                  items: ProductCatalog.genders
                      .map((g) => DropdownMenuItem(value: g, child: Text(ProductCatalog.label(g), style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _formGender = v!),
                  decoration: InputDecoration(labelText: S.of('field_gender'), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _formType,
                  items: ProductCatalog.types
                      .map((t) => DropdownMenuItem(value: t, child: Text(ProductCatalog.label(t), style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _formType = v!),
                  decoration: InputDecoration(labelText: S.of('field_category'), isDense: true),
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
