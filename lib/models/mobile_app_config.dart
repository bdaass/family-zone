import '../utils/app_version.dart';

/// Remote mobile release settings stored in Firestore `app_config/mobile`.
///
/// Firebase console → Firestore → `app_config` → document `mobile`:
/// ```json
/// {
///   "current_version": "1.0.0",
///   "force_update": false,
///   "android_store_url": "https://play.google.com/store/apps/details?id=com.familyzone.shop",
///   "ios_store_url": "https://apps.apple.com/app/idXXXXXXXXX"
/// }
/// ```
class MobileAppConfig {
  const MobileAppConfig({
    required this.currentVersion,
    required this.forceUpdate,
    this.androidStoreUrl,
    this.iosStoreUrl,
  });

  final String currentVersion;
  final bool forceUpdate;
  final String? androidStoreUrl;
  final String? iosStoreUrl;

  AppVersion get currentVersionParsed => AppVersion.parse(currentVersion);

  bool requiresForceUpdate(String installedVersion) {
    if (!forceUpdate) return false;
    return AppVersion.parse(installedVersion).isOlderThan(currentVersionParsed);
  }

  factory MobileAppConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return MobileAppConfig.fallback;
    final version = data['current_version'];
    return MobileAppConfig(
      currentVersion: version is String && version.trim().isNotEmpty ? version.trim() : '0.0.0',
      forceUpdate: data['force_update'] == true,
      androidStoreUrl: _optionalUrl(data['android_store_url']),
      iosStoreUrl: _optionalUrl(data['ios_store_url']),
    );
  }

  static String? _optionalUrl(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Used when the remote doc is missing or Firestore is unreachable.
  static const fallback = MobileAppConfig(currentVersion: '0.0.0', forceUpdate: false);
}
