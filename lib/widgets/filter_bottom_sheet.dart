import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';
import 'catalog_filter_bar.dart';

class FilterBottomSheet extends StatefulWidget {
  final String initialSeason;
  final String initialAgeGroup;
  final String initialSex;
  final String initialCategory;
  final bool initialSaleOnly;
  final double initialPriceMin;
  final double initialPriceMax;
  final void Function(
    String season,
    String ageGroup,
    String sex,
    String category,
    bool saleOnly,
    double priceMin,
    double priceMax,
  ) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialSeason,
    required this.initialAgeGroup,
    required this.initialSex,
    required this.initialCategory,
    required this.initialSaleOnly,
    required this.initialPriceMin,
    required this.initialPriceMax,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _season;
  late String _ageGroup;
  late String _sex;
  late String _category;
  late bool _saleOnly;
  late double _priceMin;
  late double _priceMax;

  @override
  void initState() {
    super.initState();
    _season = widget.initialSeason;
    _ageGroup = widget.initialAgeGroup;
    _sex = widget.initialSex;
    _category = widget.initialCategory;
    _saleOnly = widget.initialSaleOnly;
    _priceMin = widget.initialPriceMin;
    _priceMax = widget.initialPriceMax;
  }

  void _apply() {
    widget.onApply(_season, _ageGroup, _sex, _category, _saleOnly, _priceMin, _priceMax);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(S.of('filters_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 22)),
              ],
            ),
            const SizedBox(height: 8),
            CatalogFilterBar(
              currentAgeGroup: _ageGroup,
              currentSex: _sex,
              currentSeason: _season,
              currentCategory: _category,
              saleOnly: _saleOnly,
              priceMin: _priceMin,
              priceMax: _priceMax,
              onAgeGroupChanged: (v) => setState(() => _ageGroup = v),
              onSexChanged: (v) => setState(() => _sex = v),
              onSeasonChanged: (v) => setState(() => _season = v),
              onCategoryChanged: (v) => setState(() => _category = v),
              onSaleOnlyChanged: (v) => setState(() => _saleOnly = v),
              onPriceRangeChanged: (values) => setState(() {
                _priceMin = values.start;
                _priceMax = values.end;
              }),
              onClearAll: () => setState(() {
                _season = 'All Seasons';
                _ageGroup = 'All';
                _sex = 'All';
                _category = 'All Categories';
                _saleOnly = false;
                _priceMin = ProductCatalog.priceFilterFloor;
                _priceMax = ProductCatalog.priceFilterCeiling;
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(S.of('apply'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
