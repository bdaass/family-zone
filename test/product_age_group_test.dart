import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductCatalog baby age group', () {
    test('normalizeAgeGroup recognizes baby', () {
      expect(ProductCatalog.normalizeAgeGroup('baby'), 'baby');
      expect(ProductCatalog.normalizeAgeGroup('Baby'), 'baby');
      expect(ProductCatalog.normalizeAgeGroup('infant'), 'baby');
    });

    test('ageGroups includes adult, kids, and baby', () {
      expect(ProductCatalog.ageGroups, ['adult', 'kids', 'baby']);
    });

    test('filterAgeGroups includes Baby', () {
      expect(ProductCatalog.filterAgeGroups, contains('Baby'));
    });

    test('baby products use boy/girl labels', () {
      expect(
        ProductCatalog.sexFormLabel(ageGroup: 'baby', sex: 'male'),
        isNotEmpty,
      );
      expect(ProductCatalog.usesChildSexLabels('baby'), isTrue);
      expect(ProductCatalog.usesChildSexLabels('adult'), isFalse);
    });

    test('matchesAgeGroupFilter filters baby items', () {
      final babyBoy = {'ageGroup': 'baby', 'sex': 'male'};
      final kidsBoy = {'ageGroup': 'kids', 'sex': 'male'};
      expect(ProductCatalog.matchesAgeGroupFilter(babyBoy, 'Baby'), isTrue);
      expect(ProductCatalog.matchesAgeGroupFilter(kidsBoy, 'Baby'), isFalse);
      expect(ProductCatalog.matchesAgeGroupFilter(babyBoy, 'Kids'), isFalse);
    });

    test('matchesSexFilter works for baby boy/girl', () {
      final babyBoy = {'ageGroup': 'baby', 'sex': 'male'};
      final babyGirl = {'ageGroup': 'baby', 'sex': 'female'};
      expect(ProductCatalog.matchesSexFilter(babyBoy, 'Male'), isTrue);
      expect(ProductCatalog.matchesSexFilter(babyBoy, 'Female'), isFalse);
      expect(ProductCatalog.matchesSexFilter(babyGirl, 'Female'), isTrue);
    });
  });
}
