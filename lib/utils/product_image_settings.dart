import 'web_platform.dart';

/// Shared settings for product image upload and display.
class ProductImageSettings {
  /// Max width/height stored in Firebase Storage (keeps files small).
  static const int uploadMaxDimension = 800;

  /// JPEG quality for uploaded product photos (0–100).
  static const int uploadQuality = 75;

  /// Decode cache size for grid thumbnails (cell width × ~2 for retina).
  static int get displayCacheSize {
    if (WebPlatform.isIOSWeb) return 160;
    if (WebPlatform.isMobileWeb) return 360;
    return 520;
  }

  /// Catalog card image width:height (1:1 — compact grid thumbnails).
  static const double catalogImageAspectRatio = 1;

  /// Minimum footer space for title, sizes, colors, and the add-to-cart button.
  static const double catalogCardFooterMinHeight = 152;

  /// Space between variant info and the add-to-cart button in catalog cards.
  static const double catalogAddToCartTopSpacing = 8;

  /// Bottom inset below the add-to-cart button in catalog cards.
  static const double catalogCardFooterBottomPadding = 16;

  /// Grid [childAspectRatio] (width / height) sized for image + footer content.
  static double catalogGridAspectRatio(double cardWidth) {
    final imageHeight = cardWidth / catalogImageAspectRatio;
    return cardWidth / (imageHeight + catalogCardFooterMinHeight);
  }

  static double catalogGridAspectRatioForLayout({required bool isWide}) {
    // Cells are often narrower than maxCrossAxisExtent on small screens — size for a
    // conservative minimum width so the card footer (title, sizes, add-to-cart) fits.
    final minCardWidth = isWide ? 200.0 : 160.0;
    return catalogGridAspectRatio(minCardWidth);
  }

  /// Decode cache size for product detail / zoom view.
  static int get detailCacheSize {
    if (WebPlatform.isIOSWeb) return 420;
    if (WebPlatform.isMobileWeb) return 900;
    return 1200;
  }
}
