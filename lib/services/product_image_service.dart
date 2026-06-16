import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Product photo + barcode upload paths under `product_images/{productId}/`.
class ProductImageUpdate {
  final List<String> keptImageUrls;
  final List<String> removedImageUrls;
  final List<Uint8List> newImages;
  final Uint8List? newBarcodeImage;
  final bool hadBarcode;

  const ProductImageUpdate({
    required this.keptImageUrls,
    this.removedImageUrls = const [],
    this.newImages = const [],
    this.newBarcodeImage,
    this.hadBarcode = false,
  });
}

class ProductImageService {
  static String productImagePath(String productId, int index) =>
      'product_images/$productId/$index.jpg';

  static String barcodeImagePath(String productId) => 'product_images/$productId/barcode.jpg';

  static String legacyImagePath(String productId) => 'product_images/$productId.jpg';

  static Future<List<String>> uploadProductImages({
    required String productId,
    required List<Uint8List> images,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(productImagePath(productId, i));
      await ref.putData(images[i], SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  static Future<String> uploadBarcodeImage({
    required String productId,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(barcodeImagePath(productId));
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<({List<String> imageUrls, String barcodeUrl})> uploadNewProductImages({
    required String productId,
    required List<Uint8List> productImages,
    required Uint8List barcodeImage,
  }) async {
    final imageUrls = await uploadProductImages(productId: productId, images: productImages);
    final barcodeUrl = await uploadBarcodeImage(productId: productId, bytes: barcodeImage);
    return (imageUrls: imageUrls, barcodeUrl: barcodeUrl);
  }

  static Future<({List<String> imageUrls, String? barcodeUrl})> applyImageUpdate({
    required String productId,
    required ProductImageUpdate update,
  }) async {
    for (final url in update.removedImageUrls) {
      await _deleteUrl(url);
    }

    final urls = List<String>.from(update.keptImageUrls);
    var nextIndex = urls.length;
    for (final bytes in update.newImages) {
      final ref = FirebaseStorage.instance.ref().child(productImagePath(productId, nextIndex));
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
      nextIndex++;
    }

    String? barcodeUrl;
    if (update.newBarcodeImage != null) {
      barcodeUrl = await uploadBarcodeImage(productId: productId, bytes: update.newBarcodeImage!);
    }

    return (imageUrls: urls, barcodeUrl: barcodeUrl);
  }

  static Future<void> deleteAllForProduct(
    String productId, {
    List<String> imageUrls = const [],
    String? barcodeImageUrl,
  }) async {
    for (final url in imageUrls) {
      await _deleteUrl(url);
    }
    if (barcodeImageUrl != null) {
      await _deleteUrl(barcodeImageUrl);
    }

    try {
      final folder = FirebaseStorage.instance.ref().child('product_images/$productId');
      final list = await folder.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (e, st) {
      debugPrint('ProductImageService: folder delete skipped: $e\n$st');
    }

    try {
      await FirebaseStorage.instance.ref().child(legacyImagePath(productId)).delete();
    } catch (_) {}
  }

  static Future<({List<String> imageUrls, String? barcodeUrl})> copyOnProductIdChange({
    required String oldId,
    required String newId,
    required List<String> imageUrls,
    String? barcodeImageUrl,
  }) async {
    final newProductUrls = <String>[];
    for (var i = 0; i < imageUrls.length; i++) {
      final bytes = await _downloadUrl(imageUrls[i]);
      if (bytes == null) continue;
      final ref = FirebaseStorage.instance.ref().child(productImagePath(newId, i));
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      newProductUrls.add(await ref.getDownloadURL());
    }

    String? newBarcodeUrl;
    if (barcodeImageUrl != null) {
      final bytes = await _downloadUrl(barcodeImageUrl);
      if (bytes != null) {
        newBarcodeUrl = await uploadBarcodeImage(productId: newId, bytes: bytes);
      }
    }

    if (newProductUrls.isEmpty) {
      final legacyBytes = await _downloadRef(legacyImagePath(oldId));
      if (legacyBytes != null) {
        final ref = FirebaseStorage.instance.ref().child(productImagePath(newId, 0));
        await ref.putData(legacyBytes, SettableMetadata(contentType: 'image/jpeg'));
        newProductUrls.add(await ref.getDownloadURL());
      }
    }

    return (imageUrls: newProductUrls, barcodeUrl: newBarcodeUrl);
  }

  static Future<void> _deleteUrl(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e, st) {
      debugPrint('ProductImageService: delete url skipped: $e\n$st');
    }
  }

  static Future<Uint8List?> _downloadUrl(String url) async {
    try {
      return await FirebaseStorage.instance.refFromURL(url).getData();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _downloadRef(String path) async {
    try {
      return await FirebaseStorage.instance.ref().child(path).getData();
    } catch (_) {
      return null;
    }
  }
}
