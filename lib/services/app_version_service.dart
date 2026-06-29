import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/store_config.dart';
import '../models/mobile_app_config.dart';

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.installedVersion,
    required this.config,
    required this.forceUpdateRequired,
    required this.storeUrl,
  });

  final String installedVersion;
  final MobileAppConfig config;
  final bool forceUpdateRequired;
  final String? storeUrl;
}

class AppVersionService {
  AppVersionService._();

  static final AppVersionService instance = AppVersionService._();

  static const _docPath = 'app_config/mobile';

  /// Skipped on web — force update applies to Android and iOS store builds only.
  bool get isSupportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<AppVersionCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;

    if (!isSupportedPlatform) {
      return AppVersionCheckResult(
        installedVersion: installedVersion,
        config: MobileAppConfig.fallback,
        forceUpdateRequired: false,
        storeUrl: null,
      );
    }

    MobileAppConfig config;
    try {
      final snap = await FirebaseFirestore.instance.doc(_docPath).get();
      config = MobileAppConfig.fromMap(snap.data());
    } catch (e, st) {
      debugPrint('AppVersionService: could not load $_docPath — $e\n$st');
      config = MobileAppConfig.fallback;
    }

    return AppVersionCheckResult(
      installedVersion: installedVersion,
      config: config,
      forceUpdateRequired: config.requiresForceUpdate(installedVersion),
      storeUrl: _storeUrlForPlatform(config),
    );
  }

  String? _storeUrlForPlatform(MobileAppConfig config) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return config.androidStoreUrl ?? StoreConfig.androidStoreUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return config.iosStoreUrl;
    }
    return null;
  }
}
