import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  static int _countFrom(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final raw = data['favoriteCount'] ?? data['favorites'] ?? 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  /// Toggle favorite for the signed-in user. Updates [likedProducts] and [favoriteCount].
  static Future<bool> toggle(String productDocId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final productRef = FirebaseFirestore.instance.collection('products').doc(productDocId);

    var nowLiked = false;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final productSnap = await tx.get(productRef);

      final liked = List<String>.from(userSnap.data()?['likedProducts'] ?? []);
      final alreadyLiked = liked.contains(productDocId);
      final currentCount = _countFrom(productSnap.data());

      if (alreadyLiked) {
        liked.remove(productDocId);
        tx.update(productRef, {'favoriteCount': currentCount > 0 ? currentCount - 1 : 0});
        nowLiked = false;
      } else {
        liked.add(productDocId);
        tx.update(productRef, {'favoriteCount': currentCount + 1});
        nowLiked = true;
      }

      tx.set(userRef, {'likedProducts': liked}, SetOptions(merge: true));
    });

    return nowLiked;
  }

  /// Fetch product documents for the given document IDs (batched for Firestore limits).
  static Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final unique = ids.toSet().toList();
    final results = <DocumentSnapshot<Map<String, dynamic>>>[];

    for (var i = 0; i < unique.length; i += 10) {
      final chunk = unique.sublist(i, i + 10 > unique.length ? unique.length : i + 10);
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs);
    }

    final order = {for (var i = 0; i < unique.length; i++) unique[i]: i};
    results.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return results;
  }
}
