import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/product_catalog.dart';

void main() {
  test('matchesSearch finds product by ID case-insensitively', () {
    const data = {'productId': 'FZ001', 'title': 'Summer dress', 'description': 'Linen'};
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'fz001'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'FZ0'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'dress'), isTrue);
    expect(ProductCatalog.matchesSearch(data: data, docId: 'FZ001', query: 'NOPE'), isFalse);
  });

  test('isIdSearchTerm requires a digit for ID search', () {
    expect(ProductCatalog.isIdSearchTerm('FZ001'), isTrue);
    expect(ProductCatalog.isIdSearchTerm('dress'), isFalse);
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
}
