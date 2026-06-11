import '../l10n/app_strings.dart';

/// Shared product categories, filters, and field helpers.
class ProductCatalog {
  static const seasons = ['summer', 'winter', 'sport', 'all seasons'];
  static const ageGroups = ['kids', 'adult'];
  static const sexes = ['female', 'male'];
  static const types = ['clothes', 'shoes', 'lingery', 'sac', 'scarf'];

  static const filterSeasons = ['All Seasons', 'Summer', 'Winter', 'Sport'];
  static const filterAgeGroups = ['All', 'Kids', 'Adult'];
  static const filterSexes = ['All', 'Female', 'Male'];
  static const filterCategories = ['All Categories', 'Clothes', 'Shoes', 'Lingery', 'Sac', 'Scarf'];

  static final RegExp _productIdPattern = RegExp(r'^[A-Za-z0-9]+$');

  static bool isValidProductId(String id) {
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= 64 && _productIdPattern.hasMatch(trimmed);
  }

  static String normalizeAgeGroup(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'kids' || v == 'kid' || v == 'children' || v == 'child') return 'kids';
    return 'adult';
  }

  static String normalizeSex(String? raw) {
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
    switch (normalizeAgeGroup(ageGroup)) {
      case 'kids':
        return S.of('age_kids');
      default:
        return S.of('age_adult');
    }
  }

  static String sexFormLabel({required String ageGroup, required String sex}) {
    final isKids = normalizeAgeGroup(ageGroup) == 'kids';
    if (normalizeSex(sex) == 'male') {
      return isKids ? S.of('sex_boy') : S.of('sex_man');
    }
    return isKids ? S.of('sex_girl') : S.of('sex_woman');
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
        if (ageGroupFilter == 'Kids') return S.of('sex_girl');
        if (ageGroupFilter == 'Adult') return S.of('sex_woman');
        return S.of('filter_sex_female');
      case 'Male':
        if (ageGroupFilter == 'Kids') return S.of('sex_boy');
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
    switch (value.toLowerCase()) {
      case 'summer':
        return S.of('catalog_summer');
      case 'winter':
        return S.of('catalog_winter');
      case 'sport':
        return S.of('catalog_sport');
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
      case 'All Categories':
        return S.of('filter_all_categories');
      default:
        return filterPillLabel(filterValue);
    }
  }

  static String normalizeType(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'sacs') return 'sac';
    return v;
  }

  static String normalizeSeason(String? raw) => (raw ?? '').toLowerCase().trim();

  /// All Seasons → everything. Summer → summer + all seasons items, etc.
  static bool matchesSeason(String? stored, String filterLabel) {
    if (filterLabel == 'All Seasons') return true;
    final itemSeason = normalizeSeason(stored);
    final filter = filterLabel.toLowerCase();
    return itemSeason == filter || itemSeason == 'all seasons';
  }

  static bool matchesAgeGroupFilter(Map<String, dynamic> data, String filterLabel) {
    if (filterLabel == 'All') return true;
    final audience = audienceFrom(data);
    final target = filterLabel == 'Kids' ? 'kids' : 'adult';
    return audience.ageGroup == target;
  }

  static bool matchesSexFilter(Map<String, dynamic> data, String filterLabel) {
    if (filterLabel == 'All') return true;
    final audience = audienceFrom(data);
    if (audience.legacyChildrenOnly && audience.ageGroup == 'kids') return true;
    final target = filterLabel == 'Male' ? 'male' : 'female';
    return audience.sex == target;
  }

  /// All Categories → everything. Clothes → clothes only, etc.
  static bool matchesType(String? stored, String filterLabel) {
    if (filterLabel == 'All Categories') return true;
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

  /// Matches title, description, product ID, size, and catalog labels.
  static bool matchesSearch({
    required Map<String, dynamic> data,
    required String docId,
    required String query,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final season = normalizeSeason(data['season']?.toString());
    final audience = audienceFrom(data);
    final type = normalizeType(data['type']?.toString());

    final haystack = [
      titleFrom(data),
      descriptionFrom(data),
      productIdFrom(data, docId),
      docId,
      sizeFrom(data),
      colorsFrom(data),
      season,
      audience.ageGroup,
      audience.sex,
      type,
      localizedCatalogLabel(season),
      ageGroupLabel(audience.ageGroup),
      sexFormLabel(ageGroup: audience.ageGroup, sex: audience.sex),
      localizedCatalogLabel(type),
      ...colorsFromField(colorsFrom(data)),
    ].join(' ').toLowerCase();

    final tokens = normalized.split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
    return tokens.every(haystack.contains);
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
    return (data['size'] ?? '').toString();
  }

  static String colorsFrom(Map<String, dynamic> data) {
    return (data['colors'] ?? '').toString();
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

  static List<String> colorsFromField(String? raw) => listFromField(raw);

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
    final colors = colorsFromField(raw);
    if (colors.isEmpty) return '';
    if (colors.length <= maxShown) return colors.join(' · ');
    return '${colors.take(maxShown - 1).join(' · ')} +${colors.length - (maxShown - 1)}';
  }

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

  static int? stockQtyFrom(Map<String, dynamic> data) {
    final raw = data['stockQty'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static bool isLowStockAlert(int? stockQty, {bool sold = false}) {
    if (sold) return true;
    if (stockQty == null) return false;
    return stockQty <= lowStockThreshold;
  }

  static double priceFrom(Map<String, dynamic> data) => (data['price'] ?? 0.0).toDouble();

  static double? soldPriceFrom(Map<String, dynamic> data) {
    final raw = data['soldPrice'] ?? data['salePrice'];
    if (raw == null) return null;
    final parsed = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static bool hasActiveSale(Map<String, dynamic> data) {
    final sold = soldPriceFrom(data);
    final price = priceFrom(data);
    return sold != null && sold < price;
  }

  static bool computeOnSale(double price, double? soldPrice) {
    return soldPrice != null && soldPrice > 0 && soldPrice < price;
  }

  /// Firestore `whereIn` values for a season filter chip (includes "all seasons" items).
  static List<String> seasonsForFilter(String filterLabel) {
    if (filterLabel == 'All Seasons') return const [];
    return [filterLabel.toLowerCase(), 'all seasons'];
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

    final tokens = <String>{};
    for (final part in parts) {
      for (final match in RegExp(r'[\w\u0600-\u06FF]+').allMatches(part.toLowerCase())) {
        final token = match.group(0)!;
        if (token.length >= 2) tokens.add(token);
      }
    }

    final list = tokens.toList()..sort();
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
