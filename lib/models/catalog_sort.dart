import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_catalog.dart';

/// Catalog sort — applied server-side via Firestore [effectivePrice], [favoriteCount], [onSale].
enum CatalogSort {
  newest,
  priceLowHigh,
  saleFirst,
  mostPopular,
}

extension CatalogSortX on CatalogSort {
  String get labelKey {
    switch (this) {
      case CatalogSort.newest:
        return 'sort_newest';
      case CatalogSort.priceLowHigh:
        return 'sort_price_low_high';
      case CatalogSort.saleFirst:
        return 'sort_sale_first';
      case CatalogSort.mostPopular:
        return 'sort_most_popular';
    }
  }

  static List<CatalogSort> get options => CatalogSort.values;
}

int compareCatalogEntries(String idA, Map<String, dynamic> dataA, String idB, Map<String, dynamic> dataB) {
  final aTs = dataA['created_at'];
  final bTs = dataB['created_at'];
  if (aTs is Timestamp && bTs is Timestamp) {
    return bTs.compareTo(aTs);
  }
  return idA.compareTo(idB);
}

void sortCatalogEntries(List<MapEntry<String, Map<String, dynamic>>> entries, CatalogSort sort) {
  int compareCreated(MapEntry<String, Map<String, dynamic>> a, MapEntry<String, Map<String, dynamic>> b) {
    return compareCatalogEntries(a.key, a.value, b.key, b.value);
  }

  switch (sort) {
    case CatalogSort.newest:
      entries.sort(compareCreated);
    case CatalogSort.priceLowHigh:
      entries.sort((a, b) {
        final priceCmp = ProductCatalog.effectivePrice(a.value).compareTo(ProductCatalog.effectivePrice(b.value));
        return priceCmp != 0 ? priceCmp : compareCreated(a, b);
      });
    case CatalogSort.saleFirst:
      entries.sort((a, b) {
        final aSale = ProductCatalog.hasActiveSale(a.value);
        final bSale = ProductCatalog.hasActiveSale(b.value);
        if (aSale != bSale) return aSale ? -1 : 1;
        return compareCreated(a, b);
      });
    case CatalogSort.mostPopular:
      entries.sort((a, b) {
        final favCmp = ProductCatalog.favoriteCountFrom(b.value).compareTo(ProductCatalog.favoriteCountFrom(a.value));
        return favCmp != 0 ? favCmp : compareCreated(a, b);
      });
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> sortCatalogDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  CatalogSort sort,
) {
  final entries = docs.map((doc) => MapEntry(doc.id, doc.data())).toList();
  sortCatalogEntries(entries, sort);
  final byId = {for (final doc in docs) doc.id: doc};
  return entries.map((entry) => byId[entry.key]!).toList();
}
