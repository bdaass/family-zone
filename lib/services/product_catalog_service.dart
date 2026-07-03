import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/catalog_sort.dart';
import '../models/product_catalog.dart';
import '../utils/product_permissions.dart';
import '../utils/web_platform.dart';
import 'catalog_migration_service.dart';

/// Query parameters for a paginated catalog fetch.
class CatalogQuery {
  const CatalogQuery({
    required this.staffMode,
    this.seasonFilter = 'All Seasons',
    this.ageGroupFilter = 'All',
    this.sexFilter = 'All',
    this.categoryFilter = 'All Categories',
    this.saleOnly = false,
    this.searchQuery = '',
    this.priceMin = ProductCatalog.priceFilterFloor,
    this.priceMax = ProductCatalog.priceFilterCeiling,
    this.sort = CatalogSort.newest,
  });

  final bool staffMode;
  final String seasonFilter;
  final String ageGroupFilter;
  final String sexFilter;
  final String categoryFilter;
  final bool saleOnly;
  final String searchQuery;
  final double priceMin;
  final double priceMax;
  final CatalogSort sort;

  @override
  bool operator ==(Object other) {
    return other is CatalogQuery &&
        staffMode == other.staffMode &&
        seasonFilter == other.seasonFilter &&
        ageGroupFilter == other.ageGroupFilter &&
        sexFilter == other.sexFilter &&
        categoryFilter == other.categoryFilter &&
        saleOnly == other.saleOnly &&
        searchQuery == other.searchQuery &&
        priceMin == other.priceMin &&
        priceMax == other.priceMax &&
        sort == other.sort;
  }

  @override
  int get hashCode => Object.hash(
        staffMode,
        seasonFilter,
        ageGroupFilter,
        sexFilter,
        categoryFilter,
        saleOnly,
        searchQuery,
        priceMin,
        priceMax,
        sort,
      );
}

/// Numbered catalog pagination — only the current page stays in memory.
class ProductCatalogService extends ChangeNotifier {
  ProductCatalogService._();
  static final ProductCatalogService instance = ProductCatalogService._();

  static int get pageSize => WebPlatform.catalogPageSize;
  static int get _maxBackfillRounds => WebPlatform.isIOSWeb ? 8 : 5;
  /// Admin session: may backfill [effectivePrice] on legacy products (Firestore rules).
  bool adminCanBackfillPrices = false;
  bool? _sortUsesBrowseFallback;
  String _priceSortOrderField = 'price';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  int _currentPage = 1;
  int? _totalCount;
  bool _hasNextPage = false;
  bool _loading = false;
  String? _error;
  CatalogQuery? _query;
  int _fetchGeneration = 0;
  String? _cursorQueryKey;

  /// Last document of page N — used as cursor to start page N + 1.
  final Map<int, QueryDocumentSnapshot<Map<String, dynamic>>> _pageEndCursors = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => List.unmodifiable(_docs);
  int get currentPage => _currentPage;
  int? get totalCount => _totalCount;
  bool get hasNextPage => _hasNextPage;
  bool get isLoading => _loading;
  bool get isLoadingInitial => _loading && _docs.isEmpty;
  bool get isLoadingMore => _loading && _docs.isNotEmpty;
  String? get error => _error;
  CatalogQuery? get currentQuery => _query;

  int get totalPages {
    if (_totalCount != null && _totalCount! > 0) {
      return (_totalCount! / pageSize).ceil();
    }
    if (_totalCount == 0) return 1;
    return _hasNextPage ? _currentPage + 1 : _currentPage.clamp(1, 999999);
  }

  /// Reload filters/sort from page 1.
  Future<void> fetchFirst(CatalogQuery query) => resetAndLoad(query);

  Future<void> resetAndLoad(CatalogQuery query) async {
    _pageEndCursors.clear();
    _cursorQueryKey = _queryCacheKey(query);
    _totalCount = null;
    _currentPage = 1;
    if (query.sort == CatalogSort.priceLowHigh && adminCanBackfillPrices) {
      await _ensurePriceSortReady();
    }
    await loadPage(query, 1);
  }

