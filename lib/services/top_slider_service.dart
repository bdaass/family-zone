import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/top_slider_slide.dart';
import '../utils/hero_slider_settings.dart';

/// Loads locale- and size-specific hero banners from Firebase Storage.
///
/// Storage layout:
/// - `topSlider/{English|arabic}/{mobile|web}/Male.jpg`
/// Legacy fallbacks (no size folder):
/// - `topSlider/{English|arabic}/Male.jpg`
/// - `web/topSlider/{English|arabic}/Male.jpg`
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
          final slides = await _loadKnownFiles('$prefix/$folder', size: size);
          if (slides.isNotEmpty) {
            _cache[cacheKey] = slides;
            return slides;
          }
        } catch (e, st) {
          debugPrint('TopSliderService: $prefix/$folder — $e\n$st');
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

  static Future<List<TopSliderSlide>> _loadKnownFiles(String folderPath, {required HeroSliderSize size}) async {
    final slides = <TopSliderSlide>[];

    for (final name in _slideNames) {
      final slide = await _resolveSlide(folderPath, name, size);
      if (slide != null) slides.add(slide);
    }

    slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }

  static Future<TopSliderSlide?> _resolveSlide(String folderPath, String name, HeroSliderSize size) async {
    final sizedPath = '$folderPath/${size.folderName}/$name';
    final sized = await _tryLoadFile(sizedPath);
    if (sized != null) {
      return TopSliderSlide(
        id: '${name.toLowerCase()}_${size.name}',
        imageUrl: sized,
        category: TopSliderCategory.fromFileStem(name),
      );
    }

    // Legacy: shared image without mobile/web subfolder.
    final legacy = await _tryLoadFile('$folderPath/$name');
    if (legacy != null) {
      return TopSliderSlide(
        id: name.toLowerCase(),
        imageUrl: legacy,
        category: TopSliderCategory.fromFileStem(name),
      );
    }

    return null;
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
}
