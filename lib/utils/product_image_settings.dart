/// Shared settings for product image upload and display.
class ProductImageSettings {
  /// Max width/height stored in Firebase Storage (keeps files small).
  static const int uploadMaxDimension = 800;

  /// JPEG quality for uploaded product photos (0–100).
  static const int uploadQuality = 75;

  /// Decode cache size for grid thumbnails (260px cell × 2 for retina).
  static const int displayCacheSize = 520;

  /// Decode cache size for product detail / zoom view.
  static const int detailCacheSize = 1200;
}
