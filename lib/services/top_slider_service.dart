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

    if (kIsWeb) {
      final bundled = _loadHostingFiles(isArabic: isArabic, size: size);
      var storageSlides = const <TopSliderSlide>[];
      try {
        storageSlides = await _loadFromStorage(localeFolders, size: size).timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('TopSliderService: Storage unavailable on web, using bundled slides — $e');
      }
      final slides = storageSlides.isNotEmpty ? storageSlides : bundled;
      if (slides.isNotEmpty) _cache[cacheKey] = slides;
      return slides;
    }

    final storageSlides = await _loadFromStorage(localeFolders, size: size);
    if (storageSlides.isNotEmpty) {
      _cache[cacheKey] = storageSlides;
      return storageSlides;
    }

    // Do not cache empty — allows retry after uploads or connectivity fixes.
    return const [];
  }

  static void invalidateCache() {
    _cache.clear();
  }

  static Future<List<TopSliderSlide>> _loadFromStorage(List<String> localeFolders, {required HeroSliderSize size}) async {
    for (final prefix in _storagePrefixes) {
      for (final folder in localeFolders) {
        final slides = await _loadSlidesFromFolder('$prefix/$folder', size: size);
        if (slides.isNotEmpty) return slides;
      }
    }
    return const [];
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

  static Future<List<TopSliderSlide>> _loadSlidesFromFolder(String folderPath, {required HeroSliderSize size}) async {
    final sized = await _listSlidesInFolder('$folderPath/${size.folderName}', idSuffix: '_${size.name}');
    if (sized.isNotEmpty) return sized;

    // Legacy flat masters (no mobile/web subfolder).
    return _listSlidesInFolder(folderPath);
  }

  static Future<List<TopSliderSlide>> _listSlidesInFolder(String folderPath, {String idSuffix = ''}) async {
    try {
      final listing = await FirebaseStorage.instance.ref(folderPath).listAll();
      final slides = <TopSliderSlide>[];

      for (final item in listing.items) {
        final stem = _fileStem(item.name);
        if (stem == null || !_slideNames.contains(stem)) continue;

        try {
          final url = await item.getDownloadURL();
          slides.add(
            TopSliderSlide(
              id: '${stem.toLowerCase()}$idSuffix',
              imageUrl: url,
              category: TopSliderCategory.fromFileStem(stem),
            ),
          );
        } catch (e) {
          debugPrint('TopSliderService: download URL for ${item.fullPath} — $e');
        }
      }

      slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
      return slides;
    } catch (e) {
      debugPrint('TopSliderService: list $folderPath — $e');
      return const [];
    }
  }

  static String? _fileStem(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return null;
    final ext = fileName.substring(dot + 1).toLowerCase();
    if (!_extensions.contains(ext)) return null;
    return fileName.substring(0, dot);
  }

  /// Bundled assets shipped with the web build under `web/topSlider/{locale}/`.
  static List<TopSliderSlide> _loadHostingFiles({required bool isArabic, required HeroSliderSize size}) {
    final folder = localeFolder(isArabic);
    final slides = <TopSliderSlide>[];

    for (final name in _slideNames) {
      slides.add(
        TopSliderSlide(
          id: '${name.toLowerCase()}_${size.name}_host',
          imageUrl: _hostingAssetUrl(folder, name, size),
          category: TopSliderCategory.fromFileStem(name),
        ),
      );
    }

    slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }

  static String _hostingAssetUrl(String localeFolder, String name, HeroSliderSize size) {
    return Uri.base.resolve('/topSlider/$localeFolder/${size.folderName}/$name.jpg').toString();
  }
}
