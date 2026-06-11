import '../l10n/app_strings.dart';

/// Shared product categories, filters, and field helpers.
class ProductCatalog {
  static const seasons = ['summer', 'winter', 'sport', 'all seasons'];
  static const genders = ['woman', 'man', 'children'];
  static const types = ['clothes', 'shoes', 'lingery', 'sac', 'scarf'];

  static const filterSeasons = ['All Seasons', 'Summer', 'Winter', 'Sport'];
  static const filterGenders = ['All', 'Woman', 'Man', 'Children'];
  static const filterCategories = ['All Categories', 'Clothes', 'Shoes', 'Lingery', 'Sac', 'Scarf'];

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
        return S.of('catalog_woman');
      case 'man':
        return S.of('catalog_man');
      case 'children':
        return S.of('catalog_children');
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

  static String filterPillLabel(String filterValue) {
    switch (filterValue) {
      case 'All':
        return S.of('gender_all');
      case 'Woman':
        return S.of('gender_women');
      case 'Man':
        return S.of('gender_men');
      case 'Children':
        return S.of('gender_kids');
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
  static String filterDisplayLabel(String filterValue) {
    switch (filterValue) {
      case 'Woman':
        return S.of('gender_women');
      case 'Man':
        return S.of('gender_men');
      case 'Children':
        return S.of('gender_kids');
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

  static String normalizeGender(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v == 'female' || v == 'woman') return 'woman';
    if (v == 'male' || v == 'man') return 'man';
    if (v == 'children' || v == 'child') return 'children';
    return v;
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

  static bool matchesGender(String? stored, String filterLabel) {
    if (filterLabel == 'All') return true;
    return normalizeGender(stored) == normalizeGender(filterLabel);
  }

  /// All Categories → everything. Clothes → clothes only, etc.
  static bool matchesType(String? stored, String filterLabel) {
    if (filterLabel == 'All Categories') return true;
    return normalizeType(stored) == normalizeType(filterLabel);
  }

  static bool matchesFilters({
    required Map<String, dynamic> data,
    required String seasonFilter,
    required String genderFilter,
    required String categoryFilter,
    bool saleOnly = false,
  }) {
    if (saleOnly && !hasActiveSale(data)) return false;
    return matchesSeason(data['season']?.toString(), seasonFilter) &&
        matchesGender(data['sex']?.toString(), genderFilter) &&
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
    final gender = normalizeGender(data['sex']?.toString());
    final type = normalizeType(data['type']?.toString());

    final haystack = [
      titleFrom(data),
      descriptionFrom(data),
      productIdFrom(data, docId),
      docId,
      sizeFrom(data),
      season,
      gender,
      type,
      localizedCatalogLabel(season),
      localizedCatalogLabel(gender),
      localizedCatalogLabel(type),
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

  /// Parses stored size text into a unique list (e.g. `41, 42, 43` or `S, M, L`).
  static List<String> sizesFromField(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return [];

    final normalized = value.replaceAll(RegExp(r'[/;|]'), ',');
    if (normalized.contains(',')) {
      return _uniqueSizes(normalized.split(','));
    }

    final spaceParts = value.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (spaceParts.length > 1) return _uniqueSizes(spaceParts);

    return [value];
  }

  static List<String> _uniqueSizes(Iterable<String> parts) {
    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      final size = part.trim();
      if (size.isEmpty) continue;
      final key = size.toLowerCase();
      if (seen.add(key)) result.add(size);
    }
    return result;
  }

  /// Encodes size chips for Firestore (`41, 42, 43`).
  static String encodeSizes(Iterable<String> sizes) {
    return sizesFromField(sizes.join(', ')).join(', ');
  }

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
    required String season,
    required String gender,
    required String type,
  }) {
    final parts = <String>[
      title,
      description,
      productId,
      size,
      normalizeSeason(season),
      normalizeGender(gender),
      normalizeType(type),
      ...sizesFromField(size),
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
    required double price,
    double? soldPrice,
    required String season,
    required String gender,
    required String type,
  }) {
    return {
      'searchPrefix': title.trim().toLowerCase(),
      'searchTokens': buildSearchTokens(
        title: title,
        description: description,
        productId: productId,
        size: size,
        season: season,
        gender: gender,
        type: type,
      ),
      'onSale': computeOnSale(price, soldPrice),
    };
  }
}
