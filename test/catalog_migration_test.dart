import 'package:family_zone/services/catalog_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacyPatchFor maps single imageUrl to imageUrls', () {
    final patch = CatalogMigrationService.legacyPatchFor({
      'imageUrl': 'https://example.com/a.jpg',
    });
    expect(patch['imageUrls'], ['https://example.com/a.jpg']);
    expect(patch['imageUrl'], 'https://example.com/a.jpg');
  });

  test('legacyPatchFor maps stockQty to tripoli branchStock', () {
    final patch = CatalogMigrationService.legacyPatchFor({
      'stockQty': 7,
    });
    expect(patch['branchStock'], {'tripoli': 7});
    expect(patch['stockQty'], 7);
  });

  test('legacyPatchFor skips when already normalized', () {
    expect(
      CatalogMigrationService.legacyPatchFor({
        'imageUrls': ['https://example.com/a.jpg'],
        'branchStock': {'tripoli': 2},
      }),
      isEmpty,
    );
  });
}
