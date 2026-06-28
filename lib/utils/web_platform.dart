import 'package:flutter/foundation.dart';

/// Web-only helpers for tuning memory and behavior on phone browsers.
class WebPlatform {
  WebPlatform._();

  static bool get isMobileWeb {
    if (!kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      default:
        return false;
    }
  }
}
