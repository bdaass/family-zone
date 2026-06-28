import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/product_catalog.dart';

void main() {
  test('matchesSearch finds product by ID prefix case-insensitively', () {
    const data = {'productId': 'FZ001', 'title': 'Summer dress', 'description': 'Linen'};
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'fz001'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'FZ0'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'FZ'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'F'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'NOPE'), isFalse);
  });

  test('matchesSearch uses title only, not description', () {
    const data = {'productId': 'FZ001', 'title': 'Summer dress', 'description': 'Linen'};
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'dress'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'summer'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'linen'), isFalse);
  });

  test('looksLikeIdPrefix detects short SKU prefixes and digit IDs', () {
    expect(ProductCatalog.looksLikeIdPrefix('FZ001'), isTrue);
    expect(ProductCatalog.looksLikeIdPrefix('FZ'), isTrue);
    expect(ProductCatalog.looksLikeIdPrefix('F'), isTrue);
    expect(ProductCatalog.looksLikeIdPrefix('dress'), isFalse);
    expect(ProductCatalog.looksLikeIdPrefix('summer'), isFalse);
  });

  test('searchIndexFields includes searchIdPrefix', () {
    final fields = ProductCatalog.searchIndexFields(
      title: 'Dress',
      description: 'Nice',
      productId: 'AB12',
      size: 'M',
      colors: '',
      price: 50,
      season: 'summer',
      ageGroup: 'adult',
      sex: 'female',
      type: 'clothes',
    );
    expect(fields['searchIdPrefix'], 'ab12');
  });

  test('searchIndexFields stores effectivePrice for sale items', () {
    final onSale = ProductCatalog.searchIndexFields(
      title: 'Dress',
      description: 'Nice',
      productId: 'AB12',
      size: 'M',
      colors: '',
      price: 50,
      soldPrice: 35,
      season: 'summer',
      ageGroup: 'adult',
      sex: 'female',
      type: 'clothes',
    );
    expect(onSale['effectivePrice'], 35);
    expect(onSale['onSale'], isTrue);

    final regular = ProductCatalog.searchIndexFields(
      title: 'Dress',
      description: 'Nice',
      productId: 'AB13',
      size: 'M',
      colors: '',
      price: 50,
      season: 'summer',
      ageGroup: 'adult',
      sex: 'female',
      type: 'clothes',
    );
    expect(regular['effectivePrice'], 50);
  });
}
