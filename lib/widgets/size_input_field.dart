import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

/// Staff size entry — add removable chips (41, M, XL, …).
class SizeInputField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onEncodedChanged;
  final bool dense;

  const SizeInputField({
    super.key,
    this.initialValue = '',
    required this.onEncodedChanged,
    this.dense = false,
  });

  @override
  State<SizeInputField> createState() => _SizeInputFieldState();
}

class _SizeInputFieldState extends State<SizeInputField> {
  final _inputController = TextEditingController();
  late List<String> _sizes;

  @override
  void initState() {
    super.initState();
    _sizes = ProductCatalog.sizesFromField(widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChange());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onEncodedChanged(ProductCatalog.encodeSizes(_sizes));
  }

  void _addSize([String? raw]) {
    final value = (raw ?? _inputController.text).trim();
    if (value.isEmpty) return;

    final exists = _sizes.any((size) => size.toLowerCase() == value.toLowerCase());
    if (exists) {
      _inputController.clear();
      return;
    }

    setState(() {
      _sizes.add(value);
      _inputController.clear();
    });
    _notifyChange();
  }

  void _removeSize(String size) {
    setState(() => _sizes.remove(size));
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.dense ? 6.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('field_size'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  isDense: widget.dense,
                  hintText: S.of('field_size_input_hint'),
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 10 : 12),
                ),
                onSubmitted: _addSize,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _addSize(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(horizontal: widget.dense ? 12 : 14, vertical: widget.dense ? 12 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(S.of('field_size_add'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: gap),
        Text(
          S.of('field_size_helper'),
          style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
        ),
        if (_sizes.isNotEmpty) ...[
          SizedBox(height: gap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sizes.map((size) {
              return InputChip(
                label: Text(size, style: const TextStyle(fontWeight: FontWeight.w700)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeSize(size),
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
