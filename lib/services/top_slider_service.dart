import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/top_slider_slide.dart';
import '../utils/hero_slider_settings.dart';

/// Loads locale- and viewport-specific hero banners from Firebase Storage.
///
/// Storage layout (required for display):
/// - `topSlider/{English|arabic}/{mobile|web}/Male.jpg`
///
/// Legacy source masters (used by generate script, not shown directly):
/// - `topSlider/{English|arabic}/Male.jpg`
class TopSliderService {
  TopSliderService._();

  static final _cache = <String, List<TopSliderSlide>>{};

  static const _slideNames = ['Male', 'Female', 'Boy', 'Girl', 'Solde'];
  static const _extensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const _storagePrefixes = ['topSlider', 'web/topSlider'];

  static Future<List<TopSliderSlide>> fetchSlides({
    required bool isArabic,
    required HeroSliderSize size,
  }) async {
    final cacheKey = '${isArabic ? 'ar' : 'en'}_${size.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final localeFolders = isArabic ? const ['arabic', 'Arabic'] : const ['English', 'english'];

    for (final prefix in _storagePrefixes) {
      for (final folder in localeFolders) {
        try {
          final slides = await _loadSizedFiles('$prefix/$folder', size: size);
          if (slides.isNotEmpty) {
            _cache[cacheKey] = slides;
            return slides;
          }
        } catch (e, st) {
          debugPrint('TopSliderService: $prefix/$folder — $e\n$st');
        }
      }
    }

    if (kIsWeb) {
      for (final folder in localeFolders) {
        final slides = _loadHostingFiles(folder, size: size);
        if (slides.isNotEmpty) {
          _cache[cacheKey] = slides;
          return slides;
        }
      }
    }

    _cache[cacheKey] = const [];
    return const [];
  }

  static void invalidateCache() {
    _cache.clear();
  }

  static String localeFolder(bool isArabic) => isArabic ? 'arabic' : 'English';

  static String storageObjectPath({
    required bool isArabic,
    required HeroSliderSize size,
    required String fileStem,
  }) {
    return 'topSlider/${localeFolder(isArabic)}/${size.folderName}/$fileStem.jpg';
  }

  /// Upload or replace a hero banner (staff only — enforced by Storage rules).
  static Future<void> uploadSlide({
    required bool isArabic,
    required HeroSliderSize size,
    required TopSliderCategory category,
    required Uint8List imageBytes,
  }) async {
    final stem = category.fileStem;
    if (stem == null) {
      throw StateError('Cannot upload slide for category $category');
    }

    final ref = FirebaseStorage.instance.ref(storageObjectPath(isArabic: isArabic, size: size, fileStem: stem));
    await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    invalidateCache();
  }

  static Future<List<TopSliderSlide>> _loadSizedFiles(String folderPath, {required HeroSliderSize size}) async {
    final slides = <TopSliderSlide>[];

    for (final name in _slideNames) {
      final slide = await _resolveSizedSlide(folderPath, name, size);
      if (slide != null) slides.add(slide);
    }

    slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }

  static Future<TopSliderSlide?> _resolveSizedSlide(String folderPath, String name, HeroSliderSize size) async {
    final url = await _tryLoadFile('$folderPath/${size.folderName}/$name');
    if (url == null) return null;

    return TopSliderSlide(
      id: '${name.toLowerCase()}_${size.name}',
      imageUrl: url,
      category: TopSliderCategory.fromFileStem(name),
    );
  }

  static Future<String?> _tryLoadFile(String pathWithoutExtension) async {
    for (final ext in _extensions) {
      try {
        final ref = FirebaseStorage.instance.ref('$pathWithoutExtension.$ext');
        return await ref.getDownloadURL();
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Bundled sized assets in `web/topSlider/{locale}/{mobile|web}/`.
  static List<TopSliderSlide> _loadHostingFiles(String localeFolder, {required HeroSliderSize size}) {
    final slides = <TopSliderSlide>[];

    for (final name in _slideNames) {
      final url = _hostingSlideUrl(localeFolder, name, size);
      if (url == null) continue;
      slides.add(
        TopSliderSlide(
          id: '${name.toLowerCase()}_${size.name}_host',
          imageUrl: url,
          category: TopSliderCategory.fromFileStem(name),
        ),
      );
    }

    slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }

  static String? _hostingSlideUrl(String localeFolder, String name, HeroSliderSize size) {
    return Uri.base.resolve('/topSlider/$localeFolder/${size.folderName}/$name.jpg').toString();
  }
}
