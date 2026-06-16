import 'package:family_zone/models/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductCatalog images', () {
    test('productImageUrlsFrom reads imageUrls array', () {
      const data = {
        'imageUrls': ['https://a/1.jpg', 'https://a/2.jpg'],
      };
      expect(ProductCatalog.productImageUrlsFrom(data), [
        'https://a/1.jpg',
        'https://a/2.jpg',
      ]);
    });

    test('productImageUrlsFrom falls back to legacy imageUrl', () {
      const data = {'imageUrl': 'https://a/legacy.jpg'};
      expect(ProductCatalog.productImageUrlsFrom(data), ['https://a/legacy.jpg']);
    });

    test('imageFieldsForWrite keeps imageUrl in sync', () {
      final fields = ProductCatalog.imageFieldsForWrite(
        imageUrls: ['https://a/1.jpg', 'https://a/2.jpg'],
        barcodeImageUrl: 'https://a/barcode.jpg',
      );
      expect(fields['imageUrl'], 'https://a/1.jpg');
      expect(fields['barcodeImageUrl'], 'https://a/barcode.jpg');
    });
  });
}
