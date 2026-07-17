import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/product_color.dart';

void main() {
  group('ProductColor', () {
    test('normalizes hex strings', () {
      expect(ProductColor.normalizeHex('#c62828'), '#C62828');
      expect(ProductColor.normalizeHex('C62828'), '#C62828');
      expect(ProductColor.normalizeHex('red'), isNull);
    });

    test('maps famous names to hex and back', () {
      expect(ProductColor.toStoredHex('Red'), '#C62828');
      expect(ProductColor.famousEnglishName('#C62828'), 'Red');
      expect(ProductColor.famousEnglishName('red'), 'Red');
      expect(ProductColor.isFamous('#C62828'), isTrue);
      expect(ProductColor.isFamous('#ABCDEF'), isFalse);
    });

    test('same matches name and hex for famous colors', () {
      expect(ProductColor.same('Red', '#C62828'), isTrue);
      expect(ProductColor.same('#c62828', '#C62828'), isTrue);
      expect(ProductColor.same('Red', 'Blue'), isFalse);
      expect(ProductColor.same('#AABBCC', '#AABBCC'), isTrue);
    });

    test('clientLabel is null for custom hex', () {
      expect(ProductColor.clientLabel('#AABBCC'), isNull);
      expect(ProductColor.clientLabel('Red'), isNotNull);
      expect(ProductColor.clientLabel('#C62828'), isNotNull);
    });

    test('swatchFill parses hex', () {
      expect(ProductColor.swatchFill('#C62828'), const Color(0xFFC62828));
      expect(ProductColor.swatchFill('Red'), const Color(0xFFC62828));
    });

    test('colorToHex round-trips', () {
      expect(ProductColor.colorToHex(const Color(0xFFAABBCC)), '#AABBCC');
    });
  });
}
