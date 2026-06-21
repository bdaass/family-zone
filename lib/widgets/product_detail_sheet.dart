import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/product_share_service.dart';
import '../services/product_view_service.dart';
import '../services/product_image_service.dart';
import '../utils/product_image_settings.dart';
import '../theme/app_theme.dart';
import '../pages/product_detail_page.dart';
import 'product_image_carousel.dart';

class ProductDetailSheet extends StatefulWidget {
  final String productDocId;
  final String productId;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> imageUrls;
  final String? barcodeImageUrl;
  final bool showBarcodeImage;
  final String sizeField;
  final String colorField;
  final double price;
  final double? soldPrice;
  final String seasonLabel;
  final String genderLabel;
  final String typeLabel;
  final int favoriteCount;
  final bool isFavorited;
  final bool isSoldOut;
  final bool showProductId;
  final bool isNew;
  final bool isOld;
  final bool showOldBadge;
  final bool showBranchStock;
  final Map<String, int?> branchStock;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToCart;

  const ProductDetailSheet({
    super.key,
    this.productDocId = '',
    required this.productId,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.imageUrls = const [],
    this.barcodeImageUrl,
    this.showBarcodeImage = false,
    required this.sizeField,
    this.colorField = '',
    required this.price,
    this.soldPrice,
    required this.seasonLabel,
    required this.genderLabel,
    required this.typeLabel,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.isSoldOut = false,
    this.showProductId = false,
    this.isNew = false,
    this.isOld = false,
    this.showOldBadge = false,
    this.showBranchStock = false,
    this.branchStock = const {},
    this.onFavoriteToggle,
    this.onAddToCart,
  });

