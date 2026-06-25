import 'package:family_zone/services/catalog_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventoryResetPatch clears legacy stock fields', () {
    final patch = CatalogMigrationService.inventoryResetPatch();
    expect(patch['stockQty'], 0);
    expect(patch['variantInventory'], isEmpty);
    expect(patch.containsKey('size'), isTrue);
    expect(patch.containsKey('colors'), isTrue);
    expect(patch.containsKey('branchStock'), isTrue);
  });

  test('legacyPatchFor no longer maps stockQty to branchStock', () {
    final patch = CatalogMigrationService.legacyPatchFor({
      'stockQty': 7,
    });
    expect(patch.containsKey('branchStock'), isFalse);
    expect(patch.containsKey('stockQty'), isFalse);
  });
}
