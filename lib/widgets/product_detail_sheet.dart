import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';

class ProductDetailSheet extends StatefulWidget {
  final String productId;
  final String title;
  final String description;
  final String imageUrl;
  final String sizeField;
  final double price;
  final double? soldPrice;
  final String seasonLabel;
  final String genderLabel;
  final String typeLabel;
  final int favoriteCount;
  final bool isFavorited;
  final bool isSoldOut;
  final bool showProductId;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToCart;

  const ProductDetailSheet({
    super.key,
    required this.productId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.sizeField,
    required this.price,
    this.soldPrice,
    required this.seasonLabel,
    required this.genderLabel,
    required this.typeLabel,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.isSoldOut = false,
    this.showProductId = false,
    this.onFavoriteToggle,
    this.onAddToCart,
  });

  static Future<void> show(
    BuildContext context, {
    required String productId,
    required String title,
    required String description,
    required String imageUrl,
    required String sizeField,
    required double price,
    double? soldPrice,
    required String seasonLabel,
    required String genderLabel,
    required String typeLabel,
    int favoriteCount = 0,
    bool isFavorited = false,
    bool isSoldOut = false,
    bool showProductId = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToCart,
  }) {
    final sheet = ProductDetailSheet(
      productId: productId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      sizeField: sizeField,
      price: price,
      soldPrice: soldPrice,
      seasonLabel: seasonLabel,
      genderLabel: genderLabel,
      typeLabel: typeLabel,
      favoriteCount: favoriteCount,
      isFavorited: isFavorited,
      isSoldOut: isSoldOut,
      showProductId: showProductId,
      onFavoriteToggle: onFavoriteToggle,
      onAddToCart: onAddToCart,
    );

    final isWide = MediaQuery.sizeOf(context).width > 720;
    if (isWide) {
      return showDialog(
        context: context,
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
                            Expanded(child: _detailsPanel(sizes, isWide: true)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _imagePanel(isWide: false),
                            const SizedBox(height: 20),
                            _detailsPanel(sizes, isWide: false),
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
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: _DetailImage(imageUrl: widget.imageUrl),
              ),
            ),
            if (_onSale)
              Positioned(
                top: 14,
                left: 14,
                child: _badge(S.of('badge_sale'), AppColors.coral),
              ),
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

  Widget _detailsPanel(List<String> sizes, {required bool isWide}) {
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

class _DetailImage extends StatelessWidget {
  final String imageUrl;

  const _DetailImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 48));
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: ProductImageSettings.detailCacheSize,
      cacheHeight: ProductImageSettings.detailCacheSize,
      webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 48));
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
          ),
        );
      },
    );
  }
}
