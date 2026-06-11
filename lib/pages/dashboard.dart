import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/catalog_sort.dart';
import '../models/product_catalog.dart';
import '../services/favorite_service.dart';
import '../services/product_catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_permissions.dart';
import '../widgets/ambient_background.dart';
import '../widgets/dashboard_hero.dart';
import '../widgets/family_zone_brand.dart';
import '../widgets/edit_product_sheet.dart';
import '../widgets/add_to_cart_sheet.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/favorites_sheet.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../services/cart_service.dart';
import '../services/locale_service.dart';
import '../services/order_service.dart';
import '../services/product_write_service.dart';
import '../widgets/sidebar_content.dart';
import '../widgets/product_card.dart';
import '../widgets/catalog_sort_bar.dart';
import '../widgets/approval_queue_sheet.dart';
import '../widgets/staff_analytics_sheet.dart';
import 'auth_modal.dart';
import 'staff_panel.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  String userRole = 'guest';
  String selectedSeason = 'All Seasons';
  String selectedAgeGroup = 'All';
  String selectedSex = 'All';
  String selectedCategory = 'All Categories';
  bool saleOnly = false;
  double priceMin = ProductCatalog.priceFilterFloor;
  double priceMax = ProductCatalog.priceFilterCeiling;
  CatalogSort catalogSort = CatalogSort.newest;
  Set<String> _likedProductIds = {};
  String? _pendingProductLink;
  bool _pendingLinkHandled = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  Timer? _searchDebounce;
  bool _authResolved = false;

  final GlobalKey _staffPanelKey = GlobalKey();
  final GlobalKey _collectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ProductCatalogService _catalog = ProductCatalogService.instance;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _listenToAuthState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();
    CartService.instance.addListener(_onCartChanged);
    _catalog.addListener(_onCatalogChanged);
    _scrollController.addListener(_onScroll);
    if (kIsWeb) {
      final linkId = Uri.base.queryParameters['p']?.trim();
      if (linkId != null && linkId.isNotEmpty) _pendingProductLink = linkId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadCatalog();
    });
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    _catalog.removeListener(_onCatalogChanged);
    _searchDebounce?.cancel();
    _userSubscription?.cancel();
    _entranceController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  CatalogQuery get _catalogQuery => CatalogQuery(
        staffMode: _isStaff,
        seasonFilter: selectedSeason,
        ageGroupFilter: selectedAgeGroup,
        sexFilter: selectedSex,
        categoryFilter: selectedCategory,
        saleOnly: saleOnly,
        searchQuery: _searchController.text,
        priceMin: priceMin,
        priceMax: priceMax,
      );

  void _onCatalogChanged() {
    if (!mounted) return;
    if (_catalog.currentQuery == null) {
      _reloadCatalog();
    } else {
      setState(() {});
      if (!_catalog.isLoadingInitial) {
        _tryOpenPendingProductLink();
      }
    }
  }

  Future<void> _reloadCatalog() async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    await _catalog.fetchFirst(_catalogQuery);
  }

  Future<void> _loadMoreProducts() async {
    await _catalog.fetchMore();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_catalog.hasMore || _catalog.isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 480) {
      _loadMoreProducts();
    }
  }

  void _invalidateCatalog() {
    _catalog.invalidate();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reloadCatalog();
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    setState(() {});
    _reloadCatalog();
  }

  void _listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        await _userSubscription?.cancel();
        _userSubscription = null;
        if (!mounted) return;
        final wasStaff = _isStaff;
        setState(() {
          userRole = 'guest';
          _likedProductIds = {};
        });
        _authResolved = true;
        if (wasStaff) _reloadCatalog();
      } else {
        await _createUserProfileIfNew(user);
        _listenToUserDoc(user.uid);
      }
    });
  }

  Future<void> _createUserProfileIfNew(User user) async {
    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDocRef.get();
      if (!docSnapshot.exists) {
        await userDocRef.set({
          'uid': user.uid,
          'name': user.displayName ?? user.email?.split('@')[0] ?? S.of('default_client_name'),
          'email': user.email,
          'role': 'client',
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error auto-initializing profile document: $e');
    }
  }

  void _listenToUserDoc(String uid) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
      if (!mounted) return;

      if (!doc.exists) {
        if (!_authResolved) {
          _authResolved = true;
          _reloadCatalog();
        }
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final newRole = data['role']?.toString() ?? 'client';
      final staffModeChanged = ProductPermissions.isStaff(newRole) != _isStaff;
      setState(() {
        userRole = newRole;
        _likedProductIds = Set<String>.from(data['likedProducts'] ?? []);
      });
      _authResolved = true;
      // Refresh JWT so Storage rules see the role custom claim.
      unawaited(FirebaseAuth.instance.currentUser?.getIdToken(true));
      if (staffModeChanged) _reloadCatalog();
    });
  }

  bool get _isStaff => ProductPermissions.isStaff(userRole);

  bool get _isClient => ProductPermissions.isClient(userRole);

  Future<void> _toggleFavorite(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAuthModal();
      return;
    }
    try {
      await FavoriteService.toggle(docId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('favorite_update_failed', {'error': '$e'}))));
      }
    }
  }

  void _resetFilters() {
    setState(() {
      selectedSeason = 'All Seasons';
      selectedAgeGroup = 'All';
      selectedSex = 'All';
      selectedCategory = 'All Categories';
      saleOnly = false;
      priceMin = ProductCatalog.priceFilterFloor;
      priceMax = ProductCatalog.priceFilterCeiling;
    });
    _reloadCatalog();
  }

  int get _activeFilterCount {
    var count = 0;
    if (selectedSeason != 'All Seasons') count++;
    if (selectedAgeGroup != 'All') count++;
    if (selectedSex != 'All') count++;
    if (selectedCategory != 'All Categories') count++;
    if (saleOnly) count++;
    if (ProductCatalog.hasActivePriceFilter(priceMin, priceMax)) count++;
    return count;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterBottomSheet(
        initialSeason: selectedSeason,
        initialAgeGroup: selectedAgeGroup,
        initialSex: selectedSex,
        initialCategory: selectedCategory,
        initialSaleOnly: saleOnly,
        initialPriceMin: priceMin,
        initialPriceMax: priceMax,
        onApply: (season, ageGroup, sex, category, onlySale, minPrice, maxPrice) {
          setState(() {
            selectedSeason = season;
            selectedAgeGroup = ageGroup;
            selectedSex = sex;
            selectedCategory = category;
            saleOnly = onlySale;
            priceMin = minPrice;
            priceMax = maxPrice;
          });
          _reloadCatalog();
        },
      ),
    );
  }

  Future<void> _deleteProduct(String docId, String imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of('delete_confirm_title')),
        content: Text(S.of('delete_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(S.of('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('products').doc(docId).delete();
      _invalidateCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('item_deleted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('delete_failed', {'error': '$e'}))));
      }
    }
  }

  Future<void> _editProduct(String docId, Map<String, dynamic> data) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final audience = ProductCatalog.audienceFrom(data);
        return EditProductSheet(
          productId: ProductCatalog.productIdFrom(data, docId),
          title: ProductCatalog.titleFrom(data),
          description: ProductCatalog.descriptionFrom(data),
          size: ProductCatalog.sizeFrom(data),
          colors: ProductCatalog.colorsFrom(data),
          stockQty: ProductCatalog.stockQtyFrom(data),
          price: ProductCatalog.priceFrom(data),
          soldPrice: ProductCatalog.soldPriceFrom(data),
          season: (data['season'] ?? 'summer').toString(),
          ageGroup: audience.ageGroup,
          sex: audience.sex,
          type: (data['type'] ?? 'clothes').toString(),
        );
      },
    );
    if (result == null || !mounted) return;

    try {
      final newProductId = result.remove('productId') as String?;
      await ProductWriteService.updateProduct(
        docId: docId,
        updates: result,
        newProductId: newProductId,
      );
      _invalidateCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('item_updated'))));
      }
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('product_id_invalid'))));
      }
    } on StateError catch (e) {
      if (!mounted) return;
      final text = e.message == 'product_id_taken' ? S.of('product_id_taken') : S.fmt('update_failed', {'error': '$e'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('update_failed', {'error': '$e'}))));
      }
    }
  }

  Future<void> _toggleVisibility(String docId, Map<String, dynamic> data) async {
    final currentlyVisible = ProductPermissions.isVisible(data);
    final newVisibility = !currentlyVisible;

    try {
      final update = <String, dynamic>{'visibility': newVisibility};
      if (newVisibility && ProductPermissions.isPendingApproval(data)) {
        update['approved'] = true;
      }
      await FirebaseFirestore.instance.collection('products').doc(docId).update(update);
      _invalidateCatalog();
      if (mounted) {
        final msg = newVisibility ? S.of('item_now_visible') : S.of('item_now_hidden');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('update_failed', {'error': '$e'}))));
      }
    }
  }

  void _showFavoritesSheet() {
    FavoritesSheet.show(context);
  }

  void _showApprovalQueue() {
    ApprovalQueueSheet.show(
      context,
      userRole: userRole,
      onOpenProduct: (docId, data) => _openProductDetail(docId, data),
    );
  }

  void _showStaffAnalytics() {
    StaffAnalyticsSheet.show(context);
  }

  Future<void> _tryOpenPendingProductLink() async {
    if (_pendingLinkHandled || _pendingProductLink == null || !_authResolved) return;

    final targetId = _pendingProductLink!;
    for (final doc in _catalog.docs) {
      final data = doc.data();
      if (doc.id == targetId || ProductCatalog.productIdFrom(data, doc.id) == targetId) {
        _pendingLinkHandled = true;
        _pendingProductLink = null;
        _openProductDetail(doc.id, data);
        return;
      }
    }

    if (_catalog.isLoadingInitial || _catalog.isLoadingMore) return;

    try {
      var doc = await FirebaseFirestore.instance.collection('products').doc(targetId).get();
      if (!doc.exists) {
        final query = await FirebaseFirestore.instance
            .collection('products')
            .where('productId', isEqualTo: targetId)
            .limit(1)
            .get();
        if (query.docs.isEmpty) return;
        doc = query.docs.first;
      }

      final data = doc.data();
      if (data == null) return;
      if (!_isStaff && !ProductPermissions.isPublicCatalogItem(data)) return;

      _pendingLinkHandled = true;
      _pendingProductLink = null;
      if (mounted) _openProductDetail(doc.id, data);
    } catch (e) {
      debugPrint('Deep link product open failed: $e');
    }
  }

  void _showCartSheet() {
    CartSheet.show(context);
  }

  Future<void> _contactViaWhatsApp() async {
    final result = await OrderService.contactViaWhatsApp();
    if (!mounted) return;

    switch (result) {
      case WhatsAppLaunchResult.opened:
        break;
      case WhatsAppLaunchResult.copiedToClipboard:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.fmt('whatsapp_message_copied', {'phone': StoreConfig.storeDisplayNumber}),
            ),
          ),
        );
      case WhatsAppLaunchResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of('whatsapp_open_failed'))),
        );
    }
  }

  void _openAddToCart(String docId, Map<String, dynamic> data) {
    AddToCartSheet.show(
      context,
      productDocId: docId,
      productId: ProductCatalog.productIdFrom(data, docId),
      title: ProductCatalog.titleFrom(data),
      imageUrl: _productImageUrl(data),
      sizeField: ProductCatalog.sizeFrom(data),
      colorField: ProductCatalog.colorsFrom(data),
      price: ProductCatalog.priceFrom(data),
      soldPrice: ProductCatalog.soldPriceFrom(data),
    );
  }

  void _openProductDetail(String docId, Map<String, dynamic> data) {
    ProductDetailSheet.show(
      context,
      productDocId: docId,
      productId: ProductCatalog.productIdFrom(data, docId),
      title: ProductCatalog.titleFrom(data),
      description: ProductCatalog.descriptionFrom(data),
      imageUrl: _productImageUrl(data),
      sizeField: ProductCatalog.sizeFrom(data),
      colorField: ProductCatalog.colorsFrom(data),
      price: ProductCatalog.priceFrom(data),
      soldPrice: ProductCatalog.soldPriceFrom(data),
      seasonLabel: ProductCatalog.localizedCatalogLabel((data['season'] ?? '').toString()),
      genderLabel: ProductCatalog.audienceLabelFromData(data),
      typeLabel: ProductCatalog.localizedCatalogLabel(ProductCatalog.normalizeType(data['type']?.toString())),
      favoriteCount: ProductCatalog.favoriteCountFrom(data),
      isFavorited: _likedProductIds.contains(docId),
      isSoldOut: data['sold'] ?? false,
      showProductId: _isStaff,
      onFavoriteToggle: _isClient ? () => _toggleFavorite(docId) : null,
      onAddToCart: _isStaff || (data['sold'] ?? false) ? null : () => _openAddToCart(docId, data),
    );
  }

  void _showAuthModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const AuthModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final useInlineSidebar = kIsWeb && screenWidth > 900;
        final showDrawer = !useInlineSidebar;
        final user = FirebaseAuth.instance.currentUser;
        final isWide = screenWidth > 600;

        return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _buildAppBar(context, user, showDrawer),
      drawer: showDrawer ? _buildDrawer() : null,
      body: Stack(
        children: [
          const AmbientBackground(),
          Row(
            children: [
              if (useInlineSidebar) _buildSidebar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: RefreshIndicator(
                      color: AppColors.coral,
                      onRefresh: _reloadCatalog,
                      child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        if (userRole == 'admin' || userRole == 'employee')
                          SliverToBoxAdapter(
                            key: _staffPanelKey,
                            child: StaffManagementPanel(userRole: userRole),
                          ),
                        SliverToBoxAdapter(
                          child: DashboardHero(
                            key: ValueKey(LocaleService.instance.languageCode),
                            isWide: isWide,
                            onContactTap: _contactViaWhatsApp,
                          ),
                        ),
                        SliverToBoxAdapter(
                          key: _collectionKey,
                          child: _buildCollectionHeader(isWide, useInlineSidebar),
                        ),
                        _buildProductGrid(isWide),
                        const SliverToBoxAdapter(child: SizedBox(height: 60)),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.cream,
      child: SafeArea(
        child: _sidebarContent(showBrand: true, onStaffTap: () {
          Navigator.pop(context);
          _scrollToStaffPanel();
        }),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        border: Border(right: BorderSide(color: AppColors.creamDark.withValues(alpha: 0.8))),
      ),
      child: _sidebarContent(showBrand: false, onStaffTap: _scrollToStaffPanel),
    );
  }

  Widget _sidebarContent({required bool showBrand, VoidCallback? onStaffTap}) {
    return FilterSidebarContent(
      userRole: userRole,
      showBrand: showBrand,
      currentSeason: selectedSeason,
      currentAgeGroup: selectedAgeGroup,
      currentSex: selectedSex,
      currentCategory: selectedCategory,
      saleOnly: saleOnly,
      priceMin: priceMin,
      priceMax: priceMax,
      onSeasonChanged: (v) {
        setState(() => selectedSeason = v);
        _reloadCatalog();
      },
      onAgeGroupChanged: (v) {
        setState(() => selectedAgeGroup = v);
        _reloadCatalog();
      },
      onSexChanged: (v) {
        setState(() => selectedSex = v);
        _reloadCatalog();
      },
      onCategoryChanged: (v) {
        setState(() => selectedCategory = v);
        _reloadCatalog();
      },
      onSaleOnlyChanged: (v) {
        setState(() => saleOnly = v);
        _reloadCatalog();
      },
      onPriceRangeChanged: (values) {
        setState(() {
          priceMin = values.start;
          priceMax = values.end;
        });
      },
      onPriceRangeCommit: (_) => _reloadCatalog(),
      onClearFilters: _resetFilters,
      onStaffPanelTap: onStaffTap,
      isLoggedIn: userRole != 'guest',
      onSignIn: _showAuthModal,
      onSignOut: () async {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
      },
    );
  }

  void _scrollToStaffPanel() {
    final context = _staffPanelKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, User? user, bool showDrawer) {
    final topInset = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).width < 420;
    final iconSize = compact ? 20.0 : 22.0;
    final iconConstraints = BoxConstraints(minWidth: compact ? 36 : 40, minHeight: compact ? 36 : 40);

    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight + topInset),
      child: Material(
        color: AppColors.white.withValues(alpha: 0.82),
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.creamDark.withValues(alpha: 0.7))),
            boxShadow: AppColors.elevationShadow(opacity: 0.04, blur: 18, y: 6),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Builder(
              builder: (barContext) {
                return SizedBox(
                  height: kToolbarHeight,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: showDrawer ? 2 : 12, end: compact ? 4 : 8),
                    child: Row(
                      children: [
                        if (showDrawer)
                          IconButton(
                            tooltip: S.of('browse_shop'),
                            onPressed: () => Scaffold.of(barContext).openDrawer(),
                            icon: Icon(Icons.menu_rounded, color: AppColors.ink, size: compact ? 22 : 24),
                            constraints: iconConstraints,
                            padding: EdgeInsets.zero,
                          )
                        else
                          const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: compact
                                ? FamilyZoneBrand.logoOnly(
                                    key: ValueKey('logo-${LocaleService.instance.languageCode}'),
                                    size: 32,
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FamilyZoneBrand.compact(key: ValueKey(LocaleService.instance.languageCode)),
                                  ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: false,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: iconConstraints,
                                padding: EdgeInsets.zero,
                                tooltip: S.of('tooltip_whatsapp'),
                                onPressed: _contactViaWhatsApp,
                                icon: Icon(Icons.chat_rounded, color: const Color(0xFF25D366), size: iconSize),
                              ),
                              if (_isStaff) ...[
                                IconButton(
                                  constraints: iconConstraints,
                                  padding: EdgeInsets.zero,
                                  tooltip: S.of('approval_queue_title'),
                                  onPressed: _showApprovalQueue,
                                  icon: Icon(Icons.pending_actions_rounded, color: AppColors.coral, size: iconSize),
                                ),
                                IconButton(
                                  constraints: iconConstraints,
                                  padding: EdgeInsets.zero,
                                  tooltip: S.of('analytics_title'),
                                  onPressed: _showStaffAnalytics,
                                  icon: Icon(Icons.insights_rounded, color: AppColors.ink, size: iconSize),
                                ),
                              ],
                              if (!_isStaff)
                                IconButton(
                                  constraints: iconConstraints,
                                  padding: EdgeInsets.zero,
                                  tooltip: S.of('tooltip_cart'),
                                  onPressed: _showCartSheet,
                                  icon: Badge(
                                    isLabelVisible: CartService.instance.itemCount > 0,
                                    label: Text('${CartService.instance.itemCount}'),
                                    child: Icon(Icons.shopping_bag_outlined, color: AppColors.ink, size: iconSize),
                                  ),
                                ),
                              if (_isClient && user != null)
                                IconButton(
                                  constraints: iconConstraints,
                                  padding: EdgeInsets.zero,
                                  tooltip: S.of('tooltip_favorites'),
                                  onPressed: _showFavoritesSheet,
                                  icon: Badge(
                                    isLabelVisible: _likedProductIds.isNotEmpty,
                                    label: Text('${_likedProductIds.length}'),
                                    child: Icon(Icons.favorite_border_rounded, color: AppColors.coral, size: iconSize),
                                  ),
                                ),
                              if (userRole != 'guest' && !compact)
                                Padding(
                                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                                  child: Text(
                                    S.roleLabel(userRole),
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              IconButton(
                                constraints: iconConstraints,
                                padding: EdgeInsets.zero,
                                tooltip: user == null ? S.of('auth_sign_in_title') : S.of('auth_login_button'),
                                icon: Icon(
                                  user == null ? Icons.person_outline_rounded : Icons.logout_rounded,
                                  color: AppColors.ink,
                                  size: iconSize,
                                ),
                                onPressed: () async {
                                  if (user == null) {
                                    _showAuthModal();
                                  } else {
                                    await GoogleSignIn().signOut();
                                    await FirebaseAuth.instance.signOut();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionHeader(bool isWide, bool useInlineSidebar) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(isWide ? 20 : 16, 8, isWide ? 20 : 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                flex: isWide ? 0 : 1,
                child: Text(
                  S.of('shop'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isWide ? 22 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.creamDark),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: S.of('search_hint'),
                      hintStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 18),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: S.of('clear'),
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted, size: 18),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 4),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (!useInlineSidebar) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: _FilterButton(activeCount: _activeFilterCount, onTap: _showFilterSheet),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          CatalogSortBar(
            compact: !isWide,
            selected: catalogSort,
            onChanged: (value) => setState(() => catalogSort = value),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(bool isWide) {
    if (_catalog.error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of('products_load_error'), style: const TextStyle(color: AppColors.inkMuted)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _reloadCatalog,
                  child: Text(S.of('retry'), style: const TextStyle(color: AppColors.coral)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_catalog.docs.isEmpty &&
        _catalog.error == null &&
        (_catalog.isLoadingInitial || _catalog.currentQuery == null)) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Center(
            child: kIsWeb
                ? Text(S.of('products_loading'), style: const TextStyle(color: AppColors.inkMuted))
                : const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.coral),
                  ),
          ),
        ),
      );
    }

    final filteredDocs = sortCatalogDocs(_catalog.docs, catalogSort);

        if (filteredDocs.isEmpty) {
          final hasSearch = _searchController.text.trim().isNotEmpty;
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                      size: 40,
                      color: AppColors.inkMuted.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasSearch ? S.of('no_search_results') : S.of('no_filter_results'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: hasSearch ? _clearSearch : _resetFilters,
                      child: Text(
                        hasSearch ? S.of('clear') : S.of('reset_filters'),
                        style: const TextStyle(color: AppColors.coral),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final cardAspectRatio = isWide ? 0.58 : 0.42;

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 12, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: isWide ? 280 : 220,
                  mainAxisSpacing: isWide ? 24 : 18,
                  crossAxisSpacing: isWide ? 20 : 12,
                  childAspectRatio: cardAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();
                    final imageUrl = _productImageUrl(data);
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('${doc.id}-$catalogSort-$selectedSeason-$selectedAgeGroup-$selectedSex-$selectedCategory-$saleOnly-$priceMin-$priceMax-${_searchController.text}'),
                      duration: Duration(milliseconds: 350 + (index * 80).clamp(0, 500)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - value)),
                            child: Transform.scale(
                              scale: 0.92 + (0.08 * value),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: ProductCardItem(
                        imageUrl: imageUrl,
                        title: ProductCatalog.titleFrom(data),
                        description: ProductCatalog.descriptionFrom(data),
                        size: ProductCatalog.sizeFrom(data),
                        colors: ProductCatalog.colorsFrom(data),
                        productId: ProductCatalog.productIdFrom(data, doc.id),
                        price: ProductCatalog.priceFrom(data),
                        soldPrice: ProductCatalog.soldPriceFrom(data),
                        favoriteCount: ProductCatalog.favoriteCountFrom(data),
                        isFavorited: _likedProductIds.contains(doc.id),
                        onTap: () => _openProductDetail(doc.id, data),
                        onFavoriteToggle: () => _toggleFavorite(doc.id),
                        showProductId: _isStaff,
                        isSoldOut: data['sold'] ?? false,
                        isHidden: !ProductPermissions.isVisible(data),
                        isPendingApproval: ProductPermissions.isPendingApproval(data),
                        showStaffActions: _isStaff,
                        canDelete: ProductPermissions.canDelete(userRole),
                        canEdit: ProductPermissions.canEdit(userRole),
                        canToggleVisibility: ProductPermissions.canToggleVisibility(userRole),
                        onDelete: () => _deleteProduct(doc.id, imageUrl),
                        onEdit: () => _editProduct(doc.id, data),
                        onToggleVisibility: () => _toggleVisibility(doc.id, data),
                        onAddToCart: _isStaff ? null : () => _openAddToCart(doc.id, data),
                      ),
                    );
                  },
                  childCount: filteredDocs.length,
                ),
              ),
            ),
            if (_catalog.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.coral),
                    ),
                  ),
                ),
              ),
          ],
        );
  }

  String _productImageUrl(Map<String, dynamic> data) {
    final raw = data['imageUrl'] ?? data['image_url'] ?? data['image'] ?? '';
    return raw is String ? raw.trim() : raw.toString().trim();
  }

}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = activeCount > 0 ? S.fmt('filters_button_count', {'count': '$activeCount'}) : S.of('filters_button');

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune_rounded, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.creamDark),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
