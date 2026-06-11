import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

/// Single, minimal filter surface — gender, season, category as clean pill rows.
class CatalogFilterBar extends StatelessWidget {
  final String currentGender;
  final String currentSeason;
  final String currentCategory;
  final bool saleOnly;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onSeasonChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onSaleOnlyChanged;
  final VoidCallback? onClearAll;
  final bool showClear;
  final bool compact;

  const CatalogFilterBar({
    super.key,
    required this.currentGender,
    required this.currentSeason,
    required this.currentCategory,
    required this.saleOnly,
    required this.onGenderChanged,
    required this.onSeasonChanged,
    required this.onCategoryChanged,
    required this.onSaleOnlyChanged,
    this.onClearAll,
    this.showClear = true,
    this.compact = false,
  });

  static const _genders = ['All', 'Woman', 'Man', 'Children'];
  static const _seasons = ['All Seasons', 'Summer', 'Winter', 'Sport'];
  static const _categories = ['All Categories', 'Clothes', 'Shoes', 'Lingery', 'Sac', 'Scarf'];

  bool get _hasActive =>
      currentGender != 'All' ||
      currentSeason != 'All Seasons' ||
      currentCategory != 'All Categories' ||
      saleOnly;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(S.of('filter_for'), _genders, currentGender, onGenderChanged),
        SizedBox(height: gap),
        _row(S.of('filter_season'), _seasons, currentSeason, onSeasonChanged),
        SizedBox(height: gap),
        _row(S.of('filter_type'), _categories, currentCategory, onCategoryChanged),
        SizedBox(height: gap),
        _saleRow(),
        if (showClear && _hasActive && onClearAll != null) ...[
          SizedBox(height: gap),
          TextButton.icon(
            onPressed: onClearAll,
            icon: Icon(Icons.refresh_rounded, size: compact ? 14 : 16),
            label: Text(S.of('clear')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMuted,
              padding: EdgeInsets.zero,
              textStyle: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _saleRow() {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of('filter_sale'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: S.of('filter_sale_all'),
                selected: !saleOnly,
                compact: true,
                onTap: () => onSaleOnlyChanged(false),
              ),
              _Pill(
                label: S.of('filter_sale_only'),
                selected: saleOnly,
                compact: true,
                onTap: () => onSaleOnlyChanged(true),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            S.of('filter_sale'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted, letterSpacing: 0.2),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _Pill(label: S.of('filter_sale_all'), selected: !saleOnly, onTap: () => onSaleOnlyChanged(false)),
              const SizedBox(width: 8),
              _Pill(label: S.of('filter_sale_only'), selected: saleOnly, onTap: () => onSaleOnlyChanged(true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, List<String> options, String selected, ValueChanged<String> onChanged) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((value) {
              return _Pill(
                label: ProductCatalog.filterPillLabel(value),
                selected: selected == value,
                compact: true,
                onTap: () => onChanged(value),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted, letterSpacing: 0.2),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = options[index];
                return _Pill(
                  label: ProductCatalog.filterPillLabel(value),
                  selected: selected == value,
                  onTap: () => onChanged(value),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.ink : AppColors.creamDark),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
