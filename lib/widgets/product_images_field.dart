import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/image_compressor.dart';
import 'product_image_carousel.dart';
import 'staff_barcode_image.dart';

/// Staff product photos + mandatory barcode capture (barcode preview admin-only on edit).
class ProductImagesField extends StatefulWidget {
  final List<String> initialImageUrls;
  final Map<String, String> initialImageColorByUrl;
  final List<String> availableColors;
  final bool hasExistingBarcode;
  final String? existingBarcodeUrl;
  final String? storageProductId;
  final bool showBarcodePreview;
  final bool dense;
  final ValueChanged<List<String>> onKeptUrlsChanged;
  final ValueChanged<List<Uint8List>> onNewImagesChanged;
  final ValueChanged<Uint8List?> onBarcodeImageChanged;
  final ValueChanged<List<String>> onRemovedUrlsChanged;
  final ValueChanged<Map<String, String>> onColorByKeptUrlChanged;
  final ValueChanged<List<String?>> onColorsForNewImagesChanged;

  const ProductImagesField({
    super.key,
    this.initialImageUrls = const [],
    this.initialImageColorByUrl = const {},
    this.availableColors = const [],
    this.hasExistingBarcode = false,
    this.existingBarcodeUrl,
    this.storageProductId,
    this.showBarcodePreview = false,
    this.dense = false,
    required this.onKeptUrlsChanged,
    required this.onNewImagesChanged,
    required this.onBarcodeImageChanged,
    required this.onRemovedUrlsChanged,
    required this.onColorByKeptUrlChanged,
    required this.onColorsForNewImagesChanged,
  });

  @override
  State<ProductImagesField> createState() => _ProductImagesFieldState();
}

class _ProductImagesFieldState extends State<ProductImagesField> {
  final _picker = ImagePicker();
  late List<String> _keptUrls;
  final List<Uint8List> _newImages = [];
  final List<String> _removedUrls = [];
  final Map<String, String> _colorByKeptUrl = {};
  final List<String?> _newImageColors = [];
  Uint8List? _barcodeBytes;
  bool _isCompressing = false;

  @override
  void initState() {
    super.initState();
    _keptUrls = List<String>.from(widget.initialImageUrls);
    _colorByKeptUrl.addAll(widget.initialImageColorByUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() {
    widget.onKeptUrlsChanged(_keptUrls);
    widget.onNewImagesChanged(List<Uint8List>.from(_newImages));
    widget.onBarcodeImageChanged(_barcodeBytes);
    widget.onRemovedUrlsChanged(List<String>.from(_removedUrls));
    widget.onColorByKeptUrlChanged(Map<String, String>.from(_colorByKeptUrl));
    widget.onColorsForNewImagesChanged(List<String?>.from(_newImageColors));
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  S.of('image_source_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.ink),
                title: Text(S.of('image_source_gallery'), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.ink),
                title: Text(S.of('image_source_camera'), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Uint8List>> _compressPickedFiles(List<XFile> picked) async {
    final compressed = <Uint8List>[];
    for (final file in picked) {
      final raw = await file.readAsBytes();
      final result = await ImageCompressor.compressForUpload(raw);
      compressed.add(result ?? raw);
    }
    return compressed;
  }

  Future<void> _pickProductImages() async {
    if (_isCompressing) return;
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    try {
      setState(() => _isCompressing = true);
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await _picker.pickMultiImage();
      } else {
        final single = await _picker.pickImage(source: ImageSource.camera);
        picked = single != null ? [single] : [];
      }
      if (picked.isEmpty) {
        if (mounted) setState(() => _isCompressing = false);
        return;
      }

      final compressed = await _compressPickedFiles(picked);

      if (!mounted) return;
      setState(() {
        _newImages.addAll(compressed);
        _newImageColors.addAll(List<String?>.filled(compressed.length, null));
        _isCompressing = false;
      });
      _notify();
    } catch (e) {
      debugPrint('Product image pick failed: $e');
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  Future<void> _pickBarcodeImage() async {
    if (_isCompressing) return;
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    try {
      setState(() => _isCompressing = true);
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        if (mounted) setState(() => _isCompressing = false);
        return;
      }
      final raw = await picked.readAsBytes();
      final compressed = await ImageCompressor.compressForUpload(raw);
      if (!mounted) return;
      setState(() {
        _barcodeBytes = compressed ?? raw;
        _isCompressing = false;
      });
      _notify();
    } catch (e) {
      debugPrint('Barcode image pick failed: $e');
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  void _removeKeptUrl(String url) {
    setState(() {
      _keptUrls.remove(url);
      _colorByKeptUrl.remove(url);
      if (!_removedUrls.contains(url)) _removedUrls.add(url);
    });
    _notify();
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
      if (index < _newImageColors.length) _newImageColors.removeAt(index);
    });
    _notify();
  }

  void _clearBarcode() {
    setState(() => _barcodeBytes = null);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.dense ? 72.0 : 88.0;
    final gap = widget.dense ? 8.0 : 12.0;
    final hasBarcode =
        _barcodeBytes != null || widget.hasExistingBarcode || (widget.existingBarcodeUrl?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('field_product_images'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        SizedBox(height: gap),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.availableColors.isEmpty
                ? S.of('field_image_color_need_stock')
                : S.of('field_image_color_hint'),
            style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in _keptUrls)
              _thumbWithColor(
                size: thumb,
                selectedColor: _colorByKeptUrl[url],
                onColorChanged: (color) {
                  setState(() {
                    if (color == null || color.isEmpty) {
                      _colorByKeptUrl.remove(url);
                    } else {
                      _colorByKeptUrl[url] = color;
                    }
                  });
                  _notify();
                },
                thumb: _thumbNetwork(url, thumb, () => _removeKeptUrl(url)),
              ),
            for (var i = 0; i < _newImages.length; i++)
              _thumbWithColor(
                size: thumb,
                selectedColor: i < _newImageColors.length ? _newImageColors[i] : null,
                onColorChanged: (color) {
                  setState(() {
                    while (_newImageColors.length < _newImages.length) {
                      _newImageColors.add(null);
                    }
                    _newImageColors[i] = color;
                  });
                  _notify();
                },
                thumb: _thumbMemory(_newImages[i], thumb, () => _removeNewImage(i)),
              ),
            _addTile(thumb, S.of('field_add_photos'), _pickProductImages),
          ],
        ),
        if (_isCompressing) ...[
          SizedBox(height: gap),
          const LinearProgressIndicator(minHeight: 2, color: AppColors.coral),
        ],
        SizedBox(height: gap * 1.5),
        Text(
          S.of('field_barcode_image'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.showBarcodePreview ? S.of('field_barcode_admin_hint') : S.of('field_barcode_staff_hint'),
          style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
        ),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showBarcodePreview && widget.existingBarcodeUrl?.isNotEmpty == true && _barcodeBytes == null)
              _barcodeNetworkThumb(widget.existingBarcodeUrl!, thumb, _pickBarcodeImage)
            else if (_barcodeBytes != null)
              _thumbMemory(_barcodeBytes!, thumb, _clearBarcode)
            else if (hasBarcode && !widget.showBarcodePreview)
              _placeholderTile(
                thumb,
                icon: Icons.verified_outlined,
                label: S.of('field_barcode_on_file'),
                onTap: _pickBarcodeImage,
              )
            else
              _addTile(thumb, S.of('field_add_barcode'), _pickBarcodeImage),
          ],
        ),
      ],
    );
  }

