import 'package:family_zone/utils/storage_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageMediaUrl', () {
    test('strips expired token from Firebase download URL', () {
      const withToken =
          'https://firebasestorage.googleapis.com/v0/b/family-zone-2026.firebasestorage.app/o/product_images%2FAB12%2F0.jpg?alt=media&token=dead-token';
      expect(
        StorageMediaUrl.normalizePublic(withToken),
        'https://firebasestorage.googleapis.com/v0/b/family-zone-2026.firebasestorage.app/o/product_images%2FAB12%2F0.jpg?alt=media',
      );
    });

    test('builds same-origin media path for web display', () {
      expect(
        StorageMediaUrl.sameOriginMediaUrl('product_images/AB12/0.jpg'),
        '/media/product_images/AB12/0.jpg',
      );
    });

    test('parses same-origin media path back to object path', () {
      expect(
        StorageMediaUrl.objectPathFromUrl('/media/product_images/AB12/0.jpg'),
        'product_images/AB12/0.jpg',
      );
    });

    test('leaves non-storage URLs unchanged for display', () {
      const external = 'https://cdn.example.com/shoe.jpg';
      expect(StorageMediaUrl.displayUrl(external), external);
    });

    test('does not rewrite barcode paths in public displayUrl', () {
      const barcode =
          'https://firebasestorage.googleapis.com/v0/b/family-zone-2026.firebasestorage.app/o/product_images%2FAB12%2Fbarcode.jpg?alt=media&token=x';
      expect(StorageMediaUrl.displayUrl(barcode), barcode);
    });

    test('builds staff barcode path helper', () {
      expect(
        StorageMediaUrl.sameOriginMediaUrl('product_images/AB12/barcode.jpg'),
        '/media/product_images/AB12/barcode.jpg',
      );
      expect(StorageMediaUrl.isStaffBarcodePath('product_images/AB12/barcode.jpg'), isTrue);
      expect(StorageMediaUrl.isStaffBarcodePath('product_images/AB12/0.jpg'), isFalse);
    });
  });
}
