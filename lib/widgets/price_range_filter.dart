import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

/// Dual-handle slider for catalog price range filtering.
class PriceRangeFilter extends StatelessWidget {
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues>? onChangeEnd;
  final bool compact;

  const PriceRangeFilter({
    super.key,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: compact ? 10 : 11,
      fontWeight: FontWeight.w700,
      color: AppColors.inkMuted,
      letterSpacing: 0.2,
    );

    final values = RangeValues(
      min.clamp(ProductCatalog.priceFilterFloor, ProductCatalog.priceFilterCeiling),
      max.clamp(ProductCatalog.priceFilterFloor, ProductCatalog.priceFilterCeiling),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!compact)
              SizedBox(width: 52, child: Text(S.of('filter_price'), style: labelStyle))
            else
              Text(S.of('filter_price'), style: labelStyle),
            const Spacer(),
            Text(
              ProductCatalog.formatPriceRange(values.start, values.end),
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                color: ProductCatalog.hasActivePriceFilter(values.start, values.end)
                    ? AppColors.coral
                    : AppColors.ink,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.coral,
            inactiveTrackColor: AppColors.creamDark,
            thumbColor: AppColors.ink,
            overlayColor: AppColors.coral.withValues(alpha: 0.12),
          ),
          child: RangeSlider(
            values: values,
            min: ProductCatalog.priceFilterFloor,
            max: ProductCatalog.priceFilterCeiling,
            divisions: ProductCatalog.priceFilterDivisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
