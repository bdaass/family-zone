import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';

class FavoritesSheet extends StatelessWidget {
  const FavoritesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FavoritesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.coral, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of('favorites_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                }

                final likedIds = List<String>.from(userSnap.data?.data()?['likedProducts'] ?? []);

                if (likedIds.isEmpty) {
                  return const _EmptyFavorites();
                }

                return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                  key: ValueKey(likedIds.join(',')),
                  future: FavoriteService.fetchProductsByIds(likedIds),
                  builder: (context, productsSnap) {
                    if (productsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                    }

                    final docs = productsSnap.data ?? [];

                    if (docs.isEmpty) {
                      return _EmptyFavorites(message: S.of('favorites_unavailable'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() ?? {};
                        return _FavoriteListTile(
                          docId: doc.id,
                          imageUrl: _imageUrl(data),
                          title: ProductCatalog.titleFrom(data),
                          price: ProductCatalog.priceFrom(data),
                          soldPrice: ProductCatalog.soldPriceFrom(data),
                          favoriteCount: ProductCatalog.favoriteCountFrom(data),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _imageUrl(Map<String, dynamic> data) => ProductCatalog.primaryImageUrl(data);
}

class _EmptyFavorites extends StatelessWidget {
  final String? message;

  const _EmptyFavorites({this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.inkMuted.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            message ?? S.of('favorites_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FavoriteListTile extends StatefulWidget {
  final String docId;
  final String imageUrl;
  final String title;
  final double price;
  final double? soldPrice;
  final int favoriteCount;

  const _FavoriteListTile({
    required this.docId,
    required this.imageUrl,
    required this.title,
    required this.price,
    this.soldPrice,
    required this.favoriteCount,
  });

  @override
  State<_FavoriteListTile> createState() => _FavoriteListTileState();
}

class _FavoriteListTileState extends State<_FavoriteListTile> {
  bool _busy = false;

  Future<void> _unlike() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FavoriteService.toggle(widget.docId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('favorite_update_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSale = widget.soldPrice != null && widget.soldPrice! > 0 && widget.soldPrice! < widget.price;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
            child: SizedBox(
              width: 80,
              height: 80,
              child: widget.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: AppColors.creamDark,
                      child: Icon(Icons.image_outlined, color: AppColors.inkMuted),
                    )
                  : Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: ProductImageSettings.displayCacheSize,
                      cacheHeight: ProductImageSettings.displayCacheSize,
                      webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.creamDark,
                        child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  if (onSale)
                    Row(
                      children: [
                        Text(
                          '\$${widget.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${widget.soldPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.coral),
                        ),
                      ],
                    )
                  else
                    Text(
                      '\$${widget.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                    ),
                  if (widget.favoriteCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.favoriteCount == 1
                          ? S.fmt('likes_one', {'count': '${widget.favoriteCount}'})
                          : S.fmt('likes_count', {'count': '${widget.favoriteCount}'}),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _busy ? null : _unlike,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.favorite_rounded, color: AppColors.coral),
          ),
        ],
      ),
    );
  }
}
