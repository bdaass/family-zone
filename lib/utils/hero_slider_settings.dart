/// Display and upload settings for the dashboard hero carousel.
class HeroSliderSettings {
  /// Fixed hero height on phones.
  static const double mobileDisplayHeight = 196;

  /// Fixed hero height on web / wide layouts.
  static const double webDisplayHeight = 220;

  /// JPEG quality for uploaded hero banners (0–100).
  static const int uploadQuality = 82;

  static int uploadMaxWidth(HeroSliderSize size) {
    switch (size) {
      case HeroSliderSize.mobile:
        return 900;
      case HeroSliderSize.web:
        return 1600;
    }
  }

  static int uploadMaxHeight(HeroSliderSize size) {
    switch (size) {
      case HeroSliderSize.mobile:
        return 500;
      case HeroSliderSize.web:
        return 400;
    }
  }

  static double displayHeight({required bool isWebWide}) {
    return isWebWide ? webDisplayHeight : mobileDisplayHeight;
  }

  static HeroSliderSize sizeForLayout({required bool isWebWide}) {
    return isWebWide ? HeroSliderSize.web : HeroSliderSize.mobile;
  }
}

/// Device-specific hero banner variant stored under `topSlider/{locale}/{folder}/`.
enum HeroSliderSize {
  mobile('mobile'),
  web('web');

  const HeroSliderSize(this.folderName);

  final String folderName;
}
