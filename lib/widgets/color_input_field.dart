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

  static const _quickColors = S.quickColorNames;

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
              label: Text(S.colorName(color), style: TextStyle(fontSize: widget.dense ? 10 : 11, fontWeight: FontWeight.w600)),
              onPressed: added ? null : () => _addColor(color),
              backgroundColor: added ? AppColors.creamDark : AppColors.white,
              side: BorderSide(color: added ? AppColors.creamDark : AppColors.creamDark.withValues(alpha: 0.8)),
            );
          }).toList(),
        ),
        SizedBox(height: gap),
        RawAutocomplete<String>(
          textEditingController: _inputController,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return S.colorSuggestions.where((color) {
              final en = color.toLowerCase();
              final localized = S.colorName(color).toLowerCase();
              return en.contains(q) || localized.contains(q);
            });
          },
          displayStringForOption: S.colorName,
          onSelected: _addColor,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                isDense: widget.dense,
                hintText: S.of('field_color_input_hint'),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 10 : 12),
              ),
              onSubmitted: (_) {
                _addColor(controller.text);
                onFieldSubmitted();
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final color = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 10,
                          backgroundColor: ProductCatalog.colorSwatchFill(color),
                        ),
                        title: Text(S.colorName(color), style: const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => onSelected(color),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () => _addColor(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.white,
              padding: EdgeInsets.symmetric(horizontal: widget.dense ? 12 : 14, vertical: widget.dense ? 12 : 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of('field_color_add'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
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
                label: Text(S.colorName(color), style: const TextStyle(fontWeight: FontWeight.w700)),
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
