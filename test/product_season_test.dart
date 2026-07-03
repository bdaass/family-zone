import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductCatalog seasons', () {
    test('normalizeSeason maps legacy all-season spellings', () {
      expect(ProductCatalog.normalizeSeason('all seasons'), 'all_seasons');
      expect(ProductCatalog.normalizeSeason('all season'), 'all_seasons');
      expect(ProductCatalog.normalizeSeason('ALL_SEASONS'), 'all_seasons');
    });

    test('staff season choices are summer, winter, all_seasons, sport', () {
      expect(
        ProductCatalog.seasons,
        ['summer', 'winter', 'all_seasons', 'sport'],
      );
    });

    test('shop filters include All Season as its own exclusive season', () {
      expect(ProductCatalog.filterSeasons, contains('All Season'));
      expect(ProductCatalog.filterSeasons.first, 'All Seasons');
    });

    test('matchesSeason is exclusive per season', () {
      expect(ProductCatalog.matchesSeason('summer', 'Summer'), isTrue);
      expect(ProductCatalog.matchesSeason('all_seasons', 'Summer'), isFalse);
      expect(ProductCatalog.matchesSeason('sport', 'Summer'), isFalse);

      expect(ProductCatalog.matchesSeason('sport', 'Sport'), isTrue);
      expect(ProductCatalog.matchesSeason('winter', 'Sport'), isFalse);
      expect(ProductCatalog.matchesSeason('all_seasons', 'Sport'), isFalse);

      expect(ProductCatalog.matchesSeason('all_seasons', 'All Season'), isTrue);
      expect(ProductCatalog.matchesSeason('summer', 'All Season'), isFalse);
      expect(ProductCatalog.matchesSeason('sport', 'All Season'), isFalse);

      expect(ProductCatalog.matchesSeason('winter', 'All Seasons'), isTrue);
      expect(ProductCatalog.matchesSeason('sport', 'All Seasons'), isTrue);
    });

    test('seasonsForFilter queries only the selected season', () {
      expect(ProductCatalog.seasonsForFilter('Summer'), ['summer']);
      expect(ProductCatalog.seasonsForFilter('Sport'), ['sport']);
      expect(
        ProductCatalog.seasonsForFilter('All Season'),
        ['all_seasons', 'all seasons'],
      );
      expect(ProductCatalog.seasonsForFilter('All Seasons'), isEmpty);
    });
  });

  group('ProductCatalog types', () {
    test('normalizeType maps French aliases', () {
      expect(ProductCatalog.normalizeType('chaussures'), 'shoes');
      expect(ProductCatalog.normalizeType('chaussettes'), 'socks');
      expect(ProductCatalog.normalizeType('ceintures'), 'belt');
    });

    test('matchesType filters socks and belts separately from clothes', () {
      expect(ProductCatalog.matchesType('socks', 'Socks'), isTrue);
      expect(ProductCatalog.matchesType('chaussettes', 'Socks'), isTrue);
      expect(ProductCatalog.matchesType('clothes', 'Socks'), isFalse);
      expect(ProductCatalog.matchesType('belt', 'Belt'), isTrue);
      expect(ProductCatalog.matchesType('clothes', 'Belt'), isFalse);
    });
  });
}
