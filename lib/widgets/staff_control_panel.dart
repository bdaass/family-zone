import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Compact staff toolbar — add-item form expands on demand.
class StaffControlPanel extends StatelessWidget {
  final String userRole;
  final bool addPanelOpen;
  final VoidCallback onToggleAddPanel;
  final VoidCallback onApprovalQueue;
  final VoidCallback onAnalytics;

  const StaffControlPanel({
    super.key,
    required this.userRole,
    required this.addPanelOpen,
    required this.onToggleAddPanel,
    required this.onApprovalQueue,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.creamDark),
          boxShadow: AppColors.elevationShadow(opacity: 0.06, blur: 20, y: 6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of('staff_control_title'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    S.roleLabel(userRole),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: addPanelOpen ? S.of('staff_close_add') : S.of('staff_add_item'),
                  icon: addPanelOpen ? Icons.expand_less_rounded : Icons.add_box_outlined,
                  filled: true,
                  onTap: onToggleAddPanel,
                ),
                _ActionChip(
                  label: S.of('approval_queue_title'),
                  icon: Icons.pending_actions_rounded,
                  onTap: onApprovalQueue,
                ),
                _ActionChip(
                  label: S.of('analytics_title'),
                  icon: Icons.insights_rounded,
                  onTap: onAnalytics,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.coral : AppColors.cream,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: filled ? AppColors.white : AppColors.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: filled ? AppColors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
