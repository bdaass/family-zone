import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';

/// Age group (Kids / Adult) + sex (Female / Male) selectors for forms.
class AudienceFields extends StatelessWidget {
  final String ageGroup;
  final String sex;
  final ValueChanged<String> onAgeGroupChanged;
  final ValueChanged<String> onSexChanged;
  final bool dense;

  const AudienceFields({
    super.key,
    required this.ageGroup,
    required this.sex,
    required this.onAgeGroupChanged,
    required this.onSexChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: dense ? 12 : 14);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: ProductCatalog.ageGroups.contains(ageGroup) ? ageGroup : 'adult',
            decoration: InputDecoration(labelText: S.of('field_age_group'), isDense: dense),
            items: ProductCatalog.ageGroups
                .map((v) => DropdownMenuItem(value: v, child: Text(ProductCatalog.ageGroupLabel(v), style: textStyle)))
                .toList(),
            onChanged: (v) => onAgeGroupChanged(v!),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: ProductCatalog.sexes.contains(sex) ? sex : 'female',
            decoration: InputDecoration(labelText: S.of('field_sex'), isDense: dense),
            items: ProductCatalog.sexes
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(ProductCatalog.sexFormLabel(ageGroup: ageGroup, sex: v), style: textStyle),
                    ))
                .toList(),
            onChanged: (v) => onSexChanged(v!),
          ),
        ),
      ],
    );
  }
}
