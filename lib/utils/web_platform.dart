import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'web_platform_detect.dart' as detect;

/// Shared web tuning — same store on phone and desktop; phones load smaller pages.
class WebPlatform {
  WebPlatform._();

  static bool get isMobileWeb {
    if (!kIsWeb) return false;
    return detect.isMobileUserAgent;
  }

  /// iPhone/iPad Safari — heavy hero banners + PageView swipe often OOM-crash the tab.
  static bool get isIOSWeb {
    if (!kIsWeb) return false;
    return detect.isIOSUserAgent;
  }

  /// Full hero section (carousel + banners). Hidden on iPhone/iPad web.
  static bool get showDashboardHero => !isIOSWeb;

  static WebHtmlElementStrategy get networkImageStrategy {
    if (!kIsWeb) return WebHtmlElementStrategy.never;
    return WebHtmlElementStrategy.prefer;
  }

  static FilterQuality get networkImageQuality =>
      isMobileWeb ? FilterQuality.low : FilterQuality.medium;

  /// Fixed catalog page size — numbered pagination loads 18 products per page.
  static const int catalogPageSize = 18;

  static void configure() {
    if (!kIsWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    if (isIOSWeb) {
      cache.maximumSize = 40;
      cache.maximumSizeBytes = 28 << 20;
    } else if (isMobileWeb) {
      cache.maximumSize = 80;
      cache.maximumSizeBytes = 48 << 20;
    } else {
      cache.maximumSize = 200;
      cache.maximumSizeBytes = 128 << 20;
    }
  }

  /// Drop decoded images when scrolling on iPhone — same UI, less RAM buildup.
  static void trimImageCacheIfNeeded() {
    if (!isIOSWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    if (cache.currentSizeBytes > (20 << 20)) {
      cache.clearLiveImages();
    }
  }
}
