import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_catalog.dart';

class StaffProductInsight {
  final String docId;
  final String productId;
  final String title;
  final int viewCount;
  final int favoriteCount;
  final int? stockQty;
  final bool sold;

  const StaffProductInsight({
    required this.docId,
    required this.productId,
    required this.title,
    required this.viewCount,
    required this.favoriteCount,
    this.stockQty,
    this.sold = false,
  });

  factory StaffProductInsight.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StaffProductInsight(
      docId: doc.id,
      productId: ProductCatalog.productIdFrom(data, doc.id),
      title: ProductCatalog.titleFrom(data),
      viewCount: ProductCatalog.viewCountFrom(data),
      favoriteCount: ProductCatalog.favoriteCountFrom(data),
      stockQty: ProductCatalog.stockQtyFrom(data),
      sold: data['sold'] == true,
    );
  }
}

class StaffInsightsSnapshot {
  final List<StaffProductInsight> topViewed;
  final List<StaffProductInsight> topFavorited;
  final List<StaffProductInsight> lowStock;
  final int pendingApprovalCount;

  const StaffInsightsSnapshot({
    required this.topViewed,
    required this.topFavorited,
    required this.lowStock,
    required this.pendingApprovalCount,
  });
}

/// Staff-only analytics and approval counts.
class StaffInsightsService {
  StaffInsightsService._();

  static Future<StaffInsightsSnapshot> fetch() async {
    final products = FirebaseFirestore.instance.collection('products');

    final results = await Future.wait([
      products.orderBy('viewCount', descending: true).limit(10).get(),
      products.orderBy('favoriteCount', descending: true).limit(10).get(),
      products.where('approved', isEqualTo: false).count().get(),
      products.where('stockQty', isLessThanOrEqualTo: ProductCatalog.lowStockThreshold).limit(50).get(),
      products.where('sold', isEqualTo: true).limit(15).get(),
    ]);

    final topViewedSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final topFavoritedSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final pendingCountSnap = results[2] as AggregateQuerySnapshot;
    final lowQtySnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final soldOutSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;

    final lowStockById = <String, StaffProductInsight>{};
    for (final doc in [...lowQtySnap.docs, ...soldOutSnap.docs]) {
      lowStockById[doc.id] = StaffProductInsight.fromDoc(doc);
    }
    final lowStock = lowStockById.values.toList()
      ..sort((a, b) {
        if (a.sold != b.sold) return a.sold ? -1 : 1;
        final aQty = a.stockQty ?? 0;
        final bQty = b.stockQty ?? 0;
        return aQty.compareTo(bQty);
      });

    return StaffInsightsSnapshot(
      topViewed: topViewedSnap.docs.map(StaffProductInsight.fromDoc).toList(),
      topFavorited: topFavoritedSnap.docs.map(StaffProductInsight.fromDoc).toList(),
      lowStock: lowStock.take(15).toList(),
      pendingApprovalCount: pendingCountSnap.count ?? 0,
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> pendingApprovalStream() {
    // Single-field filter only — sort client-side to avoid a composite index.
    return FirebaseFirestore.instance.collection('products').where('approved', isEqualTo: false).snapshots();
  }

  /// Newest pending items first (used after fetching without orderBy).
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> sortByCreatedDesc(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTs = a.data()['created_at'];
      final bTs = b.data()['created_at'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      return b.id.compareTo(a.id);
    });
    return sorted;
  }
}
