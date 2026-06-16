import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('branchStockFrom', () {
    test('reads per-branch map', () {
      final stock = ProductCatalog.branchStockFrom({
        'branchStock': {'tripoli': 5, 'elminieh': 3, 'halba': 0},
      });
      expect(stock['tripoli'], 5);
      expect(stock['elminieh'], 3);
      expect(stock['halba'], 0);
    });

    test('legacy stockQty maps to Tripoli', () {
      final stock = ProductCatalog.branchStockFrom({'stockQty': 12});
      expect(stock['tripoli'], 12);
      expect(stock['elminieh'], isNull);
      expect(stock['halba'], isNull);
    });
  });

  group('resolveBranchStockForSave', () {
    test('empty input clears stock', () {
      final result = ProductCatalog.resolveBranchStockForSave({});
      expect(result.branchStock, isNull);
      expect(result.stockQty, isNull);
    });

    test('sums branch quantities', () {
      final result = ProductCatalog.resolveBranchStockForSave({
        'tripoli': 5,
        'elminieh': 3,
        'halba': null,
      });
      expect(result.branchStock, {'tripoli': 5, 'elminieh': 3});
      expect(result.stockQty, 8);
    });
  });

  group('stockQtyFrom', () {
    test('prefers stored total', () {
      expect(
        ProductCatalog.stockQtyFrom({
          'stockQty': 10,
          'branchStock': {'tripoli': 2},
        }),
        10,
      );
    });

    test('sums branches when total missing', () {
      expect(
        ProductCatalog.stockQtyFrom({
          'branchStock': {'tripoli': 2, 'halba': 4},
        }),
        6,
      );
    });
  });
}