  static Future<void> show(
    BuildContext context, {
    String productDocId = '',
    required String productId,
    required String title,
    required String description,
    required String imageUrl,
    List<String> imageUrls = const [],
    String? barcodeImageUrl,
    bool showBarcodeImage = false,
    required String sizeField,
    String colorField = '',
    required double price,
    double? soldPrice,
    required String seasonLabel,
    required String genderLabel,
    required String typeLabel,
    int favoriteCount = 0,
    bool isFavorited = false,
    bool isSoldOut = false,
    bool showProductId = false,
    bool isNew = false,
    bool isOld = false,
    bool showOldBadge = false,
    bool showBranchStock = false,
    Map<String, int?> branchStock = const {},
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToCart,
  }) {
    final sheet = ProductDetailSheet(
      productDocId: productDocId,
      productId: productId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      barcodeImageUrl: barcodeImageUrl,
      showBarcodeImage: showBarcodeImage,
      sizeField: sizeField,
      colorField: colorField,
      price: price,
      soldPrice: soldPrice,
      seasonLabel: seasonLabel,
      genderLabel: genderLabel,
      typeLabel: typeLabel,
      favoriteCount: favoriteCount,
      isFavorited: isFavorited,
      isSoldOut: isSoldOut,
      showProductId: showProductId,
      isNew: isNew,
      isOld: isOld,
      showOldBadge: showOldBadge,
      showBranchStock: showBranchStock,
      branchStock: branchStock,
      onFavoriteToggle: onFavoriteToggle,
      onAddToCart: onAddToCart,
    );

    final isWide = MediaQuery.sizeOf(context).width > 720;

    if (kIsWeb) {
      return Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => ProductDetailPage(child: sheet),
        ),
      );
    }

    if (isWide) {
      return showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierColor: AppColors.ink.withValues(alpha: 0.45),
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.cream,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 920,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
            ),
            child: sheet,
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: sheet,
        ),
      ),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.isFavorited;
    final docId = widget.productDocId.isNotEmpty ? widget.productDocId : widget.productId;
    ProductViewService.instance.recordView(docId);
  }

  Future<void> _shareProduct() async {
    await ProductShareService.shareProduct(productId: widget.productId, title: widget.title);
  }

  bool get _onSale =>
      widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price;

  void _toggleFavorite() {
    widget.onFavoriteToggle?.call();
    setState(() => _isFavorited = !_isFavorited);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 720;
    final sizes = ProductCatalog.sizesForSelection(widget.sizeField);
    final colors = ProductCatalog.colorsForSelection(widget.colorField);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(isWide ? 16 : 12, isWide ? 16 : 12, isWide ? 8 : 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of('product_details'),
                        style: TextStyle(
                          fontSize: isWide ? 18 : 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: S.of('share_product'),
                      onPressed: _shareProduct,
                      icon: const Icon(Icons.ios_share_rounded, color: AppColors.inkMuted),
                    ),
                    if (widget.onFavoriteToggle != null)
                      IconButton(
                        tooltip: S.of('tooltip_favorites'),
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: AppColors.coral,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 8, isWide ? 24 : 16, 24),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _imagePanel(isWide: true)),
                            const SizedBox(width: 24),
                            Expanded(child: _detailsPanel(sizes, colors, isWide: true)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _imagePanel(isWide: false),
                            const SizedBox(height: 20),
                            _detailsPanel(sizes, colors, isWide: false),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imagePanel({required bool isWide}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: isWide ? 0.82 : 0.88,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.creamDark,
              child: ProductImageCarousel(
                imageUrls: widget.imageUrls.isNotEmpty ? widget.imageUrls : [widget.imageUrl],
                interactive: true,
                showIndicators: true,
              ),
            ),
            ..._buildLeftBadges(),
            if (widget.isSoldOut)
              Container(
                color: AppColors.ink.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: AppDecor.glassCard(radius: 12),
                  child: Text(
                    S.of('badge_sold_out'),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailsPanel(List<String> sizes, List<String> colors, {required bool isWide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: isWide ? 26 : 22,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        _priceRow(),
        if (widget.showProductId) ...[
          const SizedBox(height: 8),
          Text(
            S.fmt('product_id_label', {'id': widget.productId}),
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
          ),
        ],
        if (widget.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            S.of('field_description'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.55, fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 20),
        _detailRow(S.of('field_season'), widget.seasonLabel),
        const SizedBox(height: 10),
        _detailRow(S.of('field_audience'), widget.genderLabel),
        const SizedBox(height: 10),
        _detailRow(S.of('field_type'), widget.typeLabel),
        if (widget.showBranchStock) ...[
          const SizedBox(height: 20),
          Text(
            S.of('field_branch_stock'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          for (final id in ProductCatalog.branchIds) ...[
            _detailRow(
              ProductCatalog.branchLabel(id),
              ProductCatalog.branchStockDisplayLabel(widget.branchStock[id]),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (widget.showBarcodeImage && widget.barcodeImageUrl?.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          _AdminBarcodePreview(
            imageUrl: widget.barcodeImageUrl!,
            storageProductId: widget.productDocId.isNotEmpty ? widget.productDocId : widget.productId,
          ),
        ],
        const SizedBox(height: 20),
        Text(
          S.of('available_sizes'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes
              .map(
                (size) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: AppDecor.pill(color: AppColors.white),
                  child: Text(
                    size,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
              )
              .toList(),
        ),
        if (colors.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            S.of('available_colors'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors
                .map(
                  (color) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: AppDecor.pill(color: AppColors.white),
                    child: Text(
                      ProductCatalog.colorDisplayName(color),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (widget.favoriteCount > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: AppColors.coral),
              const SizedBox(width: 6),
              Text(
                '${widget.favoriteCount}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
              ),
            ],
          ),
        ],
        if (!widget.isSoldOut && widget.onAddToCart != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onAddToCart!();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(S.of('add_to_cart'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _priceRow() {
    if (!_onSale) {
      return Text(
        '\$${widget.price.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink),
      );
    }

    return Row(
      children: [
        Text(
          '\$${widget.price.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.inkMuted,
            decoration: TextDecoration.lineThrough,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '\$${widget.soldPrice!.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.coral),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLeftBadges() {
    final badges = <({String label, Color color})>[];
    if (widget.isNew) badges.add((label: S.of('badge_new'), color: AppColors.violet));
    if (_onSale) badges.add((label: S.of('badge_sale'), color: AppColors.coral));
    if (widget.showOldBadge && widget.isOld) {
      badges.add((label: S.of('badge_old_6'), color: AppColors.inkMuted));
    }
    return [
      for (var i = 0; i < badges.length; i++)
        Positioned(
          top: 14 + i * 30.0,
          left: 14,
          child: _badge(badges[i].label, badges[i].color),
        ),
    ];
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppColors.elevationShadow(opacity: 0.12, blur: 10, y: 4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
      ),
    );
  }
}

class _AdminBarcodePreview extends StatefulWidget {
  final String imageUrl;
  final String storageProductId;

  const _AdminBarcodePreview({
    required this.imageUrl,
    required this.storageProductId,
  });

  @override
  State<_AdminBarcodePreview> createState() => _AdminBarcodePreviewState();
}

class _AdminBarcodePreviewState extends State<_AdminBarcodePreview> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = ProductImageService.resolveBarcodeViewUrl(
      productStorageId: widget.storageProductId,
      storedUrl: widget.imageUrl,
    );
  }

  void _openZoom(BuildContext context, String url) {
    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: AppColors.ink.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: size.width * 0.9,
                      height: size.height * 0.8,
                      child: ProductNetworkImage(
                        url: url,
                        fit: BoxFit.contain,
                        cacheSize: ProductImageSettings.detailCacheSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFrame({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.cream),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.of('field_barcode_admin_only'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 8),
        FutureBuilder<String>(
          future: _urlFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final url = snapshot.data;
            final failed = snapshot.hasError || (!loading && (url == null || url.isEmpty));

            return Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: loading || failed || url == null ? null : () => _openZoom(context, url),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.creamDark),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (loading)
                        _imageFrame(
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                            ),
                          ),
                        )
                      else if (failed)
                        _imageFrame(
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32),
                          ),
                        )
                      else
                        _imageFrame(
                          child: ProductNetworkImage(
                            url: url!,
                            fit: BoxFit.contain,
                            cacheSize: ProductImageSettings.detailCacheSize,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.inkMuted),
                          const SizedBox(width: 6),
                          Text(
                            S.of('barcode_tap_to_zoom'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
