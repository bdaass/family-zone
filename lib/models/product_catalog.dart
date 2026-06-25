import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import 'variant_inventory.dart';

/// Shared product categories, filters, and field helpers.
class ProductCatalog {
  static const seasons = ['summer', 'winter', 'sport', 'all_seasons'];
  static const ageGroups = ['adult', 'kids', 'baby'];
  static const sexes = ['female', 'male'];
  static const types = ['clothes', 'shoes', 'lingery', 'sac', 'scarf'];

  static const filterSeasons = ['All Seasons', 'Summer', 'Winter', 'Sport', 'All Year'];
  static const filterAgeGroups = ['All', 'Adult', 'Kids', 'Baby'];
  static const filterSexes = ['All', 'Female', 'Male'];
  static const filterCategories = ['All Categories', 'Clothes', 'Shoes', 'Lingery', 'Sac', 'Scarf'];

  /// Stored on products when staff has not decided yet (add form).
  static const notDetermined = 'not_determined';

  static bool isNotDetermined(String? raw) {
    final v = (raw ?? '').toLowerCase().trim().replaceAll(' ', '_');
    return v == notDetermined || v == 'notdetermined';
  }

  static String notDeterminedLabel() => S.of('choice_not_determined');

  static final RegExp _productIdPattern = RegExp(r'^[A-Za-z0-9]+$');

  static bool isValidProductId(String id) {
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= 64 && _productIdPattern.hasMatch(trimmed);
  }

  /// True when the query should use product-ID prefix search (e.g. F, FZ, FZ153).
  static bool looksLikeIdPrefix(String token) {
    final trimmed = token.trim();
    if (!isValidProductId(trimmed)) return false;
    if (RegExp(r'\d').hasMatch(trimmed)) return true;
    // Short letter-only prefixes of SKU-style IDs (e.g. FZ1024).
    if (trimmed.length <= 3 && RegExp(r'^[A-Za-z]+$').hasMatch(trimmed)) {
      return RegExp(r'^F', caseSensitive: false).hasMatch(trimmed);
    }
    return false;
  }

  /// True when the search term should use product-ID lookup.
  static bool isIdSearchTerm(String token) => looksLikeIdPrefix(token);

  static String normalizedIdSearch(String query) => query.trim().toLowerCase();

