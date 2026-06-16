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

    final branchStock = data['branchStock'];
    final hasBranchStock = branchStock is Map && branchStock.isNotEmpty;
    if (!hasBranchStock) {
      final legacyQty = data['stockQty'];
      if (legacyQty != null) {
        final qty = ProductCatalog.stockQtyFrom(data);
        if (qty != null) {
          patch['branchStock'] = {'tripoli': qty};
          patch['stockQty'] = qty;
        }
      }
    }

    return patch;
  }
}