  Widget _thumbWithColor({
    required double size,
    required Widget thumb,
    required String? selectedColor,
    required ValueChanged<String?> onColorChanged,
  }) {
    if (widget.availableColors.isEmpty) return thumb;

    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          thumb,
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isDense: true,
              isExpanded: true,
              value: selectedColor != null &&
                      widget.availableColors.any((c) => ProductCatalog.colorsMatch(c, selectedColor))
                  ? widget.availableColors.firstWhere((c) => ProductCatalog.colorsMatch(c, selectedColor))
                  : null,
              hint: Text(
                S.of('field_image_color_none'),
                style: TextStyle(fontSize: widget.dense ? 9 : 10, color: AppColors.inkMuted),
                overflow: TextOverflow.ellipsis,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(S.of('field_image_color_none'), style: const TextStyle(fontSize: 11)),
                ),
                for (final color in widget.availableColors)
                  DropdownMenuItem<String?>(
                    value: color,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: ProductCatalog.colorSwatchFill(color),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: AppColors.creamDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ProductCatalog.colorDisplayName(color),
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: onColorChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbNetwork(String url, double size, VoidCallback onRemove) {
    return _thumbFrame(
      size,
      Stack(
        fit: StackFit.expand,
        children: [
          ProductNetworkImage(url: url, fit: BoxFit.cover),
          _removeButton(onRemove),
        ],
      ),
    );
  }

  Widget _barcodeNetworkThumb(String url, double size, VoidCallback onReplace) {
    final storageId = widget.storageProductId?.trim() ?? '';
    return _thumbFrame(
      size,
      Stack(
        fit: StackFit.expand,
        children: [
          StaffBarcodeImage(
            imageUrl: url,
            storageProductId: storageId,
            fit: BoxFit.cover,
          ),
          _removeButton(onReplace),
        ],
      ),
    );
  }

  Widget _thumbMemory(Uint8List bytes, double size, VoidCallback onRemove) {
    return _thumbFrame(
      size,
      Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.cover),
          _removeButton(onRemove),
        ],
      ),
    );
  }

  Widget _addTile(double size, String label, VoidCallback onTap) {
    return _thumbFrame(
      size,
      InkWell(
        onTap: _isCompressing ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.inkMuted, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderTile(double size, {required IconData icon, required String label, required VoidCallback onTap}) {
    return _thumbFrame(
      size,
      InkWell(
        onTap: _isCompressing ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.violet, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.ink, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFrame(double size, Widget child) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.creamDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDark),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(11), child: child),
      ),
    );
  }

  Widget _removeButton(VoidCallback onTap) {
    return Positioned(
      top: 4,
      right: 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

/// Validation helpers for staff forms.
class ProductImagesFieldValidation {
  static String? validate({
    required List<String> keptUrls,
    required List<Uint8List> newImages,
    required Uint8List? barcodeImage,
    required bool hadBarcode,
  }) {
    if (keptUrls.isEmpty && newImages.isEmpty) return 'staff_validation_images';
    if (barcodeImage == null && !hadBarcode) return 'staff_validation_barcode';
    return null;
  }
}