  Future<void> loadPage(CatalogQuery query, int page) async {
    final targetPage = page < 1 ? 1 : page;
    if (query.sort == CatalogSort.priceLowHigh && targetPage == 1 && adminCanBackfillPrices) {
      await _ensurePriceSortReady();
    }
    final generation = ++_fetchGeneration;
    final key = _queryCacheKey(query);

    if (key != _cursorQueryKey) {
      _pageEndCursors.clear();
      _cursorQueryKey = key;
      _totalCount = null;
      _sortUsesBrowseFallback = null;
      _priceSortOrderField = 'price';
    }

    if (query.sort == CatalogSort.priceLowHigh && !_usesSimpleBrowse(query)) {
      // Filtered price sort: browse visible catalog by price, apply filters client-side.
      _sortUsesBrowseFallback = true;
    }

    _query = query;
    _error = null;
    _loading = true;
    if (WebPlatform.isIOSWeb) {
      _docs = [];
    }
    WebPlatform.onCatalogPageLoadStart();
    notifyListeners();

    if (_totalCount == null && !_needsClientSidePass(query)) {
      _refreshTotalCount(query, generation);
    }

    try {
      final startAfter = await _resolveCursorForPage(query, targetPage, generation);
      if (generation != _fetchGeneration) return;

      final fetched = await _fetchSinglePage(query: query, startAfter: startAfter);
      if (generation != _fetchGeneration) return;

      var batch = fetched.docs;
      final serverCursor = fetched.serverCursor;

      if (targetPage == 1) {
        final direct = await _fetchDirectIdMatch(query);
        if (generation != _fetchGeneration) return;
        if (direct != null && _passesClientFilters(query, direct)) {
          final existing = batch.map((d) => d.id).toSet();
          if (!existing.contains(direct.id)) {
            batch = [direct, ...batch];
            if (batch.length > pageSize) {
              batch = batch.sublist(0, pageSize);
            }
          }
        }
      }

      if (query.sort == CatalogSort.priceLowHigh && batch.length > 1) {
        batch = sortCatalogDocs(batch, CatalogSort.priceLowHigh);
      }

      _docs = batch;
      _currentPage = targetPage;
      _hasNextPage = batch.length >= pageSize;
      if (serverCursor != null) {
        _pageEndCursors[targetPage] = serverCursor;
      } else if (batch.isNotEmpty) {
        _pageEndCursors[targetPage] = batch.last;
      } else if (targetPage > 1) {
        _hasNextPage = false;
      }

      _loading = false;
      notifyListeners();
      WebPlatform.onCatalogPageLoadComplete();
    } catch (e, st) {
      if (generation != _fetchGeneration) return;
      debugPrint('ProductCatalogService.loadPage failed: $e\n$st');
      _error = 'load_failed';
      _loading = false;
      notifyListeners();
    }
  }

  void invalidate() {
    _docs = [];
    _pageEndCursors.clear();
    _cursorQueryKey = null;
    _currentPage = 1;
    _totalCount = null;
    _hasNextPage = false;
    _error = null;
    _query = null;
    _sortUsesBrowseFallback = null;
    notifyListeners();
  }

  String _queryCacheKey(CatalogQuery q) {
    return '${q.staffMode}|${q.seasonFilter}|${q.ageGroupFilter}|${q.sexFilter}|'
        '${q.categoryFilter}|${q.saleOnly}|${q.searchQuery}|${q.priceMin}|${q.priceMax}|${q.sort.name}';
  }

