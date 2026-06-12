import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'hero_slider_settings.dart';

/// Center-crops and resizes hero banners to the exact slot aspect ratio (no stretch).
class HeroImageProcessor {
  static Uint8List? encodeForSlot(Uint8List input, {required HeroSliderSize size}) {
    if (input.isEmpty) return null;

    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return null;

      final targetW = HeroSliderSettings.uploadMaxWidth(size);
      final targetH = HeroSliderSettings.uploadMaxHeight(size);
      final cropped = _centerCropToAspect(decoded, targetW / targetH);
      final resized = img.copyResize(cropped, width: targetW, height: targetH, interpolation: img.Interpolation.linear);
      return Uint8List.fromList(img.encodeJpg(resized, quality: HeroSliderSettings.uploadQuality));
    } catch (e, st) {
      debugPrint('HeroImageProcessor: $e\n$st');
      return null;
    }
  }

  static img.Image _centerCropToAspect(img.Image source, double targetAspect) {
    final srcAspect = source.width / source.height;

    int cropW, cropH, left, top;
    if (srcAspect > targetAspect) {
      cropH = source.height;
      cropW = (source.height * targetAspect).round();
      left = ((source.width - cropW) / 2).round();
      top = 0;
    } else {
      cropW = source.width;
      cropH = (source.width / targetAspect).round();
      left = 0;
      top = ((source.height - cropH) / 2).round();
    }

    return img.copyCrop(source, x: left, y: top, width: cropW, height: cropH);
  }
}
