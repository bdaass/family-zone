import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';

class ProductCardItem extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String size;
  final String colors;
  final String productId;
  final double price;
  final double? soldPrice;
  final int favoriteCount;
  final bool isFavorited;
  final VoidCallback? onFavoriteToggle;
  final bool isSoldOut;
  final bool showProductId;
  final bool isHidden;
  final bool isPendingApproval;
  final bool isNew;
  final bool isOld;
  final bool showOldBadge;
  final bool showStaffActions;
  final bool canDelete;
  final bool canEdit;
  final bool canToggleVisibility;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;

  const ProductCardItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.size,
    this.colors = '',
    required this.productId,
    required this.price,
    this.soldPrice,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.onFavoriteToggle,
    this.isSoldOut = false,
    this.showProductId = false,
    this.isHidden = false,
    this.isPendingApproval = false,
    this.isNew = false,
    this.isOld = false,
    this.showOldBadge = false,
    this.showStaffActions = false,
    this.canDelete = false,
    this.canEdit = false,
    this.canToggleVisibility = false,
    this.onDelete,
    this.onEdit,
    this.onToggleVisibility,
    this.onAddToCart,
    this.onTap,
  });

  @override
  State<ProductCardItem> createState() => _ProductCardItemState();
}

class _ProductCardItemState extends State<ProductCardItem> {
  bool _hovered = false;

  bool get _onSale =>
      widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: _hovered ? 0.1 : 0.05),
              blurRadius: _hovered ? 24 : 12,
              offset: Offset(0, _hovered ? 12 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: AppColors.white,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.creamDark,
                          child: _ProductImage(imageUrl: widget.imageUrl),
                        ),
                        if (widget.isHidden)
                          Positioned.fill(
                            child: Container(color: AppColors.ink.withValues(alpha: 0.35)),
                          ),
                        ..._buildLeftBadges(),
                        if (!widget.showStaffActions)
                          Positioned(top: 12, right: 12, child: _WishlistButton(
                            active: widget.isFavorited,
                            count: widget.favoriteCount,
                            onTap: widget.onFavoriteToggle,
                          )),
                        if (widget.showStaffActions) _buildStaffActions(),
                        if (widget.isSoldOut) _soldOutOverlay(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: widget.isHidden ? AppColors.inkMuted : AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (widget.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (ProductCatalog.sizesDisplayLabel(widget.size).isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: AppDecor.pill(color: AppColors.cream),
                                  child: Text(
                                    ProductCatalog.sizesDisplayLabel(widget.size),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: 0.6),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            _PriceLabel(price: widget.price, soldPrice: widget.soldPrice),
                          ],
                        ),
                        if (ProductCatalog.colorsFromField(widget.colors).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _ColorSwatches(colors: ProductCatalog.colorsFromField(widget.colors)),
                        ],
                        if (widget.showProductId) ...[
                          const SizedBox(height: 4),
                          Text(
                            S.fmt('product_id_label', {'id': widget.productId}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
                          ),
                        ],
                        if (!widget.showStaffActions && !widget.isSoldOut && widget.onAddToCart != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: FilledButton(
                              onPressed: widget.onAddToCart,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: AppColors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(S.of('add_to_cart'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeftBadges() {
    final badges = <({String label, Color color})>[];
    if (widget.isNew) badges.add((label: S.of('badge_new'), color: AppColors.violet));
    if (_onSale) badges.add((label: S.of('badge_sale'), color: AppColors.coral));
    if (widget.showOldBadge && widget.isOld) {
      badges.add((label: S.of('badge_old_6'), color: AppColors.inkMuted));
    }
    if (widget.isPendingApproval) badges.add((label: S.of('badge_pending'), color: AppColors.gold));
    if (widget.isHidden && widget.showStaffActions) {
      badges.add((label: S.of('badge_hidden'), color: AppColors.ink));
    }
    return [
      for (var i = 0; i < badges.length; i++)
        _badge(badges[i].label, badges[i].color, top: 12 + i * 28.0, left: 12),
    ];
  }

  Widget _badge(String label, Color color, {required double top, required double left}) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppColors.elevationShadow(opacity: 0.12, blur: 10, y: 4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
      ),
    );
  }

  Widget _buildStaffActions() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.canEdit)
              _StaffActionButton(icon: Icons.edit_outlined, tooltip: S.of('tooltip_edit'), color: AppColors.violet, onTap: widget.onEdit),
            if (widget.canToggleVisibility)
              _StaffActionButton(
                icon: widget.isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: widget.isHidden ? S.of('tooltip_show_item') : S.of('tooltip_hide_item'),
                color: AppColors.coral,
                onTap: widget.onToggleVisibility,
              ),
            if (widget.canDelete)
              _StaffActionButton(icon: Icons.close_rounded, tooltip: S.of('tooltip_delete'), color: Colors.redAccent, onTap: widget.onDelete),
          ],
        ),
      ),
    );
  }

  Widget _soldOutOverlay() {
    return Container(
      color: AppColors.ink.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AppDecor.glassCard(radius: 12),
          child: Text(
            S.of('badge_sold_out'),
            style: const TextStyle(color: AppColors.ink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4),
          ),
        ),
      ),
    );
  }
}

class _StaffActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _StaffActionButton({required this.icon, required this.tooltip, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback? onTap;

  const _WishlistButton({required this.active, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.creamDark),
            ),
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: active ? AppColors.coral : AppColors.inkMuted,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: AppDecor.pill(),
              child: Text('$count', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final double price;
  final double? soldPrice;

  const _PriceLabel({required this.price, this.soldPrice});

  @override
  Widget build(BuildContext context) {
    final onSale = soldPrice != null && soldPrice! > 0 && soldPrice! < price;

    if (!onSale) {
      return Text(
        '\$${price.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: AppColors.inkMuted, decoration: TextDecoration.lineThrough),
        ),
        const SizedBox(width: 4),
        Text(
          '\$${soldPrice!.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.coral),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 32));
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: ProductImageSettings.displayCacheSize,
      cacheHeight: ProductImageSettings.displayCacheSize,
      webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Product image load failed: $error');
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32));
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        if (kIsWeb) {
          return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 28));
        }
        return const Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral)),
        );
      },
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  final List<String> colors;

  const _ColorSwatches({required this.colors});

  static Color _swatchFill(String name) {
    switch (name.toLowerCase().trim()) {
      case 'black':
        return const Color(0xFF1A1A1A);
      case 'white':
        return const Color(0xFFF4F4F4);
      case 'navy':
        return const Color(0xFF1B2A4A);
      case 'beige':
        return const Color(0xFFD8CBB8);
      case 'gray':
      case 'grey':
        return const Color(0xFF9E9E9E);
      case 'red':
        return const Color(0xFFC62828);
      case 'pink':
        return const Color(0xFFE891A8);
      case 'blue':
        return const Color(0xFF1565C0);
      case 'green':
        return const Color(0xFF2E7D32);
      case 'brown':
        return const Color(0xFF6D4C41);
      default:
        final hash = name.toLowerCase().codeUnits.fold(0, (sum, c) => sum + c);
        return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.42, 0.52).toColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = colors.take(5).toList();
    return Row(
      children: [
        for (final color in shown)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Tooltip(
              message: color,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _swatchFill(color),
                  border: Border.all(color: AppColors.creamDark),
                ),
              ),
            ),
          ),
        if (colors.length > shown.length)
          Text(
            '+${colors.length - shown.length}',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
      ],
    );
  }
}
