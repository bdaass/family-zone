import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';

/// Age group + sex selectors for staff forms.
class AudienceFields extends StatelessWidget {
  final String? ageGroup;
  final String? sex;
  final ValueChanged<String?> onAgeGroupChanged;
  final ValueChanged<String?> onSexChanged;
  final bool dense;
  final bool requireExplicitChoice;

  const AudienceFields({
    super.key,
    required this.ageGroup,
    required this.sex,
    required this.onAgeGroupChanged,
    required this.onSexChanged,
    this.dense = false,
    this.requireExplicitChoice = false,
  });

  bool _isAgeValue(String? value) {
    if (value == null) return false;
    return ProductCatalog.ageGroups.contains(value) ||
        (requireExplicitChoice && ProductCatalog.isNotDetermined(value));
  }

  bool _isSexValue(String? value) {
    if (value == null) return false;
    return ProductCatalog.sexes.contains(value) ||
        (requireExplicitChoice && ProductCatalog.isNotDetermined(value));
  }

  String _sexLabel(String sexValue) {
    final age = ageGroup ?? '';
    if (ProductCatalog.isNotDetermined(age) || ProductCatalog.isNotDetermined(sexValue)) {
      return ProductCatalog.sexFormLabel(ageGroup: age, sex: sexValue);
    }
    return ProductCatalog.sexFormLabel(ageGroup: age, sex: sexValue);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: dense ? 12 : 14);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('age-$ageGroup'),
            initialValue: _isAgeValue(ageGroup) ? ageGroup : null,
            decoration: InputDecoration(labelText: S.of('field_age_group'), isDense: dense),
            hint: requireExplicitChoice
                ? Text(S.of('field_please_select'), style: textStyle.copyWith(color: Colors.grey))
                : null,
            items: [
              if (requireExplicitChoice)
                DropdownMenuItem(
                  value: ProductCatalog.notDetermined,
                  child: Text(ProductCatalog.notDeterminedLabel(), style: textStyle),
                ),
              ...ProductCatalog.ageGroups.map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(ProductCatalog.ageGroupLabel(v), style: textStyle),
                ),
              ),
            ],
            onChanged: onAgeGroupChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('sex-$sex'),
            initialValue: _isSexValue(sex) ? sex : null,
            decoration: InputDecoration(labelText: S.of('field_sex'), isDense: dense),
            hint: requireExplicitChoice
                ? Text(S.of('field_please_select'), style: textStyle.copyWith(color: Colors.grey))
                : null,
            items: [
              if (requireExplicitChoice)
                DropdownMenuItem(
                  value: ProductCatalog.notDetermined,
                  child: Text(ProductCatalog.notDeterminedLabel(), style: textStyle),
                ),
              ...ProductCatalog.sexes.map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(_sexLabel(v), style: textStyle),
                ),
              ),
            ],
            onChanged: onSexChanged,
          ),
        ),
      ],
    );
  }
}
