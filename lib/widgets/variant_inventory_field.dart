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
  final Map<String, String?> _selectedQuickColor = {};

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
      _selectedQuickColor[branch.id] = null;
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

  void _selectQuickColor(String branchId, String color) {
    setState(() {
      _selectedQuickColor[branchId] = color;
      _colorControllers[branchId]!.text = color;
    });
  }

  bool _isQuickColorSelected(String branchId, String color) {
    final picked = _selectedQuickColor[branchId];
    if (picked != null && picked.toLowerCase() == color.toLowerCase()) return true;
    final typed = _colorControllers[branchId]!.text.trim();
    return typed.isNotEmpty && typed.toLowerCase() == color.toLowerCase();
  }

  void _removeColor(String branchId, String color) {
    setState(() {
      _inventory[branchId]?.remove(color);
      if (_selectedQuickColor[branchId]?.toLowerCase() == color.toLowerCase()) {
        _selectedQuickColor[branchId] = null;
        _colorControllers[branchId]!.clear();
      }
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
      _selectedQuickColor[branchId] = existingColor;
      _colorControllers[branchId]!.text = existingColor;
      _sizeControllers[branchId]!.clear();
      _qtyControllers[branchId]!.clear();
    });
    _notify();
  }

  static Color _swatchFill(String name) {
    switch (name.toLowerCase().trim()) {
      case 'black':
        return const Color(0xFF1A1A1A);
      case 'white':
        return const Color(0xFFF4F4F4);
      case 'navy':
        return const Color(0xFF1B2A4A);
      case 'beige':
        return const Color(0xFFD8CBB8);
      case 'gray':
      case 'grey':
        return const Color(0xFF9E9E9E);
      case 'red':
        return const Color(0xFFC62828);
      case 'pink':
        return const Color(0xFFE891A8);
      case 'blue':
        return const Color(0xFF1565C0);
      case 'green':
        return const Color(0xFF2E7D32);
      case 'brown':
        return const Color(0xFF6D4C41);
      default:
        final hash = name.toLowerCase().codeUnits.fold(0, (sum, c) => sum + c);
        return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.42, 0.52).toColor();
    }
  }

  static Color _labelOnSwatch(Color fill) =>
      fill.computeLuminance() > 0.55 ? AppColors.ink : AppColors.white;

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
      padding: EdgeInsets.all(widget.dense ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDark),
        boxShadow: AppColors.elevationShadow(opacity: 0.04, blur: 12, y: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_outlined, size: 16, color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ProductCatalog.branchLabel(branchId),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
              ),
            ],
          ),
          if (widget.requireExplicitChoice) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(ProductCatalog.notDeterminedLabel(), style: chipStyle),
                  selected: mode == _BranchInventoryMode.notDetermined,
                  selectedColor: AppColors.creamDark,
                  onSelected: (_) => _setBranchMode(branchId, _BranchInventoryMode.notDetermined),
                ),
                ChoiceChip(
                  label: Text(S.of('field_stock_set_qty'), style: chipStyle),
                  selected: mode == _BranchInventoryMode.specified,
                  selectedColor: AppColors.coral.withValues(alpha: 0.2),
                  onSelected: (_) => _setBranchMode(branchId, _BranchInventoryMode.specified),
                ),
              ],
            ),
          ],
          if (!widget.requireExplicitChoice || mode == _BranchInventoryMode.specified) ...[
            if (colors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                S.of('variant_saved_stock'),
                style: TextStyle(
                  fontSize: widget.dense ? 10 : 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              for (final colorEntry in colors.entries)
                _savedColorCard(branchId, colorEntry.key, colorEntry.value),
            ],
            const SizedBox(height: 12),
            Text(
              S.of('variant_pick_color'),
              style: TextStyle(
                fontSize: widget.dense ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: S.quickColorNames.map((color) => _quickColorChip(branchId, color)).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorControllers[branchId],
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _selectedQuickColor[branchId] = null),
              decoration: InputDecoration(
                isDense: widget.dense,
                labelText: S.of('color'),
                hintText: S.of('field_color_input_hint'),
                prefixIcon: const Icon(Icons.palette_outlined, size: 20),
              ),
            ),
            SizedBox(height: gap),
            TextField(
              controller: _sizeControllers[branchId],
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                isDense: widget.dense,
                labelText: S.of('size'),
                hintText: S.of('field_size_input_hint'),
                prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
              ),
            ),
            SizedBox(height: gap),
            TextField(
              controller: _qtyControllers[branchId],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: widget.dense,
                labelText: S.of('field_branch_qty'),
                hintText: S.of('field_branch_qty_hint'),
                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _addVariantLine(branchId),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  S.of('variant_add_line'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(vertical: widget.dense ? 12 : 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickColorChip(String branchId, String color) {
    final fill = _swatchFill(color);
    final selected = _isQuickColorSelected(branchId, color);
    final labelColor = selected ? _labelOnSwatch(fill) : AppColors.ink;

    return Material(
      color: selected ? fill : AppColors.cream,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => _selectQuickColor(branchId, color),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.creamDark,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                    color: selected ? AppColors.white.withValues(alpha: 0.8) : AppColors.creamDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.colorName(color),
                style: TextStyle(
                  fontSize: widget.dense ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedColorCard(String branchId, String color, Map<String, int> sizes) {
    final fill = _swatchFill(color);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fill.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: AppColors.creamDark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ProductCatalog.colorDisplayName(color),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
              ),
              IconButton(
                tooltip: S.of('field_color_remove'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeColor(branchId, color),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizes.entries.map((sizeEntry) {
              return InputChip(
                label: Text(
                  S.fmt('variant_size_stock_line', {
                    'size': sizeEntry.key,
                    'count': '${sizeEntry.value}',
                  }),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeSize(branchId, color, sizeEntry.key),
                backgroundColor: AppColors.white,
                side: BorderSide(color: fill.withValues(alpha: 0.4)),
              );
            }).toList(),
          ),
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
