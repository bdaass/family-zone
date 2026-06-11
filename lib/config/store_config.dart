/// Store contact settings — update links and details for your shop.
class StoreConfig {
  static const storeName = 'Family Zone';

  /// Country code + number, digits only (no + or spaces). +961 76 376 228
  static const whatsappNumber = '96176376228';
  static const storeDisplayNumber = '+961 76 376 228';
  static const storeEmail = 'fazone2026@gmail.com';

  static const facebookUrl = 'https://www.facebook.com/familyzonelb/';
  static const instagramUrl = 'https://www.instagram.com/familyzone.lb/';
  static const mapsUrl = 'https://maps.app.goo.gl/VZG34D717FK9KT4d6';

  static const workingHoursEn = '8 AM – 9 PM, every day';
  static const workingHoursAr = '٨ صباحاً – ٩ مساءً، كل الأيام';

  static const locations = [
    StoreLocation(
      labelAr: 'طرابلس بجانب مسجد السلام',
      labelEn: 'Tripoli, next to Al-Salam Mosque',
    ),
  ];
}

class StoreLocation {
  final String labelAr;
  final String labelEn;

  const StoreLocation({required this.labelAr, required this.labelEn});
}
