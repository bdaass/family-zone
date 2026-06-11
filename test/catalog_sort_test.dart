import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/catalog_sort.dart';

void main() {
  test('sortCatalogEntries orders by effective price ascending', () {
    final entries = [
      MapEntry('a', {'price': 50.0}),
      MapEntry('b', {'price': 20.0, 'soldPrice': 15.0}),
      MapEntry('c', {'price': 30.0}),
    ];

    sortCatalogEntries(entries, CatalogSort.priceLowHigh);
    expect(entries.map((e) => e.key).toList(), ['b', 'c', 'a']);
  });

  test('sortCatalogEntries puts sale items first', () {
    final entries = [
      MapEntry('a', {'price': 10.0}),
      MapEntry('b', {'price': 40.0, 'soldPrice': 25.0}),
      MapEntry('c', {'price': 15.0, 'soldPrice': 12.0}),
    ];

    sortCatalogEntries(entries, CatalogSort.saleFirst);
    expect(entries.first.key, isIn(['b', 'c']));
    expect(entries.last.key, 'a');
  });

  test('sortCatalogEntries orders by favorite count', () {
    final entries = [
      MapEntry('a', {'favoriteCount': 2}),
      MapEntry('b', {'favoriteCount': 9}),
      MapEntry('c', {'favoriteCount': 5}),
    ];

    sortCatalogEntries(entries, CatalogSort.mostPopular);
    expect(entries.map((e) => e.key).toList(), ['b', 'c', 'a']);
  });
}
