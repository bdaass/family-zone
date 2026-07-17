import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/product_catalog.dart';

void main() {
  test('soldPriceFromPercent applies percentage discount', () {
    expect(ProductCatalog.soldPriceFromPercent(100, 20), 80);
    expect(ProductCatalog.soldPriceFromPercent(49.99, 10), 44.99);
    expect(ProductCatalog.soldPriceFromPercent(100, 25.3), 74.7);
  });

  test('discountPercentFrom reads stored percent and legacy soldPrice', () {
    expect(
      ProductCatalog.discountPercentFrom({'price': 100.0, 'discountPercent': 25}),
      25,
    );
    expect(
      ProductCatalog.discountPercentFrom({'price': 100.0, 'discountPercent': 25.3}),
      25.3,
    );
    expect(
      ProductCatalog.discountPercentFrom({'price': 100.0, 'soldPrice': 75.0}),
      25,
    );
    expect(ProductCatalog.soldPriceFrom({'price': 100.0, 'discountPercent': 20}), 80);
    expect(ProductCatalog.soldPriceFrom({'price': 100.0, 'discountPercent': 25.3}), 74.7);
  });

  test('parseDiscountPercent accepts decimals and optional percent sign', () {
    expect(ProductCatalog.parseDiscountPercent('15'), 15);
    expect(ProductCatalog.parseDiscountPercent('15%'), 15);
    expect(ProductCatalog.parseDiscountPercent('25.3'), 25.3);
    expect(ProductCatalog.parseDiscountPercent('25.3%'), 25.3);
    expect(ProductCatalog.parseDiscountPercent(''), isNull);
    expect(ProductCatalog.parseDiscountPercent('0'), isNull);
    expect(ProductCatalog.parseDiscountPercent('100'), isNull);
  });

  test('resolveSalePricing accepts float percent or sale price', () {
    expect(
      ProductCatalog.resolveSalePricing(
        regularPrice: 100,
        salePriceText: '',
        discountPercentText: '20',
      ).soldPrice,
      80,
    );
    final fromFloatPercent = ProductCatalog.resolveSalePricing(
      regularPrice: 100,
      salePriceText: '',
      discountPercentText: '25.3',
    );
    expect(fromFloatPercent.soldPrice, 74.7);
    expect(fromFloatPercent.discountPercent, 25.3);

    final fromPrice = ProductCatalog.resolveSalePricing(
      regularPrice: 100,
      salePriceText: '75',
      discountPercentText: '',
    );
    expect(fromPrice.soldPrice, 75);
    expect(fromPrice.discountPercent, 25);

    final fromFloatPrice = ProductCatalog.resolveSalePricing(
      regularPrice: 100,
      salePriceText: '45.6',
      discountPercentText: '',
    );
    expect(fromFloatPrice.soldPrice, 45.6);
    expect(fromFloatPrice.discountPercent, 54.4);
  });

  test('formatDiscountPercent trims whole numbers', () {
    expect(ProductCatalog.formatDiscountPercent(20), '20');
    expect(ProductCatalog.formatDiscountPercent(25.3), '25.3');
  });
}
