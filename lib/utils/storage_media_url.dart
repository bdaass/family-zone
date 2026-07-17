import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase Storage URLs for public product photos (no auth token required).
class StorageMediaUrl {
  StorageMediaUrl._();

  static const _host = 'firebasestorage.googleapis.com';

  static String? objectPathFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('/media/')) {
      try {
        final decoded = Uri.decodeComponent(trimmed.substring('/media/'.length));
        return decoded.isEmpty ? null : decoded;
      } catch (_) {
        return null;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.host.contains(_host)) return null;

    final segments = uri.pathSegments;
    final oIndex = segments.indexOf('o');
    if (oIndex < 0 || oIndex + 1 >= segments.length) return null;

    final encodedPath = segments.sublist(oIndex + 1).join('/');
    return Uri.decodeComponent(encodedPath);
  }

  static String publicMediaUrl(String objectPath) {
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket!;
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(objectPath)}?alt=media';
  }

  /// Web-only: load via Firebase Hosting `/media/...` (same origin as the shop).
  static String sameOriginMediaUrl(String objectPath) {
    final segments = objectPath.split('/').where((segment) => segment.isNotEmpty);
    return '/media/${segments.map(Uri.encodeComponent).join('/')}';
  }

  static bool isPublicProductPhotoPath(String objectPath) {
    if (objectPath.startsWith('product_images/')) {
      return !objectPath.endsWith('/barcode.jpg') && !objectPath.endsWith('barcode.jpg');
    }
    return false;
  }

  static bool isStaffBarcodePath(String objectPath) {
    return objectPath.startsWith('product_images/') &&
        (objectPath.endsWith('/barcode.jpg') || objectPath.endsWith('barcode.jpg'));
  }

  /// Staff barcode photos — same-origin on web with auth header (admin/employee only).
  static String displayStaffUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final objectPath = objectPathFromUrl(trimmed);
    if (objectPath == null || !isStaffBarcodePath(objectPath)) {
      return trimmed;
    }

    if (kIsWeb) {
      return Uri.base.resolve(sameOriginMediaUrl(objectPath)).toString();
    }
    return publicMediaUrl(objectPath);
  }

  /// URL used in widgets — same-origin on web so Chrome profiles/extensions cannot block Storage.
  static String displayUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final objectPath = objectPathFromUrl(trimmed);
    if (objectPath == null || !isPublicProductPhotoPath(objectPath)) {
      return trimmed;
    }

    if (kIsWeb) {
      return Uri.base.resolve(sameOriginMediaUrl(objectPath)).toString();
    }
    return publicMediaUrl(objectPath);
  }

  /// Drop expired download tokens — product photos are world-readable in storage.rules.
  static String normalizePublic(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final objectPath = objectPathFromUrl(trimmed);
    if (objectPath == null || !isPublicProductPhotoPath(objectPath)) {
      return trimmed;
    }
    return publicMediaUrl(objectPath);
  }
}
