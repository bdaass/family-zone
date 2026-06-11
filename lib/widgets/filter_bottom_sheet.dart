import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'catalog_filter_bar.dart';

class FilterBottomSheet extends StatefulWidget {
  final String initialSeason;
  final String initialGender;
  final String initialCategory;
  final bool initialSaleOnly;
  final void Function(String season, String gender, String category, bool saleOnly) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialSeason,
    required this.initialGender,
    required this.initialCategory,
    required this.initialSaleOnly,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _season;
  late String _gender;
  late String _category;
  late bool _saleOnly;

  @override
  void initState() {
    super.initState();
    _season = widget.initialSeason;
    _gender = widget.initialGender;
    _category = widget.initialCategory;
    _saleOnly = widget.initialSaleOnly;
  }

  void _apply() {
    widget.onApply(_season, _gender, _category, _saleOnly);
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
            currentGender: _gender,
            currentSeason: _season,
            currentCategory: _category,
            saleOnly: _saleOnly,
            onGenderChanged: (v) => setState(() => _gender = v),
            onSeasonChanged: (v) => setState(() => _season = v),
            onCategoryChanged: (v) => setState(() => _category = v),
            onSaleOnlyChanged: (v) => setState(() => _saleOnly = v),
            onClearAll: () => setState(() {
              _season = 'All Seasons';
              _gender = 'All';
              _category = 'All Categories';
              _saleOnly = false;
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
    );
  }
}
