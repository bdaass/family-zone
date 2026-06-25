/// Shared settings for product image upload and display.
class ProductImageSettings {
  /// Max width/height stored in Firebase Storage (keeps files small).
  static const int uploadMaxDimension = 800;

  /// JPEG quality for uploaded product photos (0–100).
  static const int uploadQuality = 75;

  /// Decode cache size for grid thumbnails (260px cell × 2 for retina).
  static const int displayCacheSize = 520;

  /// Catalog card image width:height (1:1 — compact grid thumbnails).
  static const double catalogImageAspectRatio = 1;

  /// Minimum footer space for title, sizes, colors, and the add-to-cart button.
  static const double catalogCardFooterMinHeight = 168;

  /// Grid [childAspectRatio] (width / height) sized for image + footer content.
  static double catalogGridAspectRatio(double cardWidth) {
    final imageHeight = cardWidth / catalogImageAspectRatio;
    return cardWidth / (imageHeight + catalogCardFooterMinHeight);
  }

  static double catalogGridAspectRatioForLayout({required bool isWide}) {
    return catalogGridAspectRatio(isWide ? 280 : 220);
  }

  /// Decode cache size for product detail / zoom view.
  static const int detailCacheSize = 1200;
}
