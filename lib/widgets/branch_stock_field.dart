import 'package:flutter/material.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../theme/app_theme.dart';

enum _BranchStockMode { unset, notDetermined, specified }

/// Quantity available per store branch (Tripoli / El Minieh / Halba).
class BranchStockField extends StatefulWidget {
  final Map<String, int?> initialValues;
  final bool requireExplicitChoice;
  final bool dense;
  final ValueChanged<Map<String, int?>> onChanged;
  final ValueChanged<Set<String>>? onAcknowledgedBranchesChanged;

  const BranchStockField({
    super.key,
    this.initialValues = const {},
    this.requireExplicitChoice = false,
    this.dense = false,
    required this.onChanged,
    this.onAcknowledgedBranchesChanged,
  });

  @override
  State<BranchStockField> createState() => _BranchStockFieldState();
}

class _BranchStockFieldState extends State<BranchStockField> {
  late final Map<String, TextEditingController> _controllers;
  final Map<String, _BranchStockMode> _modes = {};

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final branch in StoreConfig.locations)
        branch.id: TextEditingController(
          text: widget.initialValues[branch.id]?.toString() ?? '',
        ),
    };
    for (final branch in StoreConfig.locations) {
      final qty = widget.initialValues[branch.id];
      if (qty != null) {
        _modes[branch.id] = _BranchStockMode.specified;
      } else {
        _modes[branch.id] = _BranchStockMode.unset;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Set<String> get _acknowledgedBranches {
    return ProductCatalog.branchIds
        .where((id) => (_modes[id] ?? _BranchStockMode.unset) != _BranchStockMode.unset)
        .toSet();
  }

  Map<String, int?> _buildValues() {
    final values = <String, int?>{};
    for (final id in ProductCatalog.branchIds) {
      switch (_modes[id] ?? _BranchStockMode.unset) {
        case _BranchStockMode.specified:
          final text = _controllers[id]!.text.trim();
          if (text.isEmpty) break;
          final parsed = int.tryParse(text);
          values[id] = parsed ?? -1;
        case _BranchStockMode.notDetermined:
          values[id] = null;
        case _BranchStockMode.unset:
          break;
      }
    }
    return values;
  }

  void _notify() {
    widget.onChanged(_buildValues());
    widget.onAcknowledgedBranchesChanged?.call(_acknowledgedBranches);
  }

  void _setMode(String id, _BranchStockMode mode) {
    setState(() {
      _modes[id] = mode;
      if (mode == _BranchStockMode.notDetermined) {
        _controllers[id]!.clear();
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.dense ? 8.0 : 10.0;
    final chipStyle = TextStyle(fontSize: widget.dense ? 10 : 11, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('field_branch_stock'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        if (widget.requireExplicitChoice) ...[
          const SizedBox(height: 4),
          Text(
            S.of('field_branch_stock_hint'),
            style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
          ),
        ],
        SizedBox(height: gap),
        for (final branch in StoreConfig.locations) ...[
          Text(
            ProductCatalog.branchLabel(branch.id),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          if (widget.requireExplicitChoice) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(ProductCatalog.notDeterminedLabel(), style: chipStyle),
                  selected: _modes[branch.id] == _BranchStockMode.notDetermined,
                  onSelected: (_) => _setMode(branch.id, _BranchStockMode.notDetermined),
                ),
                ChoiceChip(
                  label: Text(S.of('field_stock_set_qty'), style: chipStyle),
                  selected: _modes[branch.id] == _BranchStockMode.specified,
                  onSelected: (_) => _setMode(branch.id, _BranchStockMode.specified),
                ),
              ],
            ),
            if (_modes[branch.id] == _BranchStockMode.specified) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _controllers[branch.id],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: S.of('field_branch_qty_hint'),
                  isDense: widget.dense,
                ),
                onChanged: (_) => _notify(),
              ),
            ],
          ] else ...[
            TextField(
              controller: _controllers[branch.id],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: S.of('field_branch_qty'),
                hintText: S.of('field_branch_qty_hint'),
                isDense: widget.dense,
              ),
              onChanged: (_) {
                final text = _controllers[branch.id]!.text.trim();
                _modes[branch.id] =
                    text.isEmpty ? _BranchStockMode.unset : _BranchStockMode.specified;
                _notify();
              },
            ),
          ],
          SizedBox(height: gap),
        ],
      ],
    );
  }
}

class BranchStockFieldValidation {
  static String? validate({
    required Map<String, int?> values,
    required bool requireExplicitChoice,
    required Set<String> acknowledgedBranches,
  }) {
    if (requireExplicitChoice) {
      if (acknowledgedBranches.length < ProductCatalog.branchIds.length) {
        return 'staff_validation_branch_stock';
      }
      for (final id in acknowledgedBranches) {
        if (!values.containsKey(id)) return 'staff_validation_branch_stock';
      }
    }

    for (final qty in values.values) {
      if (qty != null && qty < 0) return 'stock_qty_invalid';
    }
    return null;
  }
}
