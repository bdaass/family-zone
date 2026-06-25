import 'package:family_zone/models/product_catalog.dart';
import 'package:family_zone/models/variant_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VariantInventory', () {
    test('parses nested Firestore map', () {
      final inventory = VariantInventory.fromFirestore({
        'tripoli': {
          'Red': {'X': 15, 'L': 10},
          'Blue': {'L': 10},
        },
        'elminieh': {
          'Red': {'M': 3},
        },
      });

      expect(inventory['tripoli']?['Red']?['X'], 15);
      expect(inventory['tripoli']?['Blue']?['L'], 10);
      expect(inventory['elminieh']?['Red']?['M'], 3);
      expect(VariantInventory.totalQty(inventory), 38);
    });

    test('unique colors and sizes', () {
      final inventory = VariantInventory.fromFirestore({
        'tripoli': {
          'Red': {'X': 1},
          'Blue': {'L': 2},
        },
        'halba': {
          'red': {'M': 1},
        },
      });

      expect(VariantInventory.uniqueColors(inventory), ['Blue', 'Red', 'red']);
      expect(VariantInventory.uniqueSizes(inventory), containsAll(['X', 'L', 'M']));
    });

    test('variant total across branches', () {
      final inventory = VariantInventory.fromFirestore({
        'tripoli': {'Red': {'X': 5}},
        'halba': {'Red': {'X': 3}},
      });

      expect(
        VariantInventory.variantTotalQty(inventory, color: 'Red', size: 'X'),
        8,
      );
    });
  });

  group('ProductCatalog variant helpers', () {
    test('sizeFrom and colorsFrom derive from variantInventory', () {
      final data = {
        'variantInventory': {
          'tripoli': {
            'Red': {'X': 2, 'L': 1},
          },
        },
      };

      expect(ProductCatalog.sizesFromField(ProductCatalog.sizeFrom(data)), containsAll(['X', 'L']));
      expect(ProductCatalog.colorsFromField(ProductCatalog.colorsFrom(data)), ['Red']);
      expect(ProductCatalog.stockQtyFrom(data), 3);
    });

    test('resolveVariantInventoryForSave encodes fields', () {
      final inventory = VariantInventory.fromFirestore({
        'tripoli': {'Red': {'X': 15}},
      });
      final saved = ProductCatalog.resolveVariantInventoryForSave(inventory);

      expect(saved.size, 'X');
      expect(saved.colors, 'Red');
      expect(saved.stockQty, 15);
      expect(saved.variantInventory, {
        'tripoli': {'Red': {'X': 15}},
      });
    });

    test('branchStockFrom sums variant inventory per branch', () {
      final stock = ProductCatalog.branchStockFrom({
        'variantInventory': {
          'tripoli': {'Red': {'X': 5, 'L': 10}},
          'halba': {'Blue': {'M': 2}},
        },
      });

      expect(stock['tripoli'], 15);
      expect(stock['halba'], 2);
      expect(stock['elminieh'], isNull);
    });
  });
}
