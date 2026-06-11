import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';
import 'catalog_filter_bar.dart';
import 'family_zone_brand.dart';
import 'sidebar_store_section.dart';

/// Sidebar / drawer — filters, store links, language.
class FilterSidebarContent extends StatelessWidget {
  final String? userRole;
  final String currentSeason;
  final String currentAgeGroup;
  final String currentSex;
  final String currentCategory;
  final bool saleOnly;
  final double priceMin;
  final double priceMax;
  final ValueChanged<String> onSeasonChanged;
  final ValueChanged<String> onAgeGroupChanged;
  final ValueChanged<String> onSexChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onSaleOnlyChanged;
  final ValueChanged<RangeValues> onPriceRangeChanged;
  final ValueChanged<RangeValues>? onPriceRangeCommit;
  final VoidCallback? onStaffPanelTap;
  final VoidCallback? onClearFilters;
  final bool showBrand;
  final bool isLoggedIn;
  final VoidCallback onSignIn;
  final VoidCallback? onSignOut;

  const FilterSidebarContent({
    super.key,
    this.userRole,
    required this.currentSeason,
    required this.currentAgeGroup,
    required this.currentSex,
    required this.currentCategory,
    required this.saleOnly,
    required this.priceMin,
    required this.priceMax,
    required this.onSeasonChanged,
    required this.onAgeGroupChanged,
    required this.onSexChanged,
    required this.onCategoryChanged,
    required this.onSaleOnlyChanged,
    required this.onPriceRangeChanged,
    this.onPriceRangeCommit,
    this.onStaffPanelTap,
    this.onClearFilters,
    this.showBrand = false,
    required this.isLoggedIn,
    required this.onSignIn,
    this.onSignOut,
  });

  bool get _isStaff => userRole == 'admin' || userRole == 'employee';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  if (showBrand) ...[
                    FamilyZoneBrand(key: ValueKey(LocaleService.instance.languageCode)),
                    const SizedBox(height: 4),
                    Text(
                      S.of('tagline'),
                      style: TextStyle(fontSize: 11, color: AppColors.inkMuted.withValues(alpha: 0.85), height: 1.35),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_isStaff)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextButton.icon(
                        onPressed: onStaffPanelTap,
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: Text(S.of('add_manage')),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        ),
                      ),
                    ),
                  _SidebarCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of('shop_by'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 14),
                        CatalogFilterBar(
                          compact: true,
                          currentAgeGroup: currentAgeGroup,
                          currentSex: currentSex,
                          currentSeason: currentSeason,
                          currentCategory: currentCategory,
                          saleOnly: saleOnly,
                          priceMin: priceMin,
                          priceMax: priceMax,
                          onAgeGroupChanged: onAgeGroupChanged,
                          onSexChanged: onSexChanged,
                          onSeasonChanged: onSeasonChanged,
                          onCategoryChanged: onCategoryChanged,
                          onSaleOnlyChanged: onSaleOnlyChanged,
                          onPriceRangeChanged: onPriceRangeChanged,
                          onPriceRangeCommit: onPriceRangeCommit,
                          onClearAll: onClearFilters,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SidebarStoreSection(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SidebarAuthBar(
                    isLoggedIn: isLoggedIn,
                    userRole: userRole,
                    onSignIn: onSignIn,
                    onSignOut: onSignOut,
                  ),
                  const SizedBox(height: 10),
                  const SidebarLanguageBar(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final Widget child;

  const _SidebarCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark.withValues(alpha: 0.65)),
      ),
      child: child,
    );
  }
}
