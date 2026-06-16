import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';

/// Staff add-item dropdown — optional explicit placeholder + "Not determined".
class StaffChoiceDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final String Function(String option) optionLabel;
  final ValueChanged<String?> onChanged;
  final bool requireExplicitChoice;
  final bool dense;

  const StaffChoiceDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.requireExplicitChoice = false,
    this.dense = false,
  });

  bool _isValidValue(String? candidate) {
    if (candidate == null) return false;
    return options.contains(candidate) ||
        (requireExplicitChoice && ProductCatalog.isNotDetermined(candidate));
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: dense ? 12 : 14);
    final items = <DropdownMenuItem<String>>[
      if (requireExplicitChoice)
        DropdownMenuItem(
          value: ProductCatalog.notDetermined,
          child: Text(ProductCatalog.notDeterminedLabel(), style: textStyle),
        ),
      ...options.map(
        (option) => DropdownMenuItem(
          value: option,
          child: Text(optionLabel(option), style: textStyle),
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: _isValidValue(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: dense,
      ),
      hint: requireExplicitChoice
          ? Text(S.of('field_please_select'), style: textStyle.copyWith(color: Colors.grey))
          : null,
      items: items,
      onChanged: onChanged,
    );
  }
}
