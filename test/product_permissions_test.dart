import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/utils/product_permissions.dart';

void main() {
  group('ProductPermissions', () {
    test('isStaff recognizes admin and employee only', () {
      expect(ProductPermissions.isStaff('admin'), isTrue);
      expect(ProductPermissions.isStaff('employee'), isTrue);
      expect(ProductPermissions.isStaff('client'), isFalse);
      expect(ProductPermissions.isStaff('guest'), isFalse);
    });

    test('canDelete is admin-only', () {
      expect(ProductPermissions.canDelete('admin'), isTrue);
      expect(ProductPermissions.canDelete('employee'), isFalse);
    });

    test('isPublicCatalogItem requires visible and approved', () {
      expect(
        ProductPermissions.isPublicCatalogItem({'visibility': true, 'approved': true}),
        isTrue,
      );
      expect(
        ProductPermissions.isPublicCatalogItem({'visibility': true, 'approved': false}),
        isFalse,
      );
      expect(
        ProductPermissions.isPublicCatalogItem({'visibility': false, 'approved': true}),
        isFalse,
      );
    });
  });
}
