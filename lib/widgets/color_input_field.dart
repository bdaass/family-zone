import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

/// Staff color entry — add removable chips (Black, Navy, Beige, …).
class ColorInputField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onEncodedChanged;
  final bool dense;
  final bool allowNotDetermined;
  final bool notDeterminedSelected;
  final VoidCallback? onNotDeterminedSelected;
  final VoidCallback? onColorsSpecified;

  const ColorInputField({
    super.key,
    this.initialValue = '',
    required this.onEncodedChanged,
    this.dense = false,
    this.allowNotDetermined = false,
    this.notDeterminedSelected = false,
    this.onNotDeterminedSelected,
    this.onColorsSpecified,
  });

  @override
  State<ColorInputField> createState() => _ColorInputFieldState();
}

class _ColorInputFieldState extends State<ColorInputField> {
  final _inputController = TextEditingController();
  late List<String> _colors;

  static const _quickColors = [
    'Black',
    'White',
    'Navy',
    'Beige',
    'Gray',
    'Red',
    'Pink',
    'Blue',
    'Green',
    'Brown',
  ];

  @override
  void initState() {
    super.initState();
    _colors = ProductCatalog.colorsFromField(widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChange());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onEncodedChanged(ProductCatalog.encodeColors(_colors));
  }

  void _addColor([String? raw]) {
    final value = (raw ?? _inputController.text).trim();
    if (value.isEmpty) return;

    final exists = _colors.any((c) => c.toLowerCase() == value.toLowerCase());
    if (exists) {
      _inputController.clear();
      return;
    }

    setState(() {
      _colors.add(value);
      _inputController.clear();
    });
    _notifyChange();
    widget.onColorsSpecified?.call();
  }

  void _selectNotDetermined() {
    setState(() => _colors.clear());
    _inputController.clear();
    widget.onEncodedChanged(ProductCatalog.notDetermined);
    widget.onNotDeterminedSelected?.call();
  }

  void _removeColor(String color) {
    setState(() => _colors.remove(color));
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.dense ? 6.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('field_colors'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        SizedBox(height: gap),
        if (widget.allowNotDetermined) ...[
          ActionChip(
            label: Text(
              ProductCatalog.notDeterminedLabel(),
              style: TextStyle(fontSize: widget.dense ? 10 : 11, fontWeight: FontWeight.w700),
            ),
            onPressed: _selectNotDetermined,
            backgroundColor: widget.notDeterminedSelected ? AppColors.ink : AppColors.white,
            labelStyle: TextStyle(color: widget.notDeterminedSelected ? AppColors.white : AppColors.ink),
            side: BorderSide(color: widget.notDeterminedSelected ? AppColors.ink : AppColors.creamDark),
          ),
          SizedBox(height: gap),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickColors.map((color) {
            final added = _colors.any((c) => c.toLowerCase() == color.toLowerCase());
            return ActionChip(
              label: Text(color, style: TextStyle(fontSize: widget.dense ? 10 : 11, fontWeight: FontWeight.w600)),
              onPressed: added ? null : () => _addColor(color),
              backgroundColor: added ? AppColors.creamDark : AppColors.white,
              side: BorderSide(color: added ? AppColors.creamDark : AppColors.creamDark.withValues(alpha: 0.8)),
            );
          }).toList(),
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  isDense: widget.dense,
                  hintText: S.of('field_color_input_hint'),
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 10 : 12),
                ),
                onSubmitted: _addColor,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _addColor(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(horizontal: widget.dense ? 12 : 14, vertical: widget.dense ? 12 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(S.of('field_color_add'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: gap),
        Text(
          S.of('field_color_helper'),
          style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
        ),
        if (_colors.isNotEmpty) ...[
          SizedBox(height: gap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) {
              return InputChip(
                label: Text(color, style: const TextStyle(fontWeight: FontWeight.w700)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeColor(color),
                backgroundColor: AppColors.cream,
                side: const BorderSide(color: AppColors.creamDark),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
