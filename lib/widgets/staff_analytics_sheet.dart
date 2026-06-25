import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/catalog_migration_service.dart';
import '../services/staff_insights_service.dart';
import '../theme/app_theme.dart';
import 'product_image_carousel.dart';

class StaffAnalyticsSheet extends StatefulWidget {
  final bool isAdmin;

  const StaffAnalyticsSheet({super.key, this.isAdmin = false});

  static Future<void> show(BuildContext context, {bool isAdmin = false}) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StaffAnalyticsSheet(isAdmin: isAdmin),
    );
  }

  @override
  State<StaffAnalyticsSheet> createState() => _StaffAnalyticsSheetState();
}

class _StaffAnalyticsSheetState extends State<StaffAnalyticsSheet> {
  late Future<StaffInsightsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = StaffInsightsService.fetch();
  }

  void _refresh() {
    setState(() => _future = StaffInsightsService.fetch());
  }

  Future<void> _resetInventory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of('migration_reset_inventory')),
        content: Text(S.of('migration_reset_inventory_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.of('confirm'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await CatalogMigrationService.resetAllProductInventory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.fmt('migration_reset_inventory_done', {'count': '${result.updated}'}))),
      );
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('migration_reset_inventory_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

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
                const Icon(Icons.insights_rounded, color: AppColors.ink, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of('analytics_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                  ),
                ),
                IconButton(tooltip: S.of('retry'), onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<StaffInsightsSnapshot>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                }
                if (snap.hasError || !snap.hasData) {
                  return Center(child: Text(S.of('products_load_error_detail')));
                }

                final data = snap.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (widget.isAdmin) ...[
                      OutlinedButton.icon(
                        onPressed: _resetInventory,
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(S.of('migration_reset_inventory')),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _SummaryRow(
                      label: S.of('analytics_pending_approval'),
                      value: '${data.pendingApprovalCount}',
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.coral,
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: S.of('analytics_top_viewed'),
                      empty: S.of('analytics_empty'),
                      items: data.topViewed
                          .map((p) => _InsightLine(
                                productId: p.productId,
                                imageUrl: p.imageUrl,
                                title: p.title,
                                meta: S.fmt('analytics_views', {'count': '${p.viewCount}'}),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: S.of('analytics_top_favorited'),
                      empty: S.of('analytics_empty'),
                      items: data.topFavorited
                          .map((p) => _InsightLine(
                                productId: p.productId,
                                imageUrl: p.imageUrl,
                                title: p.title,
                                meta: S.fmt('analytics_favorites', {'count': '${p.favoriteCount}'}),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: S.of('analytics_low_stock'),
                      empty: S.of('analytics_low_stock_empty'),
                      items: data.lowStock
                          .map((p) {
                            final meta = p.sold
                                ? S.of('badge_sold_out')
                                : S.fmt('analytics_stock_left', {'count': '${p.stockQty ?? 0}'});
                            return _InsightLine(
                              productId: p.productId,
                              imageUrl: p.imageUrl,
                              title: p.title,
                              meta: meta,
                              alert: true,
                            );
                          })
                          .toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String empty;
  final List<Widget> items;

  const _Section({required this.title, required this.empty, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(empty, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted))
        else
          ...items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  final String productId;
  final String? imageUrl;
  final String title;
  final String meta;
  final bool alert;

  const _InsightLine({
    required this.productId,
    this.imageUrl,
    required this.title,
    required this.meta,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alert ? AppColors.coral.withValues(alpha: 0.08) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alert ? AppColors.coral.withValues(alpha: 0.25) : AppColors.creamDark),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl != null
                  ? ProductThumbnail(imageUrl: imageUrl!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppColors.creamDark,
                      child: Icon(Icons.image_not_supported_outlined, size: 18, color: AppColors.inkMuted.withValues(alpha: 0.6)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  S.fmt('product_id_label', {'id': productId}),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(meta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: alert ? AppColors.coral : AppColors.inkMuted)),
        ],
      ),
    );
  }
}
