import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/top_slider_slide.dart';
import '../services/locale_service.dart';
import '../services/staff_storage_auth.dart';
import '../services/top_slider_service.dart';
import '../theme/app_theme.dart';
import '../utils/hero_slider_settings.dart';
import '../utils/image_compressor.dart';

class HeroSliderManageSheet extends StatefulWidget {
  final HeroSliderSize initialSize;
  final VoidCallback? onUpdated;

  const HeroSliderManageSheet({
    super.key,
    required this.initialSize,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required HeroSliderSize initialSize,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => HeroSliderManageSheet(initialSize: initialSize, onUpdated: onUpdated),
    );
  }

  @override
  State<HeroSliderManageSheet> createState() => _HeroSliderManageSheetState();
}

class _HeroSliderManageSheetState extends State<HeroSliderManageSheet> {
  static const _categories = [
    TopSliderCategory.male,
    TopSliderCategory.female,
    TopSliderCategory.boy,
    TopSliderCategory.girl,
    TopSliderCategory.sale,
  ];

  late HeroSliderSize _size;
  TopSliderCategory? _uploadingCategory;

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
    StaffStorageAuth.prepareForUpload().catchError((Object e) {
      debugPrint('Hero manage sheet: staff check failed: $e');
    });
  }

  String _label(TopSliderCategory category) {
    switch (category) {
      case TopSliderCategory.male:
        return S.of('hero_slide_male');
      case TopSliderCategory.female:
        return S.of('hero_slide_female');
      case TopSliderCategory.boy:
        return S.of('hero_slide_boy');
      case TopSliderCategory.girl:
        return S.of('hero_slide_girl');
      case TopSliderCategory.sale:
        return S.of('hero_slide_sale');
      case TopSliderCategory.unknown:
        return '';
    }
  }

  Future<void> _upload(TopSliderCategory category) async {
    if (_uploadingCategory != null) return;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      setState(() => _uploadingCategory = category);

      final rawBytes = await picked.readAsBytes();
      final bytes = await ImageCompressor.compressForHeroUpload(rawBytes, size: _size);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not process this image. Try a JPG or PNG from your gallery.');
      }
      ImageCompressor.ensureHeroUploadSize(bytes);

      final isArabic = LocaleService.instance.isArabic;

      await TopSliderService.uploadSlide(
        isArabic: isArabic,
        size: _size,
        category: category,
        imageBytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('hero_upload_success'))));
      widget.onUpdated?.call();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Hero slide upload failed: $e');
      if (mounted) {
        final detail = switch (e) {
          FirebaseException(:final message) => message,
          StateError(:final message) => message,
          _ => '$e',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of('hero_upload_failed')} $detail')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCategory = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeLabel = LocaleService.instance.isArabic ? S.of('hero_locale_ar') : S.of('hero_locale_en');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of('hero_manage_slides'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            localeLabel,
            style: TextStyle(fontSize: 13, color: AppColors.ink.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 14),
          SegmentedButton<HeroSliderSize>(
            segments: [
              ButtonSegment(
                value: HeroSliderSize.mobile,
                label: Text(S.of('hero_size_mobile'), style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.phone_iphone_rounded, size: 16),
              ),
              ButtonSegment(
                value: HeroSliderSize.web,
                label: Text(S.of('hero_size_web'), style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.laptop_mac_rounded, size: 16),
              ),
            ],
            selected: {_size},
            onSelectionChanged: (value) => setState(() => _size = value.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.fmt('hero_storage_path', {
              'path': 'topSlider/${TopSliderService.localeFolder(LocaleService.instance.isArabic)}/${_size.folderName}/',
            }),
            style: TextStyle(fontSize: 11, color: AppColors.ink.withValues(alpha: 0.55), height: 1.35),
          ),
          const SizedBox(height: 16),
          ..._categories.map((category) {
            final busy = _uploadingCategory == category;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: busy ? null : () => _upload(category),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _label(category),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                        if (busy)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_rounded, size: 18, color: AppColors.coral),
                              const SizedBox(width: 6),
                              Text(
                                S.of('hero_upload_slide'),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.coral, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
