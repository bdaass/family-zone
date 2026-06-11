import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/product_catalog.dart';

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

    final merged = {...oldSnap.data()!, ...updates, 'productId': trimmedId};
    String? imageUrl = merged['imageUrl']?.toString();

    try {
      final storageRef = FirebaseStorage.instance.ref().child('product_images/$docId.jpg');
      final bytes = await storageRef.getData();
      if (bytes != null) {
        final newStorageRef = FirebaseStorage.instance.ref().child('product_images/$trimmedId.jpg');
        await newStorageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await newStorageRef.getDownloadURL();
        merged['imageUrl'] = imageUrl;
      }
    } catch (e, st) {
      debugPrint('ProductWriteService: image copy skipped: $e\n$st');
    }

    await FirebaseFirestore.instance.collection('products').doc(trimmedId).set(merged);
    await oldRef.update({'visibility': false, 'supersededBy': trimmedId});
  }
}