  static String normalizeAgeGroup(String? raw) {
    if (isNotDetermined(raw)) return notDetermined;
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'baby' || v == 'infant' || v == 'babies') return 'baby';
    if (v == 'kids' || v == 'kid' || v == 'children' || v == 'child') return 'kids';
    return 'adult';
  }

  static bool usesChildSexLabels(String ageGroup) {
    if (isNotDetermined(ageGroup)) return false;
    final group = normalizeAgeGroup(ageGroup);
    return group == 'kids' || group == 'baby';
  }

  static String normalizeSex(String? raw) {
    if (isNotDetermined(raw)) return notDetermined;
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'male' || v == 'man' || v == 'boy' || v == 'm') return 'male';
    return 'female';
  }

  /// Reads age + sex from document, including legacy `sex`-only values.
  static ({String ageGroup, String sex, bool legacyChildrenOnly}) audienceFrom(Map<String, dynamic> data) {
    if (data['ageGroup'] != null) {
      return (
        ageGroup: normalizeAgeGroup(data['ageGroup']?.toString()),
        sex: normalizeSex(data['sex']?.toString()),
        legacyChildrenOnly: false,
      );
    }

    final legacy = (data['sex'] ?? '').toString().toLowerCase().trim();
    if (legacy == 'children' || legacy == 'child') {
      return (ageGroup: 'kids', sex: 'female', legacyChildrenOnly: true);
    }
    if (legacy == 'man' || legacy == 'male' || legacy == 'boy') {
      return (ageGroup: 'adult', sex: 'male', legacyChildrenOnly: false);
    }
    return (ageGroup: 'adult', sex: 'female', legacyChildrenOnly: false);
  }

  static String ageGroupLabel(String ageGroup) {
    if (isNotDetermined(ageGroup)) return notDeterminedLabel();
    switch (normalizeAgeGroup(ageGroup)) {
      case 'kids':
        return S.of('age_kids');
      case 'baby':
        return S.of('age_baby');
      default:
        return S.of('age_adult');
    }
  }

  static String sexFormLabel({required String ageGroup, required String sex}) {
    if (isNotDetermined(sex)) return notDeterminedLabel();
    final childLabels = usesChildSexLabels(ageGroup);
    if (normalizeSex(sex) == 'male') {
      return childLabels ? S.of('sex_boy') : S.of('sex_man');
    }
    return childLabels ? S.of('sex_girl') : S.of('sex_woman');
  }

  static String audienceLabelFromData(Map<String, dynamic> data) {
    final audience = audienceFrom(data);
    return sexFormLabel(ageGroup: audience.ageGroup, sex: audience.sex);
  }

  static String sexFilterPillLabel(String filterValue, {String ageGroupFilter = 'All'}) {
    switch (filterValue) {
      case 'All':
        return S.of('gender_all');
      case 'Female':
        if (ageGroupFilter == 'Kids' || ageGroupFilter == 'Baby') return S.of('sex_girl');
        if (ageGroupFilter == 'Adult') return S.of('sex_woman');
        return S.of('filter_sex_female');
      case 'Male':
        if (ageGroupFilter == 'Kids' || ageGroupFilter == 'Baby') return S.of('sex_boy');
        if (ageGroupFilter == 'Adult') return S.of('sex_man');
        return S.of('filter_sex_male');
      default:
        return filterValue;
    }
  }

  static String ageGroupFilterPillLabel(String filterValue) {
    switch (filterValue) {
      case 'All':
        return S.of('gender_all');
      case 'Kids':
        return S.of('age_kids');
      case 'Baby':
        return S.of('age_baby');
      case 'Adult':
        return S.of('age_adult');
      default:
        return filterValue;
    }
  }

  /// Price slider bounds (USD). Full range = no active price filter.
  static const double priceFilterFloor = 0;
  static const double priceFilterCeiling = 250;
  static const int priceFilterStep = 10;
  static int get priceFilterDivisions =>
      ((priceFilterCeiling - priceFilterFloor) / priceFilterStep).round();

  static bool hasActivePriceFilter(double min, double max) =>
      min > priceFilterFloor || max < priceFilterCeiling;

  static String formatPrice(double value) => '\$${value.round()}';

  static String formatPriceRange(double min, double max) {
    if (!hasActivePriceFilter(min, max)) return S.of('filter_price_any');
    return '${formatPrice(min)} – ${formatPrice(max)}';
  }

  static bool matchesPriceRange(Map<String, dynamic> data, {required double min, required double max}) {
    if (!hasActivePriceFilter(min, max)) return true;
    final price = effectivePrice(data);
    return price >= min && price <= max;
  }

  static String label(String value) => localizedCatalogLabel(value);

  static String localizedCatalogLabel(String value) {
    if (isNotDetermined(value)) return notDeterminedLabel();
    switch (value.toLowerCase()) {
      case 'summer':
        return S.of('catalog_summer');
      case 'winter':
        return S.of('catalog_winter');
      case 'sport':
        return S.of('catalog_sport');
      case 'all_seasons':
      case 'all seasons':
        return S.of('catalog_all_seasons');
      case 'woman':
      case 'female':
        return S.of('sex_woman');
      case 'man':
      case 'male':
        return S.of('sex_man');
      case 'girl':
        return S.of('sex_girl');
      case 'boy':
        return S.of('sex_boy');
      case 'children':
      case 'kids':
      case 'kid':
        return S.of('age_kids');
      case 'baby':
        return S.of('age_baby');
      case 'adult':
        return S.of('age_adult');
      case 'clothes':
        return S.of('catalog_clothes');
      case 'shoes':
        return S.of('catalog_shoes');
      case 'lingery':
        return S.of('catalog_lingery');
      case 'sac':
        return S.of('catalog_sac');
      case 'scarf':
        return S.of('catalog_scarf');
      default:
        return value.toUpperCase();
    }
  }

  static String filterPillLabel(String filterValue, {String ageGroupFilter = 'All'}) {
    if (filterAgeGroups.contains(filterValue)) {
      return ageGroupFilterPillLabel(filterValue);
    }
    if (filterSexes.contains(filterValue)) {
      return sexFilterPillLabel(filterValue, ageGroupFilter: ageGroupFilter);
    }
    switch (filterValue) {
      case 'All Seasons':
        return S.of('season_all');
      case 'Summer':
        return S.of('season_summer');
      case 'Winter':
        return S.of('season_winter');
      case 'Sport':
        return S.of('season_sport');
      case 'All Year':
        return S.of('season_all_year');
      case 'All Categories':
        return S.of('category_all');
      case 'Clothes':
        return S.of('category_clothes');
      case 'Shoes':
        return S.of('category_shoes');
      case 'Lingery':
        return S.of('category_lingery');
      case 'Sac':
        return S.of('category_bags');
      case 'Scarf':
        return S.of('category_scarves');
      default:
        return filterValue;
    }
  }

  /// Short, friendly labels for active filter chips in the UI.
  static String filterDisplayLabel(String filterValue, {String ageGroupFilter = 'All'}) {
    if (filterAgeGroups.contains(filterValue) || filterSexes.contains(filterValue)) {
      return filterPillLabel(filterValue, ageGroupFilter: ageGroupFilter);
    }
    switch (filterValue) {
      case 'Sac':
        return S.of('category_bags');
      case 'Scarf':
        return S.of('category_scarves');
      case 'All Seasons':
        return S.of('filter_all_seasons');
      case 'All Year':
        return S.of('filter_all_year');
      case 'All Categories':
        return S.of('filter_all_categories');
      default:
        return filterPillLabel(filterValue);
    }
  }

  static String normalizeType(String? raw) {
    if (isNotDetermined(raw)) return notDetermined;
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'sacs') return 'sac';
    return v;
  }

  static String normalizeSeason(String? raw) {
    if (isNotDetermined(raw)) return notDetermined;
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'all seasons' || v == 'all_seasons' || v == 'allseasons') {
      return 'all_seasons';
    }
    return v;
  }

  static bool isAllSeasonsProduct(String? stored) => normalizeSeason(stored) == 'all_seasons';

  /// All Seasons → everything. Summer → summer + all_seasons items, etc.
  static bool matchesSeason(String? stored, String filterLabel) {
    if (filterLabel == 'All Seasons') return true;
    if (isNotDetermined(stored)) return false;
    final itemSeason = normalizeSeason(stored);
    if (filterLabel == 'All Year') return itemSeason == 'all_seasons';
    final filter = filterLabel.toLowerCase();
    return itemSeason == filter || itemSeason == 'all_seasons';
  }

  static bool matchesAgeGroupFilter(Map<String, dynamic> data, String filterLabel) {
    if (filterLabel == 'All') return true;
    final audience = audienceFrom(data);
    if (isNotDetermined(audience.ageGroup)) return false;
    final target = switch (filterLabel) {
      'Kids' => 'kids',
      'Baby' => 'baby',
      'Adult' => 'adult',
      _ => '',
    };
    return audience.ageGroup == target;
  }

  static bool matchesSexFilter(Map<String, dynamic> data, String filterLabel) {
    if (filterLabel == 'All') return true;
    final audience = audienceFrom(data);
    if (isNotDetermined(audience.sex)) return false;
    if (audience.legacyChildrenOnly && audience.ageGroup == 'kids') return true;
    final target = filterLabel == 'Male' ? 'male' : 'female';
    return audience.sex == target;
  }

  /// All Categories → everything. Clothes → clothes only, etc.
  static bool matchesType(String? stored, String filterLabel) {
    if (filterLabel == 'All Categories') return true;
    if (isNotDetermined(stored)) return false;
    return normalizeType(stored) == normalizeType(filterLabel);
  }

  static bool matchesFilters({
    required Map<String, dynamic> data,
    required String seasonFilter,
    required String ageGroupFilter,
    required String sexFilter,
    required String categoryFilter,
    bool saleOnly = false,
    double priceMin = priceFilterFloor,
    double priceMax = priceFilterCeiling,
  }) {
    if (saleOnly && !hasActiveSale(data)) return false;
    if (!matchesPriceRange(data, min: priceMin, max: priceMax)) return false;
    return matchesSeason(data['season']?.toString(), seasonFilter) &&
        matchesAgeGroupFilter(data, ageGroupFilter) &&
        matchesSexFilter(data, sexFilter) &&
        matchesType(data['type']?.toString(), categoryFilter);
  }

  /// Matches product title or ID only (title substring; ID prefix).
  static bool matchesSearch({
    required Map<String, dynamic> data,
    required String docId,
    required String query,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final terms = normalized.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
    final productId = productIdFrom(data, docId).toLowerCase();
    final documentId = docId.toLowerCase();
    final title = titleFrom(data).toLowerCase();

    bool idMatches(String term) =>
        productId.startsWith(term) || documentId.startsWith(term);

    if (terms.length == 1) {
      final term = terms.first;
      if (looksLikeIdPrefix(term)) return idMatches(term);
      return title.contains(term);
    }

    for (final term in terms) {
      if (looksLikeIdPrefix(term)) {
        if (!idMatches(term)) return false;
      } else if (!title.contains(term)) {
        return false;
      }
    }
    return true;
  }

  static String productIdFrom(Map<String, dynamic> data, String docId) {
    final raw = data['productId'] ?? data['id'] ?? docId;
    return raw is String ? raw : raw.toString();
  }

  static String titleFrom(Map<String, dynamic> data) {
    final title = data['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
    return (data['description'] ?? S.of('untitled_item')).toString();
  }

  static String descriptionFrom(Map<String, dynamic> data) {
    return (data['description'] ?? '').toString();
  }

  static String sizeFrom(Map<String, dynamic> data) {
    final stored = (data['size'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;
    final inventory = variantInventoryFrom(data);
    if (VariantInventory.hasAnyEntries(inventory)) {
      return encodeSizes(VariantInventory.uniqueSizes(inventory));
    }
    return '';
  }

  static String colorsFrom(Map<String, dynamic> data) {
    final stored = (data['colors'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;
    final inventory = variantInventoryFrom(data);
    if (VariantInventory.hasAnyEntries(inventory)) {
      return encodeColors(VariantInventory.uniqueColors(inventory));
    }
    return '';
  }

  static VariantInventoryMap variantInventoryFrom(Map<String, dynamic> data) {
    return VariantInventory.fromFirestore(data['variantInventory']);
  }

  /// Public product photos (never includes barcode).
  static List<String> productImageUrlsFrom(Map<String, dynamic> data) {
    final urls = data['imageUrls'];
    if (urls is List) {
      final list = urls
          .map((e) => e.toString().trim())
          .where((u) => u.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    final legacy = data['imageUrl'] ?? data['image_url'] ?? data['image'] ?? '';
    final single = legacy.toString().trim();
    return single.isEmpty ? const [] : [single];
  }

  static String primaryImageUrl(Map<String, dynamic> data) {
    final urls = productImageUrlsFrom(data);
    return urls.isEmpty ? '' : urls.first;
  }

  static String? barcodeImageUrlFrom(Map<String, dynamic> data) {
    final raw = data['barcodeImageUrl']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static bool hasBarcodeImage(Map<String, dynamic> data) => barcodeImageUrlFrom(data) != null;

  static Map<String, dynamic> imageFieldsForWrite({
    required List<String> imageUrls,
    String? barcodeImageUrl,
  }) {
    final urls = imageUrls.where((u) => u.trim().isNotEmpty).toList();
    return {
      'imageUrls': urls,
      if (urls.isNotEmpty) 'imageUrl': urls.first,
      if (barcodeImageUrl != null && barcodeImageUrl.trim().isNotEmpty)
        'barcodeImageUrl': barcodeImageUrl.trim(),
    };
  }

  /// Delimiter for size/color lists — keeps labels like `1-5 years` intact.
  static const listFieldDelimiter = ' | ';

  /// Parses a stored list field (sizes, colors). Supports ` | ` and legacy comma-separated values.
  static List<String> listFromField(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return [];

    if (value.contains(listFieldDelimiter)) {
      return _uniqueListItems(value.split(listFieldDelimiter));
    }

    if (value.contains(',')) {
      return _uniqueListItems(value.split(','));
    }

    if (value.contains(';')) {
      return _uniqueListItems(value.split(';'));
    }

    return [value];
  }

  static List<String> _uniqueListItems(Iterable<String> parts) {
    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      final item = part.trim();
      if (item.isEmpty) continue;
      final key = item.toLowerCase();
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  static String encodeListField(Iterable<String> items) {
    return items.map((s) => s.trim()).where((s) => s.isNotEmpty).join(listFieldDelimiter);
  }

  static List<String> sizesFromField(String? raw) => listFromField(raw);

  static String encodeSizes(Iterable<String> sizes) => encodeListField(sizes);

  static List<String> colorsFromField(String? raw) {
    if (isNotDetermined(raw)) return const [];
    return listFromField(raw);
  }

  static String encodeColors(Iterable<String> colors) => encodeListField(colors);

  /// Sizes shown in cart / detail; falls back to one-size label when empty.
  static List<String> sizesForSelection(String? raw) {
    final sizes = sizesFromField(raw);
    if (sizes.isEmpty) return [S.of('one_size')];
    return sizes;
  }

  static String sizesDisplayLabel(String? raw, {int maxShown = 4}) {
    final sizes = sizesFromField(raw);
    if (sizes.isEmpty) return '';
    if (sizes.length <= maxShown) return sizes.join(' · ');
    return '${sizes.take(maxShown - 1).join(' · ')} +${sizes.length - (maxShown - 1)}';
  }

  static String colorsDisplayLabel(String? raw, {int maxShown = 4}) {
    if (isNotDetermined(raw)) return notDeterminedLabel();
    final colors = colorsFromField(raw);
    if (colors.isEmpty) return '';
    final labels = colors.map(colorDisplayName);
    if (colors.length <= maxShown) return labels.join(' · ');
    return '${labels.take(maxShown - 1).join(' · ')} +${colors.length - (maxShown - 1)}';
  }

  static String colorDisplayName(String raw) => S.colorName(raw);

  static List<String> colorsForSelection(String? raw) => colorsFromField(raw);

  static double effectivePrice(Map<String, dynamic> data) {
    final sold = soldPriceFrom(data);
    final price = priceFrom(data);
    if (sold != null && sold < price) return sold;
    return price;
  }

  static int favoriteCountFrom(Map<String, dynamic> data) {
    final raw = data['favoriteCount'] ?? data['favorites'] ?? 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  static int viewCountFrom(Map<String, dynamic> data) {
    final raw = data['viewCount'] ?? 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  static const lowStockThreshold = 5;

  static List<String> get branchIds =>
      StoreConfig.locations.map((location) => location.id).toList();

  static String branchLabel(String branchId) =>
      StoreConfig.branchLabel(branchId, isArabic: S.isAr);

  static int? optionalIntFrom(dynamic raw) => _optionalIntFrom(raw);

  static int? _optionalIntFrom(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  /// Per-branch totals. Prefers `variantInventory`, then legacy `branchStock`.
  static Map<String, int?> branchStockFrom(Map<String, dynamic> data) {
    final inventory = variantInventoryFrom(data);
    if (VariantInventory.hasAnyEntries(inventory)) {
      return VariantInventory.branchTotals(inventory);
    }

    final result = <String, int?>{for (final id in branchIds) id: null};
    final raw = data['branchStock'];
    if (raw is Map) {
      for (final id in branchIds) {
        result[id] = _optionalIntFrom(raw[id]);
      }
      return result;
    }

    final legacy = _optionalIntFrom(data['stockQty']);
    if (legacy != null) result['tripoli'] = legacy;
    return result;
  }

  static int? totalStockFrom(Map<String, dynamic> data) => stockQtyFrom(data);

  static ({
    Map<String, dynamic>? variantInventory,
    String size,
    String colors,
    int? stockQty,
  }) resolveVariantInventoryForSave(VariantInventoryMap inventory) {
    if (!VariantInventory.hasAnyEntries(inventory)) {
      return (variantInventory: null, size: '', colors: '', stockQty: null);
    }
    final sizes = VariantInventory.uniqueSizes(inventory);
    final colors = VariantInventory.uniqueColors(inventory);
    final firestore = VariantInventory.toFirestore(inventory);
    return (
      variantInventory: firestore.isEmpty ? null : firestore,
      size: encodeSizes(sizes),
      colors: encodeColors(colors),
      stockQty: VariantInventory.totalQty(inventory),
    );
  }

  static Map<String, dynamic> variantInventoryFieldsForWrite(VariantInventoryMap inventory) {
    final resolved = resolveVariantInventoryForSave(inventory);
    if (resolved.variantInventory == null) {
      return {
        'variantInventory': const <String, dynamic>{},
        'size': '',
        'colors': '',
        'stockQty': 0,
        'branchStock': const <String, dynamic>{},
      };
    }
    return {
      'variantInventory': resolved.variantInventory,
      'size': resolved.size,
      'colors': resolved.colors,
      'stockQty': resolved.stockQty,
      'branchStock': const <String, dynamic>{},
    };
  }

  /// @deprecated Use [resolveVariantInventoryForSave].
  static ({Map<String, int>? branchStock, int? stockQty}) resolveBranchStockForSave(
    Map<String, int?> stock,
  ) {
    final branchStock = <String, int>{};
    for (final id in branchIds) {
      final qty = stock[id];
      if (qty != null) branchStock[id] = qty;
    }
    if (branchStock.isEmpty) return (branchStock: null, stockQty: null);
    final total = branchStock.values.fold<int>(0, (sum, qty) => sum + qty);
    return (branchStock: branchStock, stockQty: total);
  }

  static String branchStockDisplayLabel(int? qty) {
    if (qty == null) return S.of('branch_stock_not_set');
    return S.fmt('branch_stock_available', {'count': '$qty'});
  }

  static int? stockQtyFrom(Map<String, dynamic> data) {
    final inventory = variantInventoryFrom(data);
    if (VariantInventory.hasAnyEntries(inventory)) {
      return VariantInventory.totalQty(inventory);
    }

    final stored = _optionalIntFrom(data['stockQty']);
    if (stored != null) return stored;

    final raw = data['branchStock'];
    if (raw is! Map) return null;

    final values = branchIds.map((id) => _optionalIntFrom(raw[id])).whereType<int>();
    if (values.isEmpty) return null;
    return values.fold<int>(0, (sum, qty) => sum + qty);
  }

  static List<String> variantInventorySummaryLines(Map<String, dynamic> data) {
    final inventory = variantInventoryFrom(data);
    if (!VariantInventory.hasAnyEntries(inventory)) return const [];

    final lines = <String>[];
    for (final branch in StoreConfig.locations) {
      final colors = inventory[branch.id];
      if (colors == null || colors.isEmpty) continue;
      final parts = <String>[];
      for (final colorEntry in colors.entries) {
        final sizeParts = colorEntry.value.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        parts.add('${colorDisplayName(colorEntry.key)} ($sizeParts)');
      }
      lines.add('${branchLabel(branch.id)} — ${parts.join(' · ')}');
    }
    return lines;
  }

  static bool isLowStockAlert(int? stockQty, {bool sold = false}) {
    if (sold) return true;
    if (stockQty == null) return false;
    return stockQty <= lowStockThreshold;
  }

  static double priceFrom(Map<String, dynamic> data) => (data['price'] ?? 0.0).toDouble();

  static int? discountPercentFrom(Map<String, dynamic> data) {
    final raw = data['discountPercent'];
    if (raw != null) {
      final parsed = raw is int ? raw : int.tryParse(raw.toString());
      if (isValidDiscountPercent(parsed)) return parsed;
    }
    final price = priceFrom(data);
    final legacySold = legacySoldPriceFrom(data);
    if (legacySold != null && price > 0 && legacySold < price) {
      return percentFromPrices(price, legacySold);
    }
    return null;
  }

  /// Parses staff input like `20` or `20%`. Returns null when empty.
  static int? parseDiscountPercent(String text) {
    final cleaned = text.trim().replaceAll('%', '').trim();
    if (cleaned.isEmpty) return null;
    final parsed = int.tryParse(cleaned);
    return isValidDiscountPercent(parsed) ? parsed : null;
  }

  static bool isValidDiscountPercent(int? percent) => percent != null && percent > 0 && percent < 100;

  static int? percentFromPrices(double price, double soldPrice) {
    if (price <= 0 || soldPrice <= 0 || soldPrice >= price) return null;
    final percent = ((1 - soldPrice / price) * 100).round();
    return isValidDiscountPercent(percent) ? percent : null;
  }

  static double soldPriceFromPercent(double price, int discountPercent) {
    final discounted = price * (1 - discountPercent / 100);
    return (discounted * 100).roundToDouble() / 100;
  }

  /// Resolves sale fields from optional sale price and/or discount percent input.
  static ({double? soldPrice, int? discountPercent, String? errorKey}) resolveSalePricing({
    required double regularPrice,
    required String salePriceText,
    required String discountPercentText,
  }) {
    final saleText = salePriceText.trim();
    final discountText = discountPercentText.trim();
    final saleParsed = saleText.isEmpty ? null : double.tryParse(saleText);
    final discountParsed = parseDiscountPercent(discountText);

    if (saleText.isEmpty && discountText.isEmpty) {
      return (soldPrice: null, discountPercent: null, errorKey: null);
    }

    if (saleText.isNotEmpty && (saleParsed == null || saleParsed <= 0)) {
      return (soldPrice: null, discountPercent: null, errorKey: 'sale_price_invalid');
    }
    if (discountText.isNotEmpty && discountParsed == null) {
      return (soldPrice: null, discountPercent: null, errorKey: 'discount_percent_invalid');
    }
    if (saleParsed != null && saleParsed >= regularPrice) {
      return (soldPrice: null, discountPercent: null, errorKey: 'sale_price_invalid');
    }

    if (discountParsed != null && saleParsed == null) {
      return (
        soldPrice: soldPriceFromPercent(regularPrice, discountParsed),
        discountPercent: discountParsed,
        errorKey: null,
      );
    }

    if (saleParsed != null && discountParsed == null) {
      final percent = percentFromPrices(regularPrice, saleParsed);
      if (percent == null) {
        return (soldPrice: null, discountPercent: null, errorKey: 'sale_price_invalid');
      }
      return (soldPrice: saleParsed, discountPercent: percent, errorKey: null);
    }

    // Both provided — sale price is source of truth; percent is derived.
    final percent = percentFromPrices(regularPrice, saleParsed!);
    if (percent == null) {
      return (soldPrice: null, discountPercent: null, errorKey: 'sale_price_invalid');
    }
    return (soldPrice: saleParsed, discountPercent: percent, errorKey: null);
  }

  static double? legacySoldPriceFrom(Map<String, dynamic> data) {
    final raw = data['soldPrice'] ?? data['salePrice'];
    if (raw == null) return null;
    final parsed = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static double? soldPriceFrom(Map<String, dynamic> data) {
    final price = priceFrom(data);
    final percent = discountPercentFrom(data);
    if (percent != null) return soldPriceFromPercent(price, percent);
    return legacySoldPriceFrom(data);
  }

  static bool hasActiveSale(Map<String, dynamic> data) {
    final sold = soldPriceFrom(data);
    final price = priceFrom(data);
    return sold != null && sold < price;
  }

  static bool computeOnSale(double price, double? soldPrice) {
    return soldPrice != null && soldPrice > 0 && soldPrice < price;
  }

  static const newProductMaxAgeDays = 10;
  static const oldProductMonths = 6;

  static DateTime? createdAtFrom(Map<String, dynamic> data) {
    final raw = data['created_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    try {
      return (raw as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  /// Listed within the last [newProductMaxAgeDays] days (exclusive of day 10+).
  static bool isNewlyAdded(Map<String, dynamic> data, {DateTime? now}) {
    final created = createdAtFrom(data);
    if (created == null) return false;
    final ref = now ?? DateTime.now();
    return ref.difference(created).inDays < newProductMaxAgeDays;
  }

  static bool hasPendingEdit(Map<String, dynamic> data) => data['editPending'] == true;

  static bool needsApproval(Map<String, dynamic> data) {
    if (data['needsApproval'] == true) return true;
    return data['approved'] == false;
  }

  static Map<String, dynamic>? pendingEditFrom(Map<String, dynamic> data) {
    final raw = data['pendingEdit'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Human-readable lines for the approval queue (new items or pending edits).
  static List<String> approvalChangeLines(Map<String, dynamic> data) {
    final pending = pendingEditFrom(data);
    if (pending != null && pending.isNotEmpty) {
      return _pendingDiffLines(data, pending);
    }
    return _newItemSummaryLines(data);
  }

  static List<String> _newItemSummaryLines(Map<String, dynamic> data) {
    final lines = <String>[
      _approvalSetLine('field_title', titleFrom(data)),
      _approvalSetLine('field_price', '\$${priceFrom(data).toStringAsFixed(2)}'),
      _approvalSetLine('field_season', label(normalizeSeason(data['season']?.toString()))),
      _approvalSetLine('field_category', label(normalizeType(data['type']?.toString()))),
      _approvalSetLine('field_age_group', ageGroupLabel(normalizeAgeGroup(data['ageGroup']?.toString()))),
      _approvalSetLine('field_sex', sexFormLabel(ageGroup: normalizeAgeGroup(data['ageGroup']?.toString()), sex: normalizeSex(data['sex']?.toString()))),
    ];
    final sizes = sizesFromField(sizeFrom(data));
    if (sizes.isNotEmpty) {
      lines.add(_approvalSetLine('size', sizes.join(' · ')));
    }
    final colorLabel = colorsDisplayLabel(colorsFrom(data));
    if (colorLabel.isNotEmpty) {
      lines.add(_approvalSetLine('color', colorLabel));
    }
    final stock = stockQtyFrom(data);
    if (stock != null) {
      lines.add(_approvalSetLine('field_branch_stock', '$stock'));
    }
    final variantLines = variantInventorySummaryLines(data);
    for (final line in variantLines) {
      lines.add(line);
    }
    final photos = productImageUrlsFrom(data).length;
    if (photos > 0) {
      lines.add(S.fmt('approval_photo_count', {'count': '$photos'}));
    }
    return lines;
  }

  static List<String> _pendingDiffLines(Map<String, dynamic> live, Map<String, dynamic> pending) {
    final lines = <String>[];
    void compareStr(String key, String labelKey, {String Function(dynamic)? format}) {
      if (!pending.containsKey(key)) return;
      final next = pending[key];
      if (next == null) {
        final prev = live[key];
        if (prev != null && prev.toString().trim().isNotEmpty) {
          lines.add(S.fmt('approval_change_cleared', {'field': S.of(labelKey)}));
        }
        return;
      }
      final fmt = format ?? _plainStr;
      final from = fmt(live[key]);
      final to = fmt(next);
      if (from == to) return;
      lines.add(S.fmt('approval_change_line', {'field': S.of(labelKey), 'from': from, 'to': to}));
    }

    compareStr('title', 'field_title');
    compareStr('description', 'field_description');
    compareStr('price', 'field_price', format: (v) => '\$${_num(v).toStringAsFixed(2)}');
    compareStr('soldPrice', 'field_sale_price', format: (v) => v == null ? '—' : '\$${_num(v).toStringAsFixed(2)}');
    compareStr('discountPercent', 'field_discount_percent', format: (v) => v == null ? '—' : '${_int(v)}%');
    compareStr('size', 'size', format: (v) => sizesDisplayLabel(v?.toString()));
    compareStr('colors', 'color', format: (v) => colorsDisplayLabel(v?.toString()));
    compareStr('season', 'field_season', format: (v) => label(normalizeSeason(v?.toString())));
    compareStr('ageGroup', 'field_age_group', format: (v) => ageGroupLabel(normalizeAgeGroup(v?.toString())));
    compareStr('sex', 'field_sex', format: (v) {
      final age = normalizeAgeGroup(pending['ageGroup']?.toString() ?? live['ageGroup']?.toString());
      return sexFormLabel(ageGroup: age, sex: normalizeSex(v?.toString()));
    });
    compareStr('type', 'field_category', format: (v) => label(normalizeType(v?.toString())));
    compareStr('stockQty', 'field_branch_stock', format: (v) => v == null ? '—' : '${_int(v)}');

    if (pending.containsKey('imageUrls')) {
      final oldCount = productImageUrlsFrom(live).length;
      final raw = pending['imageUrls'];
      final newCount = raw is List ? raw.length : oldCount;
      if (oldCount != newCount) {
        lines.add(S.fmt('approval_change_line', {
          'field': S.of('field_photos'),
          'from': '$oldCount',
          'to': '$newCount',
        }));
      }
    }

    if (lines.isEmpty) {
      lines.add(S.of('approval_no_visible_changes'));
    }
    return lines;
  }

  static String _approvalSetLine(String labelKey, String value) {
    return S.fmt('approval_change_set', {'field': S.of(labelKey), 'value': value});
  }

  static String _plainStr(dynamic value) => (value ?? '').toString().trim();

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? primaryImageUrlOrNull(Map<String, dynamic> data) {
    final urls = productImageUrlsFrom(data);
    if (urls.isEmpty) return null;
    return urls.first;
  }

  /// Listed more than [oldProductMonths] months ago (admin inventory hint).
  static bool isOlderThanSixMonths(Map<String, dynamic> data, {DateTime? now}) {
    final created = createdAtFrom(data);
    if (created == null) return false;
    final ref = now ?? DateTime.now();
    final cutoff = DateTime(ref.year, ref.month - oldProductMonths, ref.day);
    return created.isBefore(cutoff);
  }

  /// Firestore `whereIn` values for a season filter chip (includes all-season items).
  static List<String> seasonsForFilter(String filterLabel) {
    if (filterLabel == 'All Seasons') return const [];
    if (filterLabel == 'All Year') return const ['all_seasons', 'all seasons'];
    return [filterLabel.toLowerCase(), 'all_seasons', 'all seasons'];
  }

  /// Lowercase tokens for Firestore `arrayContains` search (max 30).
  static List<String> buildSearchTokens({
    required String title,
    required String description,
    required String productId,
    required String size,
    required String colors,
    required String season,
    required String ageGroup,
    required String sex,
    required String type,
  }) {
    final parts = <String>[
      title,
      description,
      productId,
      size,
      colors,
      normalizeSeason(season),
      normalizeAgeGroup(ageGroup),
      normalizeSex(sex),
      sexFormLabel(ageGroup: ageGroup, sex: sex),
      normalizeType(type),
      ...sizesFromField(size),
      ...colorsFromField(colors),
    ];

    final tokens = <String>{productId.trim().toLowerCase()};
    for (final part in parts) {
      for (final match in RegExp(r'[\w\u0600-\u06FF]+').allMatches(part.toLowerCase())) {
        final token = match.group(0)!;
        if (token.length >= 2) tokens.add(token);
      }
    }

    final list = tokens.where((t) => t.isNotEmpty).toList()..sort();
    if (list.length <= 30) return list;
    return list.sublist(0, 30);
  }

  /// Denormalized fields written on product create/update for server queries.
  static Map<String, dynamic> searchIndexFields({
    required String title,
    required String description,
    required String productId,
    required String size,
    required String colors,
    required double price,
    double? soldPrice,
    required String season,
    required String ageGroup,
    required String sex,
    required String type,
  }) {
    return {
      'searchPrefix': title.trim().toLowerCase(),
      'searchIdPrefix': productId.trim().toLowerCase(),
      'searchTokens': buildSearchTokens(
        title: title,
        description: description,
        productId: productId,
        size: size,
        colors: colors,
        season: season,
        ageGroup: ageGroup,
        sex: sex,
        type: type,
      ),
      'onSale': computeOnSale(price, soldPrice),
    };
  }
}
