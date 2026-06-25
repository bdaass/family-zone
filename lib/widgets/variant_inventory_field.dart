import 'package:flutter/material.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../models/variant_inventory.dart';
import '../theme/app_theme.dart';

enum _BranchInventoryMode { unset, notDetermined, specified }

/// Staff inventory entry: per branch, per color, per size quantity.
class VariantInventoryField extends StatefulWidget {
  final VariantInventoryMap initialInventory;
  final bool requireExplicitChoice;
  final bool dense;
  final ValueChanged<VariantInventoryMap> onChanged;
  final ValueChanged<Set<String>>? onAcknowledgedBranchesChanged;

  const VariantInventoryField({
    super.key,
    this.initialInventory = const {},
    this.requireExplicitChoice = false,
    this.dense = false,
    required this.onChanged,
    this.onAcknowledgedBranchesChanged,
  });

  @override
  State<VariantInventoryField> createState() => _VariantInventoryFieldState();
}

class _VariantInventoryFieldState extends State<VariantInventoryField> {
  late VariantInventoryMap _inventory;
  final Map<String, _BranchInventoryMode> _branchModes = {};
  final Map<String, TextEditingController> _colorControllers = {};
  final Map<String, TextEditingController> _sizeControllers = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _inventory = _cloneInventory(widget.initialInventory);
    for (final branch in StoreConfig.locations) {
      final hasEntries = _inventory[branch.id]?.isNotEmpty == true;
      _branchModes[branch.id] =
          hasEntries ? _BranchInventoryMode.specified : _BranchInventoryMode.unset;
      _colorControllers[branch.id] = TextEditingController();
      _sizeControllers[branch.id] = TextEditingController();
      _qtyControllers[branch.id] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final controller in [
      ..._colorControllers.values,
      ..._sizeControllers.values,
      ..._qtyControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  VariantInventoryMap _cloneInventory(VariantInventoryMap source) {
    final clone = VariantInventory.empty();
    for (final branch in StoreConfig.locations) {
      final colors = source[branch.id];
      if (colors == null) continue;
      clone[branch.id] = {
        for (final colorEntry in colors.entries)
          colorEntry.key: Map<String, int>.from(colorEntry.value),
      };
    }
    return clone;
  }

  Set<String> get _acknowledgedBranches {
    return ProductCatalog.branchIds
        .where((id) => (_branchModes[id] ?? _BranchInventoryMode.unset) != _BranchInventoryMode.unset)
        .toSet();
  }

  void _notify() {
    widget.onChanged(_inventory);
    widget.onAcknowledgedBranchesChanged?.call(_acknowledgedBranches);
  }

  void _setBranchMode(String branchId, _BranchInventoryMode mode) {
    setState(() {
      _branchModes[branchId] = mode;
      if (mode == _BranchInventoryMode.notDetermined) {
        _inventory[branchId] = {};
      }
    });
    _notify();
  }

  void _removeColor(String branchId, String color) {
    setState(() {
      _inventory[branchId]?.remove(color);
    });
    _notify();
  }

  void _removeSize(String branchId, String color, String size) {
    setState(() {
      _inventory[branchId]?[color]?.remove(size);
      if (_inventory[branchId]?[color]?.isEmpty == true) {
        _inventory[branchId]?.remove(color);
      }
    });
    _notify();
  }

  void _addVariantLine(String branchId) {
    final color = _colorControllers[branchId]!.text.trim();
    final size = _sizeControllers[branchId]!.text.trim();
    final qty = int.tryParse(_qtyControllers[branchId]!.text.trim());
    if (color.isEmpty || size.isEmpty || qty == null || qty < 0) return;

    setState(() {
      _branchModes[branchId] = _BranchInventoryMode.specified;
      _inventory.putIfAbsent(branchId, () => {});
      final branch = _inventory[branchId]!;
      final existingColor = VariantInventory.findCanonicalColor({branchId: branch}, color) ?? color;
      branch.putIfAbsent(existingColor, () => {});
      final existingSize = VariantInventory.findCanonicalSize(branch, existingColor, size) ?? size;
      branch[existingColor]![existingSize] = qty;
      _colorControllers[branchId]!.clear();
      _sizeControllers[branchId]!.clear();
      _qtyControllers[branchId]!.clear();
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
          S.of('field_variant_inventory'),
          style: TextStyle(
            fontSize: widget.dense ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          S.of('field_variant_inventory_hint'),
          style: TextStyle(fontSize: widget.dense ? 10 : 11, color: AppColors.inkMuted, height: 1.35),
        ),
        SizedBox(height: gap),
        for (final branch in StoreConfig.locations) ...[
          _branchSection(branch.id, chipStyle, gap),
          SizedBox(height: gap),
        ],
      ],
    );
  }

  Widget _branchSection(String branchId, TextStyle chipStyle, double gap) {
    final mode = _branchModes[branchId] ?? _BranchInventoryMode.unset;
    final colors = _inventory[branchId] ?? {};

    return Container(
      padding: EdgeInsets.all(widget.dense ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProductCatalog.branchLabel(branchId),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
          if (widget.requireExplicitChoice) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(ProductCatalog.notDeterminedLabel(), style: chipStyle),
                  selected: mode == _BranchInventoryMode.notDetermined,
                  onSelected: (_) => _setBranchMode(branchId, _BranchInventoryMode.notDetermined),
                ),
                ChoiceChip(
                  label: Text(S.of('field_stock_set_qty'), style: chipStyle),
                  selected: mode == _BranchInventoryMode.specified,
                  onSelected: (_) => _setBranchMode(branchId, _BranchInventoryMode.specified),
                ),
              ],
            ),
          ],
          if (!widget.requireExplicitChoice || mode == _BranchInventoryMode.specified) ...[
            const SizedBox(height: 10),
            for (final colorEntry in colors.entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ProductCatalog.colorDisplayName(colorEntry.key),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: S.of('field_color_remove'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeColor(branchId, colorEntry.key),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final sizeEntry in colorEntry.value.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          sizeEntry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          S.fmt('variant_qty_label', {'count': '${sizeEntry.value}'}),
                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                        ),
                      ),
                      IconButton(
                        tooltip: S.of('field_size_remove'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeSize(branchId, colorEntry.key, sizeEntry.key),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: S.quickColorNames.map((color) {
                return ActionChip(
                  label: Text(
                    S.colorName(color),
                    style: TextStyle(fontSize: widget.dense ? 10 : 11, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    _colorControllers[branchId]!.text = color;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _colorControllers[branchId],
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      isDense: widget.dense,
                      labelText: S.of('color'),
                      hintText: S.of('field_color_input_hint'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _sizeControllers[branchId],
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: widget.dense,
                      labelText: S.of('size'),
                      hintText: S.of('field_size_input_hint'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyControllers[branchId],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: widget.dense,
                      labelText: S.of('field_branch_qty'),
                      hintText: S.of('field_branch_qty_hint'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () => _addVariantLine(branchId),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(S.of('variant_add_line'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VariantInventoryFieldValidation {
  static String? validate({
    required VariantInventoryMap inventory,
    required bool requireExplicitChoice,
    required Set<String> acknowledgedBranches,
  }) {
    if (requireExplicitChoice) {
      if (acknowledgedBranches.length < ProductCatalog.branchIds.length) {
        return 'staff_validation_branch_stock';
      }
    }

    if (!VariantInventory.hasAnyEntries(inventory)) {
      return 'variant_inventory_required';
    }

    for (final branch in inventory.values) {
      for (final colorSizes in branch.values) {
        for (final qty in colorSizes.values) {
          if (qty < 0) return 'stock_qty_invalid';
        }
      }
    }
    return null;
  }
}
