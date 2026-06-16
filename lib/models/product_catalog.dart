import '../l10n/app_strings.dart';

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

  /// True when the search term should use product-ID lookup (contains a digit).
  static bool isIdSearchTerm(String token) {
    final trimmed = token.trim();
    if (!isValidProductId(trimmed)) return false;
    return RegExp(r'\d').hasMatch(trimmed);
  }

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

  /// Matches title, description, product ID, size, and catalog labels.
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

    if (terms.length == 1 && isIdSearchTerm(terms.first)) {
      final term = terms.first;
      return productId.contains(term) || documentId.contains(term);
    }

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
