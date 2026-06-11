import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Records product detail views (session-deduped, +1 in Firestore).
class ProductViewService {
  ProductViewService._();
  static final ProductViewService instance = ProductViewService._();

  final _viewedThisSession = <String>{};

  Future<void> recordView(String docId) async {
    if (docId.isEmpty || !_viewedThisSession.add(docId)) return;

    try {
      await FirebaseFirestore.instance.collection('products').doc(docId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e, st) {
      debugPrint('ProductViewService.recordView failed: $e\n$st');
      _viewedThisSession.remove(docId);
    }
  }
}
