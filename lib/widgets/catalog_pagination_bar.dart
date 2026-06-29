import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Styled page strip: Page 1 · Page 2 · … with prev / next controls.
class CatalogPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int? totalItems;
  final bool isLoading;
  final ValueChanged<int> onPageSelected;

  const CatalogPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.totalItems,
    required this.isLoading,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1 && currentPage <= 1 && totalItems == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final barWidth = constraints.maxWidth - 32;
        final maxBarWidth = barWidth < 640 ? barWidth : 640.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(compact),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: maxBarWidth,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 10 : 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.creamDark),
                    boxShadow: AppColors.elevationShadow(opacity: 0.07, blur: 20, y: 8),
                  ),
                  child: Row(
                    children: [
                      _RoundNavButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: S.of('page_prev'),
                        enabled: currentPage > 1 && !isLoading,
                        onTap: () => onPageSelected(currentPage - 1),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: _buildPageStrip(pages: _visiblePages(currentPage, totalPages), compact: compact),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.coral),
                          ),
                        )
                      else
                        _RoundNavButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: S.of('page_next'),
                          enabled: currentPage < totalPages,
                          onTap: () => onPageSelected(currentPage + 1),
                        ),
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

  Widget _buildSummaryRow(bool compact) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 8 : 10,
      runSpacing: 8,
      children: [
        Text(
          S.fmt('page_of', {'current': '$currentPage', 'total': '$totalPages'}),
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.inkMuted.withValues(alpha: 0.9),
          ),
        ),
        if (totalItems != null) _TotalItemsBadge(count: totalItems!, compact: compact),
      ],
    );
  }

  List<Widget> _buildPageStrip({required List<int?> pages, required bool compact}) {
    final widgets = <Widget>[];
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) {
        widgets.add(_Separator(compact: compact));
      }
      final item = pages[i];
      if (item == null) {
        widgets.add(_Ellipsis(compact: compact));
      } else {
        widgets.add(
          _PagePill(
            page: item,
            selected: item == currentPage,
            compact: compact,
            enabled: !isLoading,
            onTap: () => onPageSelected(item),
          ),
        );
      }
    }
    return widgets;
  }

  static List<int?> _visiblePages(int current, int total) {
    if (total <= 7) {
      return [for (var i = 1; i <= total; i++) i];
    }

    final pages = <int?>{1, total, current, current - 1, current + 1};
    if (current <= 3) {
      pages.addAll([2, 3, 4]);
    }
    if (current >= total - 2) {
      pages.addAll([total - 3, total - 2, total - 1]);
    }

    final sorted = pages.whereType<int>().where((p) => p >= 1 && p <= total).toList()..sort();
    final result = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        result.add(null);
      }
      result.add(sorted[i]);
    }
    return result;
  }
}

class _TotalItemsBadge extends StatelessWidget {
  final int count;
  final bool compact;

  const _TotalItemsBadge({required this.count, required this.compact});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppColors.glowShadow(AppColors.coral, blur: 14),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: compact ? 13 : 14, color: AppColors.white.withValues(alpha: 0.92)),
            const SizedBox(width: 5),
            Text(
              S.fmt('catalog_total_items', {'count': '$count'}),
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _RoundNavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? AppColors.cream : AppColors.cream.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 22,
              color: enabled ? AppColors.coral : AppColors.inkMuted.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  final bool compact;

  const _Separator({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: compact ? 16 : 18,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted.withValues(alpha: 0.35),
          height: 1,
        ),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  final bool compact;

  const _Ellipsis({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      child: Text(
        '…',
        style: TextStyle(
          fontSize: compact ? 14 : 15,
          fontWeight: FontWeight.w800,
          color: AppColors.inkMuted.withValues(alpha: 0.5),
          height: 1,
        ),
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  final int page;
  final bool selected;
  final bool compact;
  final bool enabled;
  final VoidCallback onTap;

  const _PagePill({
    required this.page,
    required this.selected,
    required this.compact,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = selected ? S.fmt('page_number', {'n': '$page'}) : '$page';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected ? AppColors.primaryGradient : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected ? AppColors.glowShadow(AppColors.coral, blur: 16) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: selected ? (compact ? 12 : 14) : (compact ? 8 : 10),
              vertical: compact ? 7 : 8,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
                letterSpacing: selected ? 0.2 : 0,
                color: selected ? AppColors.white : AppColors.ink.withValues(alpha: enabled ? 0.72 : 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
