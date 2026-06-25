import '../config/store_config.dart';
import 'product_catalog.dart';

/// Per-branch stock: color → size → quantity.
typedef BranchVariantStock = Map<String, Map<String, int>>;

/// branchId → color → size → quantity.
typedef VariantInventoryMap = Map<String, BranchVariantStock>;

/// Helpers for location / color / size inventory stored in Firestore as `variantInventory`.
class VariantInventory {
  VariantInventory._();

  static VariantInventoryMap empty() => {
        for (final branch in StoreConfig.locations) branch.id: <String, Map<String, int>>{},
      };

  static VariantInventoryMap fromFirestore(dynamic raw) {
    final result = empty();
    if (raw is! Map) return result;

    for (final branch in StoreConfig.locations) {
      final branchRaw = raw[branch.id];
      if (branchRaw is! Map) continue;
      final colors = <String, Map<String, int>>{};
      for (final colorEntry in branchRaw.entries) {
        final color = colorEntry.key.toString().trim();
        if (color.isEmpty) continue;
        final sizesRaw = colorEntry.value;
        if (sizesRaw is! Map) continue;
        final sizes = <String, int>{};
        for (final sizeEntry in sizesRaw.entries) {
          final size = sizeEntry.key.toString().trim();
          if (size.isEmpty) continue;
          final qty = ProductCatalog.optionalIntFrom(sizeEntry.value);
          if (qty != null && qty >= 0) sizes[size] = qty;
        }
        if (sizes.isNotEmpty) colors[color] = sizes;
      }
      if (colors.isNotEmpty) result[branch.id] = colors;
    }
    return result;
  }

  static Map<String, dynamic> toFirestore(VariantInventoryMap inventory) {
    final result = <String, dynamic>{};
    for (final branch in StoreConfig.locations) {
      final colors = inventory[branch.id];
      if (colors == null || colors.isEmpty) continue;
      final branchMap = <String, dynamic>{};
      for (final colorEntry in colors.entries) {
        if (colorEntry.value.isEmpty) continue;
        branchMap[colorEntry.key] = Map<String, int>.from(colorEntry.value);
      }
      if (branchMap.isNotEmpty) result[branch.id] = branchMap;
    }
    return result;
  }

  static bool hasAnyEntries(VariantInventoryMap inventory) {
    for (final colors in inventory.values) {
      for (final sizes in colors.values) {
        if (sizes.isNotEmpty) return true;
      }
    }
    return false;
  }

  static List<String> uniqueColors(VariantInventoryMap inventory) {
    final colors = <String>{};
    for (final branch in inventory.values) {
      colors.addAll(branch.keys);
    }
    return colors.toList()..sort(_compareLabels);
  }

  static List<String> uniqueSizes(VariantInventoryMap inventory) {
    final sizes = <String>{};
    for (final branch in inventory.values) {
      for (final colorSizes in branch.values) {
        sizes.addAll(colorSizes.keys);
      }
    }
    return sizes.toList()..sort(_compareLabels);
  }

  static int totalQty(VariantInventoryMap inventory) {
    var total = 0;
    for (final branch in inventory.values) {
      for (final colorSizes in branch.values) {
        for (final qty in colorSizes.values) {
          total += qty;
        }
      }
    }
    return total;
  }

  static int? branchTotal(VariantInventoryMap inventory, String branchId) {
    final colors = inventory[branchId];
    if (colors == null || colors.isEmpty) return null;
    var total = 0;
    var hasQty = false;
    for (final sizes in colors.values) {
      for (final qty in sizes.values) {
        total += qty;
        hasQty = true;
      }
    }
    return hasQty ? total : null;
  }

  static Map<String, int?> branchTotals(VariantInventoryMap inventory) {
    return {
      for (final id in ProductCatalog.branchIds) id: branchTotal(inventory, id),
    };
  }

  static int variantTotalQty(
    VariantInventoryMap inventory, {
    required String color,
    required String size,
  }) {
    var total = 0;
    for (final branch in inventory.values) {
      for (final colorEntry in branch.entries) {
        if (!_equalsIgnoreCase(colorEntry.key, color)) continue;
        for (final sizeEntry in colorEntry.value.entries) {
          if (_equalsIgnoreCase(sizeEntry.key, size)) total += sizeEntry.value;
        }
      }
    }
    return total;
  }

  static List<String> colorsWithStock(VariantInventoryMap inventory) {
    final counts = <String, int>{};
    for (final branch in inventory.values) {
      for (final colorEntry in branch.entries) {
        final qty = colorEntry.value.values.fold<int>(0, (sum, n) => sum + n);
        if (qty > 0) {
          counts[colorEntry.key] = (counts[colorEntry.key] ?? 0) + qty;
        }
      }
    }
    return counts.keys.toList()..sort(_compareLabels);
  }

  static List<String> sizesWithStockForColor(VariantInventoryMap inventory, String color) {
    final counts = <String, int>{};
    for (final branch in inventory.values) {
      for (final colorEntry in branch.entries) {
        if (!_equalsIgnoreCase(colorEntry.key, color)) continue;
        for (final sizeEntry in colorEntry.value.entries) {
          if (sizeEntry.value > 0) {
            counts[sizeEntry.key] = (counts[sizeEntry.key] ?? 0) + sizeEntry.value;
          }
        }
      }
    }
    return counts.keys.toList()..sort(_compareLabels);
  }

  static int _compareLabels(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  static bool _equalsIgnoreCase(String a, String b) => a.toLowerCase() == b.toLowerCase();

  static String? findCanonicalColor(VariantInventoryMap inventory, String color) {
    for (final branch in inventory.values) {
      for (final key in branch.keys) {
        if (_equalsIgnoreCase(key, color)) return key;
      }
    }
    return null;
  }

  static String? findCanonicalSize(BranchVariantStock branchColors, String color, String size) {
    final colors = branchColors[color];
    if (colors == null) {
      for (final colorEntry in branchColors.entries) {
        if (!_equalsIgnoreCase(colorEntry.key, color)) continue;
        for (final key in colorEntry.value.keys) {
          if (_equalsIgnoreCase(key, size)) return key;
        }
      }
      return null;
    }
    for (final key in colors.keys) {
      if (_equalsIgnoreCase(key, size)) return key;
    }
    return null;
  }
}
