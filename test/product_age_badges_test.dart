import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _ts(DateTime dt) => dt;

void main() {
  group('ProductCatalog age badges', () {
    final now = DateTime(2026, 6, 12);

    test('isNewlyAdded is true within 10 days', () {
      final data = {'created_at': _ts(DateTime(2026, 6, 5))};
      expect(ProductCatalog.isNewlyAdded(data, now: now), isTrue);
    });

    test('isNewlyAdded is false on day 10', () {
      final data = {'created_at': _ts(DateTime(2026, 6, 2))};
      expect(ProductCatalog.isNewlyAdded(data, now: now), isFalse);
    });

    test('isNewlyAdded is false without created_at', () {
      expect(ProductCatalog.isNewlyAdded({}, now: now), isFalse);
    });

    test('isOlderThanSixMonths is true before cutoff', () {
      final data = {'created_at': _ts(DateTime(2025, 11, 1))};
      expect(ProductCatalog.isOlderThanSixMonths(data, now: now), isTrue);
    });

    test('isOlderThanSixMonths is false for recent items', () {
      final data = {'created_at': _ts(DateTime(2026, 1, 15))};
      expect(ProductCatalog.isOlderThanSixMonths(data, now: now), isFalse);
    });

    test('isOlderThanSixMonths is false without created_at', () {
      expect(ProductCatalog.isOlderThanSixMonths({}, now: now), isFalse);
    });
  });
}
