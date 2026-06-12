/// Display and upload settings for the dashboard hero carousel.
class HeroSliderSettings {
  /// Viewport width at or above this uses wide banners (matches dashboard `isWide`).
  static const double wideLayoutBreakpoint = 600;

  /// Fixed hero height on narrow viewports.
  static const double mobileDisplayHeight = 196;

  /// Fixed hero height on wide viewports.
  static const double webDisplayHeight = 220;

  /// Reference layout width used to derive wide-banner aspect ratio.
  static const double wideReferenceWidth = 1200;

  /// JPEG quality for uploaded hero banners (0–100).
  static const int uploadQuality = 82;

  /// Narrow slot ~2:1 (e.g. 390×196).
  static const int mobileUploadWidth = 1000;
  static const int mobileUploadHeight = 500;

  /// Wide slot ~5.45:1 (e.g. 1200×220).
  static const int webUploadWidth = 2400;
  static const int webUploadHeight = 440;

  static double targetAspectRatio(HeroSliderSize size) {
    switch (size) {
      case HeroSliderSize.mobile:
        return mobileUploadWidth / mobileUploadHeight;
      case HeroSliderSize.web:
        return webUploadWidth / webUploadHeight;
    }
  }

  static int uploadMaxWidth(HeroSliderSize size) {
    switch (size) {
      case HeroSliderSize.mobile:
        return mobileUploadWidth;
      case HeroSliderSize.web:
        return webUploadWidth;
    }
  }

  static int uploadMaxHeight(HeroSliderSize size) {
    switch (size) {
      case HeroSliderSize.mobile:
        return mobileUploadHeight;
      case HeroSliderSize.web:
        return webUploadHeight;
    }
  }

  static double displayHeight({required bool isWideLayout}) {
    return isWideLayout ? webDisplayHeight : mobileDisplayHeight;
  }

  static HeroSliderSize sizeForLayout({required bool isWideLayout}) {
    return isWideLayout ? HeroSliderSize.web : HeroSliderSize.mobile;
  }
}

/// Viewport-specific hero banner variant stored under `topSlider/{locale}/{folder}/`.
enum HeroSliderSize {
  mobile('mobile'),
  web('web');

  const HeroSliderSize(this.folderName);

  final String folderName;
}
