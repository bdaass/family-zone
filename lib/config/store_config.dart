/// Store contact settings — update links and details for your shop.
class StoreConfig {
  static const storeName = 'Family Zone';

  /// Public web shop URL (Firebase Hosting). Used for share links.
  static const webBaseUrl = 'https://family-zone-2026.web.app';

  /// Country code + number, digits only (no + or spaces). +961 76 376 228
  static const whatsappNumber = '96176376228';
  static const storeDisplayNumber = '+961 76 376 228';
  static const storeEmail = 'fazone2026@gmail.com';

  static const facebookUrl = 'https://www.facebook.com/familyzonelb/';
  static const instagramUrl = 'https://www.instagram.com/familyzone.lb/';

  /// Play Store listing (update when the Android app is published).
  static const androidApplicationId = 'com.familyzone.shop';

  /// iOS bundle id — set `ios_store_url` in Firestore when the App Store link is known.
  static const iosBundleId = 'com.familyzone.shop';

  static String get androidStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidApplicationId';

  static const workingHoursEn = '8 AM – 9 PM, every day';
  static const workingHoursAr = '٨ صباحاً – ٩ مساءً، كل الأيام';

  static const locations = [
    StoreLocation(
      id: 'tripoli',
      labelAr: 'طرابلس بجانب مسجد السلام',
      labelEn: 'Tripoli',
      mapsUrl: 'https://maps.app.goo.gl/VZG34D717FK9KT4d6',
    ),
    StoreLocation(
      id: 'elminieh',
      labelAr: 'المنية فوق نفق بحنين',
      labelEn: 'El Minieh',
      mapsUrl: 'https://maps.app.goo.gl/Ga59KbHmS6Ruruik7',
    ),
    StoreLocation(
      id: 'halba',
      labelAr: 'حلبا',
      labelEn: 'Halba',
      mapsUrl: 'https://maps.app.goo.gl/nTVQXUtZehcL6RfD8',
    ),
  ];

  static StoreLocation branchById(String id) {
    return locations.firstWhere(
      (b) => b.id == id,
      orElse: () => locations.first,
    );
  }

  static String branchLabel(String id, {required bool isArabic}) {
    final branch = branchById(id);
    return isArabic ? branch.labelAr : branch.labelEn;
  }
}

class StoreLocation {
  final String id;
  final String labelAr;
  final String labelEn;
  final String mapsUrl;

  const StoreLocation({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.mapsUrl,
  });
}
