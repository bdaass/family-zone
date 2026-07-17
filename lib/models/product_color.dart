import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Product color stored as `#RRGGBB` (famous palette or custom picker).
/// Legacy English names remain readable for existing Firestore data.
class ProductColor {
  ProductColor._();

  /// Famous colors shown in the staff dropdown — English name → hex.
  static const Map<String, String> famousHexByName = {
    'Black': '#1A1A1A',
    'White': '#F4F4F4',
    'Navy': '#1B2A4A',
    'Beige': '#D8CBB8',
    'Gray': '#9E9E9E',
    'Light gray': '#BDBDBD',
    'Dark gray': '#424242',
    'Red': '#C62828',
    'Pink': '#E891A8',
    'Peach': '#FFCC99',
    'Blue': '#1565C0',
    'Light blue': '#90CAF9',
    'Green': '#2E7D32',
    'Brown': '#6D4C41',
    'Orange': '#E65100',
    'Yellow': '#F9A825',
    'Yellow butter': '#F5E6A3',
    'Purple': '#6A1B9A',
    'Lilac': '#C8A2C8',
    'Burgundy': '#6D1B2A',
    'Cream': '#FFF8E7',
    'Olive': '#6B7C3E',
    'Coral': '#FF7043',
    'Gold': '#D4AF37',
    'Ivory': '#FFFFF0',
    'Khaki': '#C3B091',
    'Maroon': '#800000',
    'Turquoise': '#26A69A',
    'Teal': '#00897B',
    'Silver': '#B0BEC5',
  };

  static final Map<String, String> _hexToFamousName = {
    for (final entry in famousHexByName.entries) entry.value.toUpperCase(): entry.key,
  };

  static final RegExp _hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');

  static List<String> get famousNames => famousHexByName.keys.toList(growable: false);

  static bool isHex(String raw) => _hexPattern.hasMatch(raw.trim());

  /// Normalize `#rrggbb` / `rrggbb` → `#RRGGBB`, or null if not hex.
  static String? normalizeHex(String raw) {
    final match = _hexPattern.firstMatch(raw.trim());
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  static String? hexForFamousName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    for (final entry in famousHexByName.entries) {
      if (entry.key.toLowerCase() == trimmed.toLowerCase()) return entry.value;
    }
    // Grey spelling aliases used in older data / l10n keys.
    switch (trimmed.toLowerCase()) {
      case 'grey':
        return famousHexByName['Gray'];
      case 'light grey':
        return famousHexByName['Light gray'];
      case 'dark grey':
        return famousHexByName['Dark gray'];
      default:
        return null;
    }
  }

  /// English famous name for a stored value (hex or legacy name), else null.
  static String? famousEnglishName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final hex = normalizeHex(trimmed);
    if (hex != null) return _hexToFamousName[hex];

    for (final name in famousHexByName.keys) {
      if (name.toLowerCase() == trimmed.toLowerCase()) return name;
    }
    switch (trimmed.toLowerCase()) {
      case 'grey':
        return 'Gray';
      case 'light grey':
        return 'Light gray';
      case 'dark grey':
        return 'Dark gray';
      default:
        return null;
    }
  }

  static bool isFamous(String raw) => famousEnglishName(raw) != null;

  /// Canonical storage value for new staff picks: always `#RRGGBB`.
  static String toStoredHex(String nameOrHex) {
    final hex = normalizeHex(nameOrHex);
    if (hex != null) return hex;
    final famousHex = hexForFamousName(nameOrHex);
    if (famousHex != null) return famousHex;
    throw ArgumentError('Expected a famous color name or hex, got: $nameOrHex');
  }

  /// Best-effort identity for matching inventory keys / image tags.
  static String? identityKey(String raw) {
    final hex = normalizeHex(raw) ?? hexForFamousName(raw);
    if (hex != null) return hex.toUpperCase();
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed.toLowerCase();
  }

  static bool same(String a, String b) {
    final ka = identityKey(a);
    final kb = identityKey(b);
    if (ka == null || kb == null) return false;
    return ka == kb;
  }

  /// Localized famous name, else hex, else raw (for staff / text contexts).
  static String displayLabel(String raw) {
    final famous = famousEnglishName(raw);
    if (famous != null) return S.colorName(famous);
    final hex = normalizeHex(raw);
    if (hex != null) return hex;
    return raw.trim();
  }

  /// Client-facing label: localized famous name, or null when only a swatch should show.
  static String? clientLabel(String raw) {
    final famous = famousEnglishName(raw);
    if (famous == null) return null;
    return S.colorName(famous);
  }

  static Color swatchFill(String raw) {
    final hex = normalizeHex(raw) ?? hexForFamousName(raw);
    if (hex != null) {
      final value = int.parse(hex.substring(1), radix: 16);
      return Color(0xFF000000 | value);
    }
    final name = raw.toLowerCase().trim();
    final hash = name.codeUnits.fold(0, (sum, c) => sum + c);
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.42, 0.52).toColor();
  }

  static String colorToHex(Color color) {
    final argb = color.toARGB32();
    final r = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }
}
