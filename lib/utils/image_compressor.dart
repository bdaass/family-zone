import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'hero_image_processor.dart';
import 'hero_slider_settings.dart' show HeroSliderSize;
import 'product_image_settings.dart';

class ImageCompressor {
  /// Resizes and compresses raw image bytes before upload.
  /// Works on mobile and web via flutter_image_compress.
  static Future<Uint8List?> compressForUpload(Uint8List input) async {
    if (input.isEmpty) return null;

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        input,
        minWidth: ProductImageSettings.uploadMaxDimension,
        minHeight: ProductImageSettings.uploadMaxDimension,
        quality: ProductImageSettings.uploadQuality,
        format: CompressFormat.jpeg,
      );

      if (compressed.isEmpty) return null;
      return compressed;
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return null;
    }
  }

  /// Center-crops to the hero slot aspect ratio, then encodes JPEG.
  static Future<Uint8List?> compressForHeroUpload(Uint8List input, {required HeroSliderSize size}) async {
    return HeroImageProcessor.encodeForSlot(input, size: size);
  }
}
