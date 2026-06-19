import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grouped block for staff add/edit product forms.
class StaffFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final bool dense;
  final List<Widget> children;

  const StaffFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
    this.dense = false,
  });

  static const gap = 12.0;
  static const gapDense = 10.0;

  double get _gap => dense ? gapDense : gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: dense ? 14 : 18),
      padding: EdgeInsets.fromLTRB(dense ? 12 : 14, dense ? 12 : 14, dense ? 12 : 14, dense ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: dense ? 28 : 32,
                height: dense ? 28 : 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: dense ? 15 : 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: dense ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _gap),
          ..._spacedChildren(),
        ],
      ),
    );
  }

  List<Widget> _spacedChildren() {
    if (children.isEmpty) return const [];
    final result = <Widget>[children.first];
    for (var i = 1; i < children.length; i++) {
      result.add(SizedBox(height: _gap));
      result.add(children[i]);
    }
    return result;
  }
}
