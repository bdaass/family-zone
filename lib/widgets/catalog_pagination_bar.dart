import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Page numbers (1, 2, 3 …) with previous / next controls.
class CatalogPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageSelected;

  const CatalogPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1 && currentPage <= 1) return const SizedBox.shrink();

    final pages = _visiblePages(currentPage, totalPages);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              label: S.of('page_prev'),
              enabled: currentPage > 1 && !isLoading,
              onTap: () => onPageSelected(currentPage - 1),
            ),
            for (final item in pages) ...[
              if (item == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…', style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
                )
              else
                _PageChip(
                  page: item,
                  selected: item == currentPage,
                  enabled: !isLoading,
                  onTap: () => onPageSelected(item),
                ),
            ],
            _NavButton(
              icon: Icons.chevron_right_rounded,
              label: S.of('page_next'),
              enabled: currentPage < totalPages && !isLoading,
              onTap: () => onPageSelected(currentPage + 1),
              trailing: true,
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.coral),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns page numbers and `null` for ellipsis gaps.
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

class _PageChip extends StatelessWidget {
  final int page;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PageChip({
    required this.page,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.coral : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.coral : AppColors.inkMuted.withValues(alpha: 0.25),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$page',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool trailing;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.coral,
        disabledForegroundColor: AppColors.inkMuted.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!trailing) Icon(icon, size: 20),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (trailing) Icon(icon, size: 20),
        ],
      ),
    );
  }
}
