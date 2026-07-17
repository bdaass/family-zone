import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_color.dart';
import '../theme/app_theme.dart';

/// RGB color picker that returns a normalized `#RRGGBB` string.
Future<String?> showProductColorPicker(
  BuildContext context, {
  Color initialColor = const Color(0xFFC62828),
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ProductColorPickerDialog(initialColor: initialColor),
  );
}

class _ProductColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ProductColorPickerDialog({required this.initialColor});

  @override
  State<_ProductColorPickerDialog> createState() => _ProductColorPickerDialogState();
}

class _ProductColorPickerDialogState extends State<_ProductColorPickerDialog> {
  late double _r;
  late double _g;
  late double _b;

  @override
  void initState() {
    super.initState();
    final argb = widget.initialColor.toARGB32();
    _r = ((argb >> 16) & 0xFF).toDouble();
    _g = ((argb >> 8) & 0xFF).toDouble();
    _b = (argb & 0xFF).toDouble();
  }

  Color get _color => Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  String get _hex => ProductColor.colorToHex(_color);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of('color_picker_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.creamDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hex,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            _channelSlider(
              label: S.of('color_picker_r'),
              value: _r,
              activeColor: const Color(0xFFC62828),
              onChanged: (v) => setState(() => _r = v),
            ),
            _channelSlider(
              label: S.of('color_picker_g'),
              value: _g,
              activeColor: const Color(0xFF2E7D32),
              onChanged: (v) => setState(() => _g = v),
            ),
            _channelSlider(
              label: S.of('color_picker_b'),
              value: _b,
              activeColor: const Color(0xFF1565C0),
              onChanged: (v) => setState(() => _b = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of('color_picker_cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _hex),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.white,
          ),
          child: Text(S.of('color_picker_use')),
        ),
      ],
    );
  }

  Widget _channelSlider({
    required String label,
    required double value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
            ),
            const Spacer(),
            Text(
              '${value.round()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            thumbColor: activeColor,
            inactiveTrackColor: activeColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            max: 255,
            divisions: 255,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
