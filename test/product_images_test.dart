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

    test('imageFieldsForWrite keeps imageUrl in sync and stores imageColors', () {
      final fields = ProductCatalog.imageFieldsForWrite(
        imageUrls: ['https://a/1.jpg', 'https://a/2.jpg'],
        barcodeImageUrl: 'https://a/barcode.jpg',
        imageColorByUrl: {'https://a/2.jpg': 'Green'},
      );
      expect(fields['imageUrl'], 'https://a/1.jpg');
      expect(fields['barcodeImageUrl'], 'https://a/barcode.jpg');
      expect(fields['imageColors'], {'https://a/2.jpg': 'Green'});
    });

    test('imageIndexForColor matches tagged photo', () {
      const urls = ['https://a/black.jpg', 'https://a/green.jpg'];
      const tags = {'https://a/green.jpg': 'Green'};
      expect(ProductCatalog.imageIndexForColor(urls, tags, 'green'), 1);
      expect(ProductCatalog.imageIndexForColor(urls, tags, 'Red'), isNull);
    });

    test('mergeImageColorsAfterUpload applies tags to new uploads', () {
      final merged = ProductCatalog.mergeImageColorsAfterUpload(
        appliedUrls: ['https://a/1.jpg', 'https://a/2.jpg'],
        keptUrls: ['https://a/1.jpg'],
        colorByKeptUrl: {'https://a/1.jpg': 'Black'},
        colorsForNewImages: ['Green'],
      );
      expect(merged, {
        'https://a/1.jpg': 'Black',
        'https://a/2.jpg': 'Green',
      });
    });
    test('imageTagColorOptions only includes entered colors', () {
      final options = ProductCatalog.imageTagColorOptions(
        enteredColors: ['Red', 'Custom Plum', 'red', '#2E7D32'],
      );
      expect(options, contains('#C62828')); // Red
      expect(options, contains('#2E7D32')); // Green hex
      expect(options, contains('Custom Plum'));
      expect(options, isNot(contains('#1A1A1A'))); // Black not entered
      expect(options.where((c) => ProductCatalog.colorsMatch(c, 'Red')).length, 1);
    });

    test('imageIndexForColor matches famous name to hex tags', () {
      const urls = ['https://a/black.jpg', 'https://a/green.jpg'];
      const tags = {'https://a/green.jpg': '#2E7D32'};
      expect(ProductCatalog.imageIndexForColor(urls, tags, 'Green'), 1);
      expect(ProductCatalog.imageIndexForColor(urls, tags, '#2E7D32'), 1);
    });

    test('imageColorsEqual compares tag maps', () {
      expect(
        ProductCatalog.imageColorsEqual({'a': 'Red'}, {'a': 'Red'}),
        isTrue,
      );
      expect(
        ProductCatalog.imageColorsEqual({'a': 'Red'}, {'a': 'Blue'}),
        isFalse,
      );
    });
  });
}
