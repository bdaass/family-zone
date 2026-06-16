import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_catalog.dart';
import 'product_image_service.dart';

class ProductWriteService {
  static Future<bool> productDocExists(String productId) async {
    final snap = await FirebaseFirestore.instance.collection('products').doc(productId).get();
    return snap.exists;
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
}
