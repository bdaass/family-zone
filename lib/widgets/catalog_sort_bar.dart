import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/catalog_sort.dart';
import '../theme/app_theme.dart';

class CatalogSortBar extends StatelessWidget {
  final CatalogSort selected;
  final ValueChanged<CatalogSort> onChanged;
  final bool compact;

  const CatalogSortBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: compact ? 16 : 18, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          for (final option in CatalogSortX.options) ...[
            _SortChip(
              label: S.of(option.labelKey),
              selected: selected == option,
              compact: compact,
              onTap: () => onChanged(option),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.ink : AppColors.creamDark),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
