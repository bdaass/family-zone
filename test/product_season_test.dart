import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductCatalog seasons', () {
    test('normalizeSeason maps legacy all seasons to all_seasons', () {
      expect(ProductCatalog.normalizeSeason('all seasons'), 'all_seasons');
      expect(ProductCatalog.normalizeSeason('ALL_SEASONS'), 'all_seasons');
    });

    test('seasons list includes all_seasons for add/edit forms', () {
      expect(ProductCatalog.seasons, contains('all_seasons'));
    });

    test('matchesSeason includes all_seasons items in Summer filter', () {
      expect(ProductCatalog.matchesSeason('summer', 'Summer'), isTrue);
      expect(ProductCatalog.matchesSeason('all_seasons', 'Summer'), isTrue);
      expect(ProductCatalog.matchesSeason('all seasons', 'Winter'), isTrue);
      expect(ProductCatalog.matchesSeason('sport', 'Summer'), isFalse);
    });

    test('All Year filter matches only all-season products', () {
      expect(ProductCatalog.matchesSeason('all_seasons', 'All Year'), isTrue);
      expect(ProductCatalog.matchesSeason('all seasons', 'All Year'), isTrue);
      expect(ProductCatalog.matchesSeason('summer', 'All Year'), isFalse);
    });

    test('seasonsForFilter includes legacy and canonical all-season values', () {
      expect(
        ProductCatalog.seasonsForFilter('Summer'),
        ['summer', 'all_seasons', 'all seasons'],
      );
      expect(
        ProductCatalog.seasonsForFilter('All Year'),
        ['all_seasons', 'all seasons'],
      );
    });
  });
}