  Future<void> _refreshTotalCount(CatalogQuery q, int generation) async {
    try {
      final snap = await _buildCountQuery(q).count().get();
      if (generation != _fetchGeneration) return;
      _totalCount = snap.count;
      notifyListeners();
    } catch (e) {
      debugPrint('ProductCatalogService count failed: $e');
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _resolveCursorForPage(
    CatalogQuery query,
    int page,
    int generation,
  ) async {
    if (page <= 1) return null;

    var knownPage = 0;
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;

    final sortedKeys = _pageEndCursors.keys.toList()..sort();
    for (final p in sortedKeys) {
      if (p < page) {
        knownPage = p;
        cursor = _pageEndCursors[p];
      }
    }

    for (var p = knownPage + 1; p < page; p++) {
      final fetched = await _fetchSinglePage(query: query, startAfter: cursor);
      if (generation != _fetchGeneration) return cursor;
      if (fetched.docs.isEmpty) return cursor;
      cursor = fetched.serverCursor ?? fetched.docs.last;
      _pageEndCursors[p] = cursor;
      if (fetched.docs.length < pageSize) return cursor;
    }

    return cursor;
  }

  Future<({List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, QueryDocumentSnapshot<Map<String, dynamic>>? serverCursor})>
      _fetchSinglePage({
    required CatalogQuery query,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var cursor = startAfter;
    var rounds = 0;
    var serverHasMore = true;
    final needsClientPass = _needsClientSidePass(query);
    final applyClientFilters = needsClientPass || !_usesSimpleBrowse(query);
    final maxRounds = _sortUsesBrowseFallback == true ? 20 : _maxBackfillRounds;
    QueryDocumentSnapshot<Map<String, dynamic>>? serverCursor;

    while (results.length < pageSize && rounds < maxRounds && serverHasMore) {
      rounds++;
      final snap = await _runQuery(q: query, startAfter: cursor);
      if (snap.docs.isEmpty) break;

      cursor = snap.docs.last;
      serverCursor = cursor;
      serverHasMore = snap.docs.length >= pageSize;

      for (final doc in snap.docs) {
        if (applyClientFilters && !_passesClientFilters(query, doc)) continue;
        results.add(doc);
        if (results.length >= pageSize) break;
      }
    }

    return (docs: results, serverCursor: serverCursor);
  }

  Future<void> _ensurePriceSortReady() async {
    if (!adminCanBackfillPrices) return;
    try {
      final result = await CatalogMigrationService.backfillEffectivePrices();
      if (result.updated > 0) {
        debugPrint('ProductCatalogService: backfilled effectivePrice on ${result.updated} products.');
      }
    } catch (e, st) {
      debugPrint('ProductCatalogService: effectivePrice backfill failed: $e\n$st');
    }
  }

  bool _needsClientSidePass(CatalogQuery q) {
    if (_sortUsesBrowseFallback == true) return true;
    if (ProductCatalog.hasActivePriceFilter(q.priceMin, q.priceMax)) return true;
    if (q.searchQuery.trim().isNotEmpty) return true;
    return false;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runQuery({
    required CatalogQuery q,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    CatalogSort? sortOverride,
  }) async {
    final sort = sortOverride ?? q.sort;
    if (_sortUsesBrowseFallback == true && sortOverride == null) {
      return _simpleBrowseQuery(q: q, startAfter: startAfter, sortOverride: sort)
          .limit(pageSize)
          .get();
    }

    try {
      return await _buildFirestoreQuery(q: q, startAfter: startAfter, sortOverride: sortOverride)
          .limit(pageSize)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      if (_usesSimpleBrowse(q) && sortOverride == null) {
        debugPrint('ProductCatalogService: missing Firestore index, using simple browse query.');
        return _simpleBrowseQuery(q: q, startAfter: startAfter).limit(pageSize).get();
      }
      if (sortOverride != null) {
        rethrow;
      }
      if (!_usesSimpleBrowse(q)) {
        debugPrint(
          'ProductCatalogService: missing index for ${q.sort.name} with filters — using browse + client filters. '
          'Deploy firestore.indexes.json for lower read cost. ${e.message}',
        );
        _sortUsesBrowseFallback = true;
        return _simpleBrowseQuery(q: q, startAfter: startAfter, sortOverride: sort)
            .limit(pageSize)
            .get();
      }
      debugPrint('ProductCatalogService: missing index for ${q.sort.name}. ${e.message}');
      rethrow;
    }
  }

  Query<Map<String, dynamic>> _buildCountQuery(CatalogQuery q) {
    if (_usesSimpleBrowse(q)) {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');
      if (!q.staffMode) {
        query = query.where('visibility', isEqualTo: true);
      }
      return query;
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');
    final search = q.searchQuery.trim().toLowerCase();
    final terms = search.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final useIdSearch = terms.length == 1 && ProductCatalog.looksLikeIdPrefix(terms.first);
    final useTitleSearch = terms.length == 1 && !useIdSearch;

    if (!q.staffMode) {
      query = query.where('visibility', isEqualTo: true);
    }

    if (useIdSearch || useTitleSearch || terms.isNotEmpty) {
      return query;
    }

    final seasons = ProductCatalog.seasonsForFilter(q.seasonFilter);
    if (seasons.isNotEmpty) {
      query = query.where('season', whereIn: seasons);
    }
    if (q.categoryFilter != 'All Categories') {
      query = query.where('type', isEqualTo: ProductCatalog.normalizeType(q.categoryFilter));
    }
    if (q.saleOnly) {
      query = query.where('onSale', isEqualTo: true);
    }
    return _applyAudienceFilters(query, q);
  }

  bool _usesSimpleBrowse(CatalogQuery q) {
    return q.searchQuery.trim().isEmpty &&
        q.seasonFilter == 'All Seasons' &&
        q.ageGroupFilter == 'All' &&
        q.sexFilter == 'All' &&
        q.categoryFilter == 'All Categories' &&
        !q.saleOnly &&
        !ProductCatalog.hasActivePriceFilter(q.priceMin, q.priceMax);
  }

  Query<Map<String, dynamic>> _simpleBrowseQuery({
    required CatalogQuery q,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    CatalogSort? sortOverride,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');
    if (!q.staffMode) {
      query = query.where('visibility', isEqualTo: true);
    }
    query = _applySortOrder(query, sortOverride ?? q.sort);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query;
  }

  Query<Map<String, dynamic>> _applyAudienceFilters(
    Query<Map<String, dynamic>> query,
    CatalogQuery q,
  ) {
    final ageGroup = ProductCatalog.firestoreAgeGroupForFilter(q.ageGroupFilter);
    if (ageGroup != null) {
      query = query.where('ageGroup', isEqualTo: ageGroup);
    }
    final sex = ProductCatalog.firestoreSexForFilter(q.sexFilter);
    if (sex != null) {
      query = query.where('sex', isEqualTo: sex);
    }
    return query;
  }

  Query<Map<String, dynamic>> _applySortOrder(Query<Map<String, dynamic>> query, CatalogSort sort) {
    switch (sort) {
      case CatalogSort.newest:
        return query.orderBy('created_at', descending: true);
      case CatalogSort.priceLowHigh:
        return query
            .orderBy(_priceSortOrderField, descending: false)
            .orderBy('created_at', descending: true);
      case CatalogSort.saleFirst:
        return query.orderBy('onSale', descending: true).orderBy('created_at', descending: true);
      case CatalogSort.mostPopular:
        return query.orderBy('favoriteCount', descending: true).orderBy('created_at', descending: true);
    }
  }

  Query<Map<String, dynamic>> _buildFirestoreQuery({
    required CatalogQuery q,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    CatalogSort? sortOverride,
  }) {
    final sort = sortOverride ?? q.sort;
    if (_usesSimpleBrowse(q)) {
      return _simpleBrowseQuery(q: q, startAfter: startAfter, sortOverride: sort);
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');

    final search = q.searchQuery.trim().toLowerCase();
    final terms = search.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final useIdSearch = terms.length == 1 && ProductCatalog.looksLikeIdPrefix(terms.first);
    final useTitleSearch = terms.length == 1 && !useIdSearch;

    if (!q.staffMode) {
      query = query.where('visibility', isEqualTo: true);
    }

    if (useIdSearch) {
      final prefix = terms.first;
      query = query.orderBy('searchIdPrefix').startAt([prefix]).endAt(['$prefix\uf8ff']);
    } else if (useTitleSearch) {
      final prefix = terms.first;
      query = query
          .orderBy('searchPrefix')
          .startAt([prefix])
          .endAt(['$prefix\uf8ff']);
    } else if (terms.isNotEmpty) {
      query = _applySortOrder(query, sort);
    } else {
      final seasons = ProductCatalog.seasonsForFilter(q.seasonFilter);
      if (seasons.isNotEmpty) {
        query = query.where('season', whereIn: seasons);
      }
      if (q.categoryFilter != 'All Categories') {
        query = query.where('type', isEqualTo: ProductCatalog.normalizeType(q.categoryFilter));
      }
      if (q.saleOnly) {
        query = query.where('onSale', isEqualTo: true);
      }
      query = _applyAudienceFilters(query, q);
      query = _applySortOrder(query, sort);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query;
  }

  bool _passesClientFilters(CatalogQuery q, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (!q.staffMode && !ProductPermissions.isPublicCatalogItem(data)) return false;

    if (!ProductCatalog.matchesFilters(
      data: data,
      seasonFilter: q.seasonFilter,
      ageGroupFilter: q.ageGroupFilter,
      sexFilter: q.sexFilter,
      categoryFilter: q.categoryFilter,
      saleOnly: q.saleOnly,
      priceMin: q.priceMin,
      priceMax: q.priceMax,
    )) {
      return false;
    }

    if (q.searchQuery.trim().isNotEmpty) {
      return ProductCatalog.matchesSearch(data: data, docId: doc.id, query: q.searchQuery);
    }

    return true;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _fetchDirectIdMatch(CatalogQuery q) async {
    final term = q.searchQuery.trim();
    if (term.isEmpty || !ProductCatalog.looksLikeIdPrefix(term)) return null;

    final col = FirebaseFirestore.instance.collection('products');
    final candidates = <String>{term, term.toUpperCase(), term.toLowerCase()};

    for (final id in candidates) {
      final qs = await col.where(FieldPath.documentId, isEqualTo: id).limit(1).get();
      if (qs.docs.isNotEmpty) return qs.docs.first;
    }

    for (final id in candidates) {
      final qs = await col.where('productId', isEqualTo: id).limit(1).get();
      if (qs.docs.isNotEmpty) return qs.docs.first;
    }

    return null;
  }
}
