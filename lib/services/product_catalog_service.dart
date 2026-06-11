import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_catalog.dart';
import '../utils/product_permissions.dart';

/// Query parameters for a paginated catalog fetch.
class CatalogQuery {
  const CatalogQuery({
    required this.staffMode,
    this.seasonFilter = 'All Seasons',
    this.genderFilter = 'All',
    this.categoryFilter = 'All Categories',
    this.saleOnly = false,
    this.searchQuery = '',
  });

  final bool staffMode;
  final String seasonFilter;
  final String genderFilter;
  final String categoryFilter;
  final bool saleOnly;
  final String searchQuery;

  @override
  bool operator ==(Object other) {
    return other is CatalogQuery &&
        staffMode == other.staffMode &&
        seasonFilter == other.seasonFilter &&
        genderFilter == other.genderFilter &&
        categoryFilter == other.categoryFilter &&
        saleOnly == other.saleOnly &&
        searchQuery == other.searchQuery;
  }

  @override
  int get hashCode => Object.hash(
        staffMode,
        seasonFilter,
        genderFilter,
        categoryFilter,
        saleOnly,
        searchQuery,
      );
}

/// Paginated product catalog — loads a small page at a time instead of the full collection.
class ProductCatalogService extends ChangeNotifier {
  ProductCatalogService._();
  static final ProductCatalogService instance = ProductCatalogService._();

  static const pageSize = 48;
  static const _maxBackfillRounds = 5;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingInitial = false;
  bool _loadingMore = false;
  String? _error;
  CatalogQuery? _query;
  int _fetchGeneration = 0;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => List.unmodifiable(_docs);
  bool get hasMore => _hasMore;
  bool get isLoadingInitial => _loadingInitial;
  bool get isLoadingMore => _loadingMore;
  String? get error => _error;
  CatalogQuery? get currentQuery => _query;

  Future<void> fetchFirst(CatalogQuery query) async {
    final generation = ++_fetchGeneration;
    _query = query;
    _docs = [];
    _lastDoc = null;
    _hasMore = true;
    _error = null;
    _loadingInitial = true;
    notifyListeners();

    try {
      final batch = await _fetchBatch(startAfter: null);
      if (generation != _fetchGeneration) return;
      _docs = batch;
      _hasMore = _lastDoc != null;
      _loadingInitial = false;
      notifyListeners();
    } catch (e, st) {
      if (generation != _fetchGeneration) return;
      debugPrint('ProductCatalogService.fetchFirst failed: $e\n$st');
      _error = '$e';
      _loadingInitial = false;
      notifyListeners();
    }
  }

  Future<void> fetchMore() async {
    if (_query == null || !_hasMore || _loadingInitial || _loadingMore) return;

    final generation = _fetchGeneration;
    _loadingMore = true;
    notifyListeners();

    try {
      final batch = await _fetchBatch(startAfter: _lastDoc);
      if (generation != _fetchGeneration) return;
      if (batch.isNotEmpty) {
        final existing = _docs.map((d) => d.id).toSet();
        _docs = [..._docs, ...batch.where((d) => !existing.contains(d.id))];
      }
      _hasMore = _lastDoc != null;
      _loadingMore = false;
      notifyListeners();
    } catch (e, st) {
      if (generation != _fetchGeneration) return;
      debugPrint('ProductCatalogService.fetchMore failed: $e\n$st');
      _error = '$e';
      _loadingMore = false;
      notifyListeners();
    }
  }

  void invalidate() {
    _docs = [];
    _lastDoc = null;
    _hasMore = true;
    _error = null;
    _query = null;
    notifyListeners();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchBatch({
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final query = _query!;
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var cursor = startAfter;
    var rounds = 0;
    var serverHasMore = true;

    while (results.length < pageSize && rounds < _maxBackfillRounds && serverHasMore) {
      rounds++;
      final snap = await _runQuery(q: query, startAfter: cursor);
      if (snap.docs.isEmpty) {
        serverHasMore = false;
        break;
      }

      cursor = snap.docs.last;
      serverHasMore = snap.docs.length >= pageSize;

      for (final doc in snap.docs) {
        if (!_passesClientFilters(query, doc)) continue;
        results.add(doc);
        if (results.length >= pageSize) break;
      }
    }

    _lastDoc = serverHasMore ? cursor : null;
    return results;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runQuery({
    required CatalogQuery q,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      return await _buildFirestoreQuery(q: q, startAfter: startAfter).get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition' || _usesSimpleBrowse(q)) rethrow;
      debugPrint('ProductCatalogService: missing Firestore index, using simple browse query.');
      return _simpleBrowseQuery(startAfter: startAfter).get();
    }
  }

  /// Default shop view — no composite index required; filters run client-side.
  bool _usesSimpleBrowse(CatalogQuery q) {
    return q.searchQuery.trim().isEmpty &&
        q.seasonFilter == 'All Seasons' &&
        q.genderFilter == 'All' &&
        q.categoryFilter == 'All Categories' &&
        !q.saleOnly;
  }

  Query<Map<String, dynamic>> _simpleBrowseQuery({
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('created_at', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.limit(pageSize);
  }

  Query<Map<String, dynamic>> _buildFirestoreQuery({
    required CatalogQuery q,
    required QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    if (_usesSimpleBrowse(q)) {
      return _simpleBrowseQuery(startAfter: startAfter);
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');

    final search = q.searchQuery.trim().toLowerCase();
    final tokens = search.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final usePrefixSearch = search.isNotEmpty && tokens.length == 1;
    final useTokenSearch = search.isNotEmpty && tokens.length > 1;

    if (!q.staffMode) {
      query = query.where('visibility', isEqualTo: true);
    }

    if (usePrefixSearch) {
      final prefix = tokens.first;
      query = query
          .orderBy('searchPrefix')
          .startAt([prefix])
          .endAt(['$prefix\uf8ff']);
    } else if (useTokenSearch) {
      final token = tokens.reduce((a, b) => a.length >= b.length ? a : b);
      query = query.where('searchTokens', arrayContains: token).orderBy('created_at', descending: true);
    } else {
      final seasons = ProductCatalog.seasonsForFilter(q.seasonFilter);
      if (seasons.isNotEmpty) {
        query = query.where('season', whereIn: seasons);
      }
      if (q.genderFilter != 'All') {
        query = query.where('sex', isEqualTo: ProductCatalog.normalizeGender(q.genderFilter));
      }
      if (q.categoryFilter != 'All Categories') {
        query = query.where('type', isEqualTo: ProductCatalog.normalizeType(q.categoryFilter));
      }
      if (q.saleOnly) {
        query = query.where('onSale', isEqualTo: true);
      }
      query = query.orderBy('created_at', descending: true);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.limit(pageSize);
  }

  bool _passesClientFilters(CatalogQuery q, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (!q.staffMode && !ProductPermissions.isPublicCatalogItem(data)) return false;

    if (!ProductCatalog.matchesFilters(
      data: data,
      seasonFilter: q.seasonFilter,
      genderFilter: q.genderFilter,
      categoryFilter: q.categoryFilter,
      saleOnly: q.saleOnly,
    )) {
      return false;
    }

    if (q.searchQuery.trim().isNotEmpty) {
      return ProductCatalog.matchesSearch(data: data, docId: doc.id, query: q.searchQuery);
    }

    return true;
  }
}
