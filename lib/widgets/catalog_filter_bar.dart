import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import 'price_range_filter.dart';

/// Filter surface — age, sex, season, category, sale, and price.
class CatalogFilterBar extends StatelessWidget {
  final String currentAgeGroup;
  final String currentSex;
  final String currentSeason;
  final String currentCategory;
  final bool saleOnly;
  final double priceMin;
  final double priceMax;
  final ValueChanged<String> onAgeGroupChanged;
  final ValueChanged<String> onSexChanged;
  final ValueChanged<String> onSeasonChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onSaleOnlyChanged;
  final ValueChanged<RangeValues> onPriceRangeChanged;
  final ValueChanged<RangeValues>? onPriceRangeCommit;
  final VoidCallback? onClearAll;
  final bool showClear;
  final bool compact;

  const CatalogFilterBar({
    super.key,
    required this.currentAgeGroup,
    required this.currentSex,
    required this.currentSeason,
    required this.currentCategory,
    required this.saleOnly,
    required this.priceMin,
    required this.priceMax,
    required this.onAgeGroupChanged,
    required this.onSexChanged,
    required this.onSeasonChanged,
    required this.onCategoryChanged,
    required this.onSaleOnlyChanged,
    required this.onPriceRangeChanged,
    this.onPriceRangeCommit,
    this.onClearAll,
    this.showClear = true,
    this.compact = false,
  });

  bool get _hasActive =>
      currentAgeGroup != 'All' ||
      currentSex != 'All' ||
      currentSeason != 'All Seasons' ||
      currentCategory != 'All Categories' ||
      saleOnly ||
      ProductCatalog.hasActivePriceFilter(priceMin, priceMax);

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(S.of('field_age_group'), ProductCatalog.filterAgeGroups, currentAgeGroup, onAgeGroupChanged),
        SizedBox(height: gap),
        _row(
          S.of('field_sex'),
          ProductCatalog.filterSexes,
          currentSex,
          onSexChanged,
          ageGroupFilter: currentAgeGroup,
        ),
        SizedBox(height: gap),
        _row(S.of('filter_season'), ProductCatalog.filterSeasons, currentSeason, onSeasonChanged),
        SizedBox(height: gap),
        _row(S.of('filter_type'), ProductCatalog.filterCategories, currentCategory, onCategoryChanged),
        SizedBox(height: gap),
        _saleRow(),
        SizedBox(height: gap),
        PriceRangeFilter(
          min: priceMin,
          max: priceMax,
          compact: compact,
          onChanged: onPriceRangeChanged,
          onChangeEnd: onPriceRangeCommit,
        ),
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

  Widget _row(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String> onChanged, {
    String ageGroupFilter = 'All',
  }) {
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
                label: ProductCatalog.filterPillLabel(value, ageGroupFilter: ageGroupFilter),
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
                  label: ProductCatalog.filterPillLabel(value, ageGroupFilter: ageGroupFilter),
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
