import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_catalog.dart';

/// One-time fixes for legacy Firestore product documents (admin only).
class CatalogMigrationService {
  static Future<({int updated, int skipped, int total})> normalizeLegacyProducts() async {
    final snap = await FirebaseFirestore.instance.collection('products').get();
    var updated = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final patch = _legacyPatchFor(data);
      if (patch.isEmpty) continue;

      try {
        await doc.reference.update(patch);
        updated++;
      } catch (e, st) {
        debugPrint('CatalogMigrationService: ${doc.id} failed: $e\n$st');
      }
    }

    return (updated: updated, skipped: snap.docs.length - updated, total: snap.docs.length);
  }

  /// Writes [effectivePrice] on every product so price-ascending catalog sort works.
  static Future<({int updated, int total})> backfillEffectivePrices() async {
    final snap = await FirebaseFirestore.instance.collection('products').get();
    var updated = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final expected = ProductCatalog.effectivePrice(data);
      final current = data['effectivePrice'];
      final needsUpdate = current == null ||
          (current is num && (current.toDouble() - expected).abs() > 0.001);
      if (!needsUpdate) continue;

      try {
        await doc.reference.update({'effectivePrice': expected});
        updated++;
      } catch (e, st) {
        debugPrint('CatalogMigrationService backfillEffectivePrices: ${doc.id} failed: $e\n$st');
      }
    }

    return (updated: updated, total: snap.docs.length);
  }

  /// Clears legacy size/color/stock fields so staff can re-enter per-branch variant inventory.
  static Future<({int updated, int total})> resetAllProductInventory() async {
    final snap = await FirebaseFirestore.instance.collection('products').get();
    var updated = 0;

    for (final doc in snap.docs) {
      try {
        await doc.reference.update(inventoryResetPatch());
        updated++;
      } catch (e, st) {
        debugPrint('CatalogMigrationService reset inventory: ${doc.id} failed: $e\n$st');
      }
    }

    return (updated: updated, total: snap.docs.length);
  }

  static Map<String, dynamic> inventoryResetPatch() => {
        'size': FieldValue.delete(),
        'colors': FieldValue.delete(),
        'branchStock': FieldValue.delete(),
        'variantInventory': <String, dynamic>{},
        'stockQty': 0,
      };

  static Map<String, dynamic> legacyPatchFor(Map<String, dynamic> data) => _legacyPatchFor(data);

  static Map<String, dynamic> _legacyPatchFor(Map<String, dynamic> data) {
    final patch = <String, dynamic>{};

    final urls = data['imageUrls'];
    final hasImageUrls = urls is List && urls.where((e) => e.toString().trim().isNotEmpty).isNotEmpty;
    if (!hasImageUrls) {
      final primary = ProductCatalog.primaryImageUrl(data);
      if (primary.isNotEmpty) {
        patch['imageUrls'] = [primary];
        patch['imageUrl'] = primary;
      }
    }

    final expected = ProductCatalog.effectivePrice(data);
    final current = data['effectivePrice'];
    if (current == null || (current is num && (current.toDouble() - expected).abs() > 0.001)) {
      patch['effectivePrice'] = expected;
    }

    return patch;
  }
}
