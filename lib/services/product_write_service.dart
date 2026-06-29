import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/product_catalog.dart';
import 'product_image_service.dart';

class ProductWriteService {
  static Future<bool> productDocExists(String productId) async {
    final trimmed = productId.trim();
    if (trimmed.isEmpty) return false;

    try {
      final snap = await FirebaseFirestore.instance.collection('products').doc(trimmed).get();
      return snap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('productDocExists: permission denied for $trimmed — treating as available');
        return false;
      }
      rethrow;
    }
  }

  static Future<void> updateProduct({
    required String docId,
    required Map<String, dynamic> updates,
    String? newProductId,
  }) async {
    final trimmedId = newProductId?.trim();
    if (trimmedId == null || trimmedId == docId) {
      await FirebaseFirestore.instance.collection('products').doc(docId).update(updates);
      return;
    }

    if (!ProductCatalog.isValidProductId(trimmedId)) {
      throw ArgumentError('invalid_product_id');
    }
    if (await productDocExists(trimmedId)) {
      throw StateError('product_id_taken');
    }

    final oldRef = FirebaseFirestore.instance.collection('products').doc(docId);
    final oldSnap = await oldRef.get();
    if (!oldSnap.exists) throw StateError('product_not_found');

    final oldData = oldSnap.data()!;
    final merged = {...oldData, ...updates, 'productId': trimmedId};

    try {
      final copied = await ProductImageService.copyOnProductIdChange(
        oldId: docId,
        newId: trimmedId,
        imageUrls: ProductCatalog.productImageUrlsFrom(merged),
        barcodeImageUrl: ProductCatalog.barcodeImageUrlFrom(merged),
      );
      if (copied.imageUrls.isNotEmpty || copied.barcodeUrl != null) {
        merged.addAll(ProductCatalog.imageFieldsForWrite(
          imageUrls: copied.imageUrls,
          barcodeImageUrl: copied.barcodeUrl,
        ));
      }
    } catch (e, st) {
      debugPrint('ProductWriteService: image copy skipped: $e\n$st');
    }

    await FirebaseFirestore.instance.collection('products').doc(trimmedId).set(merged);
    await oldRef.update({'visibility': false, 'supersededBy': trimmedId});
  }

  static Future<void> updateStaffNotes({
    required String docId,
    required String staffNotes,
  }) async {
    await FirebaseFirestore.instance.collection('products').doc(docId).update({
      'staffNotes': staffNotes,
    });
  }

  /// True when [proposed] changes catalog fields compared with [current] (excluding staff notes).
  static bool hasCatalogFieldChanges({
    required Map<String, dynamic> proposed,
    required Map<String, dynamic> current,
    required String docId,
    bool imagesChanged = false,
  }) {
    if (imagesChanged) return true;

    final audience = ProductCatalog.audienceFrom(current);
    if ((proposed['title'] ?? '').toString().trim() != ProductCatalog.titleFrom(current)) return true;
    if ((proposed['description'] ?? '').toString().trim() != ProductCatalog.descriptionFrom(current)) {
      return true;
    }

    final proposedPrice = proposed['price'];
    final price = proposedPrice is num
        ? proposedPrice.toDouble()
        : double.tryParse(proposedPrice?.toString() ?? '') ?? ProductCatalog.priceFrom(current);
    if ((price - ProductCatalog.priceFrom(current)).abs() > 0.001) return true;

    if ((proposed['season'] ?? '').toString() != (current['season'] ?? 'summer').toString()) return true;
    if ((proposed['ageGroup'] ?? '').toString() != audience.ageGroup) return true;
    if ((proposed['sex'] ?? '').toString() != audience.sex) return true;
    if (ProductCatalog.normalizeType((proposed['type'] ?? '').toString()) !=
        ProductCatalog.normalizeType(current['type']?.toString())) {
      return true;
    }

    if ((proposed['size'] ?? '').toString() != ProductCatalog.sizeFrom(current)) return true;
    if ((proposed['colors'] ?? '').toString() != ProductCatalog.colorsFrom(current)) return true;

    final proposedSold = proposed['soldPrice'];
    final currentSold = ProductCatalog.soldPriceFrom(current);
    final parsedSold = proposedSold is num
        ? proposedSold.toDouble()
        : double.tryParse(proposedSold?.toString() ?? '');
    if (parsedSold == null && currentSold != null) return true;
    if (parsedSold != null && currentSold == null) return true;
    if (parsedSold != null && currentSold != null && (parsedSold - currentSold).abs() > 0.001) {
      return true;
    }

    final proposedDiscount = proposed['discountPercent'];
    final currentDiscount = ProductCatalog.discountPercentFrom(current);
    final parsedDiscount = proposedDiscount is int
        ? proposedDiscount
        : int.tryParse(proposedDiscount?.toString() ?? '');
    if (parsedDiscount != currentDiscount) return true;

    final proposedInventory = proposed['variantInventory'];
    if (proposedInventory is Map) {
      final currentInventory = ProductCatalog.variantInventoryFrom(current);
      if (proposedInventory.toString() != currentInventory.toString()) return true;
    }

    return false;
  }

  /// Stores proposed changes for admin review without changing the live catalog entry.
  static Future<void> submitPendingEdit({
    required String docId,
    required Map<String, dynamic> proposed,
    String? newProductId,
  }) async {
    final trimmedId = (newProductId ?? proposed['productId'] as String?)?.trim();
    if (trimmedId != null && trimmedId != docId) {
      if (!ProductCatalog.isValidProductId(trimmedId)) {
        throw ArgumentError('invalid_product_id');
      }
      if (await productDocExists(trimmedId)) {
        throw StateError('product_id_taken');
      }
    }

    final pending = _pendingPayloadFrom(proposed);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance.collection('products').doc(docId).update({
      'pendingEdit': pending,
      'editPending': true,
      'needsApproval': true,
      'pendingEditAt': FieldValue.serverTimestamp(),
      if (uid != null) 'pendingEditBy': uid,
    });
  }

  /// Applies pending changes or publishes a new item after admin approval.
  static Future<void> approveProduct(String docId) async {
    final ref = FirebaseFirestore.instance.collection('products').doc(docId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('product_not_found');

    final data = snap.data()!;
    final pending = ProductCatalog.pendingEditFrom(data);

    if (pending != null && pending.isNotEmpty) {
      final removedUrls = pending.remove('pendingImageRemovedUrls');
      final patch = <String, dynamic>{};
      for (final entry in pending.entries) {
        patch[entry.key] = entry.value ?? FieldValue.delete();
      }
      patch['pendingEdit'] = FieldValue.delete();
      patch['editPending'] = false;
      patch['needsApproval'] = false;
      patch['approved'] = true;
      patch['visibility'] = true;
      patch['pendingEditAt'] = FieldValue.delete();
      patch['pendingEditBy'] = FieldValue.delete();
      await ref.update(patch);
      if (removedUrls is List) {
        await ProductImageService.deleteUrls(
          removedUrls.map((url) => url.toString()).where((url) => url.isNotEmpty),
        );
      }
      return;
    }

    await ref.update({
      'approved': true,
      'visibility': true,
      'needsApproval': false,
      'editPending': false,
    });
  }

  /// Rejects a pending edit or removes an unpublished new item.
  static Future<void> declineProduct(String docId) async {
    final ref = FirebaseFirestore.instance.collection('products').doc(docId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('product_not_found');

    final data = snap.data()!;
    if (ProductCatalog.hasPendingEdit(data)) {
      await ref.update({
        'pendingEdit': FieldValue.delete(),
        'editPending': false,
        'needsApproval': false,
        'pendingEditAt': FieldValue.delete(),
        'pendingEditBy': FieldValue.delete(),
      });
      return;
    }

    await ProductImageService.deleteAllForProduct(
      docId,
      imageUrls: ProductCatalog.productImageUrlsFrom(data),
      barcodeImageUrl: ProductCatalog.barcodeImageUrlFrom(data),
    );
    await ref.delete();
  }

  static Map<String, dynamic> _pendingPayloadFrom(Map<String, dynamic> proposed) {
    final pending = <String, dynamic>{};
    for (final entry in proposed.entries) {
      if (entry.key.startsWith('_')) continue;
      final value = entry.value;
      if (value is FieldValue) {
        pending[entry.key] = null;
        continue;
      }
      pending[entry.key] = value;
    }
    return pending;
  }
}
