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

  /// iPhone/iPad Safari and iOS Chrome (all use WebKit) — tight memory limits.
  static bool get isIOSWeb {
    if (!kIsWeb) return false;
    return detect.isIOSUserAgent;
  }

  /// Trim animations, shadows, and image work on iOS web.
  static bool get useLiteUi => isIOSWeb;

  /// Microsoft Edge and Firefox on skwasm — HTML img overlays often fail to load Storage URLs.
  static bool get needsCanvasNetworkImages {
    if (!kIsWeb) return false;
    return detect.isEdgeUserAgent || detect.isGeckoUserAgent;
  }

  /// Full hero section (carousel + banners). Hidden on iPhone/iPad web.
  static bool get showDashboardHero => !isIOSWeb;

  static WebHtmlElementStrategy get networkImageStrategy {
    if (!kIsWeb) return WebHtmlElementStrategy.never;
    if (needsCanvasNetworkImages) return WebHtmlElementStrategy.never;
    return WebHtmlElementStrategy.prefer;
  }

  static FilterQuality get networkImageQuality =>
      isIOSWeb ? FilterQuality.low : (isMobileWeb ? FilterQuality.low : FilterQuality.medium);

  /// iOS Safari: 6 products per page to stay under WebKit memory limits.
  static int get catalogPageSize => isIOSWeb ? 6 : 18;

  static void configure() {
    if (!kIsWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    if (isIOSWeb) {
      cache.maximumSize = 12;
      cache.maximumSizeBytes = 10 << 20;
    } else if (isMobileWeb) {
      cache.maximumSize = 80;
      cache.maximumSizeBytes = 48 << 20;
    } else {
      cache.maximumSize = 200;
      cache.maximumSizeBytes = 128 << 20;
    }
  }

  static void trimImageCacheIfNeeded() {
    if (!isIOSWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    if (cache.currentSizeBytes > (6 << 20) || cache.currentSize > 8) {
      cache.clearLiveImages();
    }
  }

  static void onCatalogPageLoadStart() {
    if (!isIOSWeb) return;
    clearImageCache();
  }

  static void onCatalogPageLoadComplete() {
    if (!isIOSWeb) return;
    trimImageCacheIfNeeded();
  }

  static void onHeavyViewClosed() {
    if (!isIOSWeb) return;
    clearImageCache();
  }

  static void clearImageCache() {
    if (!isIOSWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    cache.clearLiveImages();
    cache.clear();
  }
}
