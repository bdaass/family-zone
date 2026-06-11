import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';
import 'contact_form_sheet.dart';

class SidebarStoreSection extends StatelessWidget {
  const SidebarStoreSection({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  Future<void> _openEmail() async {
    final uri = Uri(scheme: 'mailto', path: StoreConfig.storeEmail);
    await launchUrl(uri);
  }

  Future<void> _openPhone() async {
    final uri = Uri(scheme: 'tel', path: StoreConfig.storeDisplayNumber.replaceAll(' ', ''));
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        final isAr = S.isAr;

        return _SidebarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of('contact_us'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: FaIcon(FontAwesomeIcons.facebookF, size: 14, color: const Color(0xFF1877F2)),
                    tooltip: S.of('facebook'),
                    onTap: () => _openUrl(StoreConfig.facebookUrl),
                  ),
                  _ActionChip(
                    icon: FaIcon(FontAwesomeIcons.instagram, size: 14, color: const Color(0xFFE4405F)),
                    tooltip: S.of('instagram'),
                    onTap: () => _openUrl(StoreConfig.instagramUrl),
                  ),
                  _ActionChip(
                    icon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.ink),
                    tooltip: StoreConfig.storeDisplayNumber,
                    onTap: _openPhone,
                  ),
                  _ActionChip(
                    icon: const Icon(Icons.email_outlined, size: 18, color: AppColors.ink),
                    tooltip: StoreConfig.storeEmail,
                    onTap: _openEmail,
                  ),
                  _ActionChip(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.coral),
                    tooltip: S.of('send_message'),
                    onTap: () => ContactFormSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const RoundedRectangleBorder(),
                  iconColor: AppColors.inkMuted,
                  collapsedIconColor: AppColors.inkMuted,
                  title: Text(
                    S.of('store_info'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                  ),
                  children: [
                    for (final location in StoreConfig.locations)
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: isAr ? location.labelAr : location.labelEn,
                        onTap: () => _openUrl(StoreConfig.mapsUrl),
                      ),
                    _InfoLine(
                      icon: Icons.schedule_rounded,
                      text: isAr ? StoreConfig.workingHoursAr : StoreConfig.workingHoursEn,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SidebarLanguageBar extends StatelessWidget {
  const SidebarLanguageBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleService.instance.isArabic;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDark.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Expanded(child: _LangChip(label: S.of('english'), selected: !isAr, onTap: LocaleService.instance.setEnglish)),
          Expanded(child: _LangChip(label: S.of('arabic'), selected: isAr, onTap: LocaleService.instance.setArabic)),
        ],
      ),
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final Widget child;

  const _SidebarCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark.withValues(alpha: 0.65)),
      ),
      child: child,
    );
  }
}

class _ActionChip extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cream.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 42, height: 42, child: Center(child: icon)),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoLine({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.coral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkMuted, textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
