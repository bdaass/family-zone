import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/top_slider_slide.dart';
import '../services/staff_storage_auth.dart';
import '../utils/hero_slider_settings.dart';
import '../utils/storage_object_probe.dart';

/// Loads locale- and viewport-specific hero banners from Firebase Storage.
///
/// Storage layout (preferred):
/// - `topSlider/{English|arabic}/{mobile|web}/Male.jpg`
///
/// Legacy flat masters (still supported):
/// - `topSlider/{English|arabic}/Male.jpg`
class TopSliderService {
  TopSliderService._();

  static final _cache = <String, List<TopSliderSlide>>{};
  static String? _storageBucket;

  static const _slideNames = ['Male', 'Female', 'Boy', 'Girl', 'Solde'];
  static const _storagePrefix = 'topSlider';

  static Future<List<TopSliderSlide>> fetchSlides({
    required bool isArabic,
    required HeroSliderSize size,
  }) async {
    final cacheKey = '${isArabic ? 'ar' : 'en'}_${size.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final localeFolders = isArabic ? const ['arabic', 'Arabic'] : const ['English', 'english'];

    for (final folder in localeFolders) {
      final slides = await _loadSlidesFromFolder('$_storagePrefix/$folder', size: size);
      if (slides.isNotEmpty) {
        _cache[cacheKey] = slides;
        return slides;
      }
    }

    if (kIsWeb) {
      final hosting = _loadHostingFiles(isArabic: isArabic, size: size);
      if (hosting.isNotEmpty) {
        _cache[cacheKey] = hosting;
        return hosting;
      }
    }

    debugPrint(
      'TopSliderService: no hero banners in Storage for '
      '${localeFolder(isArabic)}/${size.folderName}/ — '
      'upload via Hero banners (staff) or scripts/generate_top_slider_variants.mjs --upload-only',
    );
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
    return '$_storagePrefix/${localeFolder(isArabic)}/${size.folderName}/$fileStem.jpg';
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

    await StaffStorageAuth.prepareForUpload();

    final path = storageObjectPath(isArabic: isArabic, size: size, fileStem: stem);
    final ref = FirebaseStorage.instance.ref(path);

    try {
      await ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=3600',
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('TopSliderService.uploadSlide($path): ${e.code} — ${e.message}');
      rethrow;
    }

    invalidateCache();
  }

  static Future<List<TopSliderSlide>> _loadSlidesFromFolder(String folderPath, {required HeroSliderSize size}) async {
    final sized = await _resolveSlidesAt('$folderPath/${size.folderName}', idSuffix: '_${size.name}');
    if (sized.isNotEmpty) return sized;

    // Wide layout can reuse mobile crops when nothing was uploaded under /web/.
    if (size == HeroSliderSize.web) {
      final mobile = await _resolveSlidesAt(
        '$folderPath/${HeroSliderSize.mobile.folderName}',
        idSuffix: '_mobile',
      );
      if (mobile.isNotEmpty) return mobile;
    }

    return _resolveSlidesAt(folderPath);
  }

  static Future<List<TopSliderSlide>> _resolveSlidesAt(String folderPath, {String idSuffix = ''}) async {
    final results = await Future.wait(
      _slideNames.map((name) async {
        final objectPath = '$folderPath/$name.jpg';
        final imageUrl = await _resolveImageUrl(objectPath);
        if (imageUrl == null) return null;
        return TopSliderSlide(
          id: '${name.toLowerCase()}$idSuffix',
          imageUrl: imageUrl,
          category: TopSliderCategory.fromFileStem(name),
        );
      }),
    );

    final slides = results.whereType<TopSliderSlide>().toList()
      ..sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }

  /// Public `alt=media` URL — works without Firebase Auth (same pattern as product images).
  static String publicMediaUrl(String objectPath) {
    final bucket = _storageBucket ??= DefaultFirebaseOptions.currentPlatform.storageBucket!;
    final encoded = Uri.encodeComponent(objectPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
  }

  /// Resolves a display URL for a Storage object, or null if missing.
  static Future<String?> _resolveImageUrl(String objectPath) async {
    if (kIsWeb) {
      try {
        return await FirebaseStorage.instance.ref(objectPath).getDownloadURL();
      } catch (_) {
        return null;
      }
    }
    final url = publicMediaUrl(objectPath);
    if (!await storageObjectExistsAtUrl(url)) return null;
    return url;
  }

  /// Local web build fallback for `flutter run -d chrome` before Storage upload.
  static List<TopSliderSlide> _loadHostingFiles({required bool isArabic, required HeroSliderSize size}) {
    final folder = localeFolder(isArabic);
    final slides = <TopSliderSlide>[];

    for (final name in _slideNames) {
      slides.add(
        TopSliderSlide(
          id: '${name.toLowerCase()}_${size.name}_host',
          imageUrl: Uri.base.resolve('/topSlider/$folder/${size.folderName}/$name.jpg').toString(),
          category: TopSliderCategory.fromFileStem(name),
        ),
      );
    }

    slides.sort((a, b) => a.category.sortIndex.compareTo(b.category.sortIndex));
    return slides;
  }
}
