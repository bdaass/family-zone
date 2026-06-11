import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class DashboardHero extends StatefulWidget {
  final VoidCallback? onContactTap;
  final bool isWide;

  const DashboardHero({super.key, this.onContactTap, this.isWide = false});

  @override
  State<DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends State<DashboardHero> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final AnimationController _marqueeController;

  static const _fashionTagKeys = [
    'hero_tag_summer_dresses',
    'hero_tag_kids_sneakers',
    'hero_tag_linen_shirts',
    'hero_tag_silk_scarves',
    'hero_tag_winter_coats',
    'hero_tag_sport_wear',
    'hero_tag_handbags',
    'hero_tag_family_looks',
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _marqueeController = AnimationController(vsync: this, duration: const Duration(seconds: 18));

    if (!kIsWeb) {
      _floatController.repeat(reverse: true);
      _shimmerController.repeat(reverse: true);
      _marqueeController.repeat();
    } else {
      _floatController.value = 0.35;
      _shimmerController.value = 0.5;
      _marqueeController.value = 0.2;
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shimmerController.dispose();
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.isWide ? 188.0 : 160.0;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(widget.isWide ? 20 : 16, 8, widget.isWide ? 20 : 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.elevationShadow(opacity: 0.18, blur: 32, y: 14),
            ),
            child: Stack(
                children: [
                _glowOrb(right: -30, top: -40, size: 140, color: AppColors.coral, drift: 0),
                _glowOrb(left: -20, bottom: -50, size: 120, color: AppColors.violet, drift: 0.5),
                _glowOrb(left: widget.isWide ? 200 : 80, top: 20, size: 90, color: AppColors.gold, drift: 0.25),
                ..._floatingIcons(),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, widget.isWide ? 22 : 16, 20, widget.isWide ? 14 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _newInBadge(),
                      ),
                      SizedBox(height: widget.isWide ? 12 : 8),
                      Flexible(
                        child: Text(
                          S.of('hero_headline'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: widget.isWide ? 26 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -0.5,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: widget.isWide ? 10 : 8),
                      Row(
                        children: [
                          Expanded(child: _marqueeTags()),
                          SizedBox(width: widget.isWide ? 10 : 6),
                          _whatsappChip(compact: !widget.isWide),
                        ],
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _glowOrb({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
    required double drift,
  }) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = (_floatController.value + drift) % 1.0;
        final offset = (t - 0.5) * 16;
        return Positioned(
          left: left,
          right: right,
          top: top != null ? top + offset : null,
          bottom: bottom != null ? bottom - offset : null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withValues(alpha: 0.32), Colors.transparent]),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _floatingIcons() {
    final items = widget.isWide
        ? [
            (Icons.checkroom_rounded, 0.0, 148.0, 22.0),
            (Icons.ice_skating_rounded, 0.35, 88.0, 48.0),
            (Icons.shopping_bag_outlined, 0.7, 28.0, 30.0),
          ]
        : [
            (Icons.checkroom_rounded, 0.0, 108.0, 18.0),
            (Icons.ice_skating_rounded, 0.35, 62.0, 42.0),
            (Icons.shopping_bag_outlined, 0.7, 16.0, 26.0),
          ];

    final textDirection = Directionality.of(context);

    return items.map((entry) {
      final (icon, phase, end, top) = entry;
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, _) {
          final t = (_floatController.value + phase) % 1.0;
          final bob = (t - 0.5) * 12;
          final spin = (t - 0.5) * 0.1;
          return Positioned.directional(
            textDirection: textDirection,
            end: end,
            top: top + bob,
            child: Transform.rotate(
              angle: spin,
              child: Container(
                padding: EdgeInsets.all(widget.isWide ? 10 : 8),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: AppColors.white.withValues(alpha: 0.85), size: widget.isWide ? 26 : 22),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _newInBadge() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment(-1 + _shimmerController.value * 2, 0),
              end: Alignment(_shimmerController.value * 2, 0),
              colors: [
                AppColors.gold.withValues(alpha: 0.35),
                AppColors.goldLight.withValues(alpha: 0.7),
                AppColors.gold.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.5)),
          ),
          child: child,
        );
      },
      child: Text(
        S.of('hero_new_in'),
        style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4),
      ),
    );
  }

  Widget _marqueeTags() {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _marqueeController,
          builder: (context, _) {
            return OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(-_marqueeController.value * 420, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 2; i++)
                      ..._fashionTagKeys.map(
                        (key) => S.of(key),
                      ).map(
                        (tag) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _whatsappChip({bool compact = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onContactTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: compact ? const EdgeInsets.all(9) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppColors.elevationShadow(opacity: 0.12, blur: 12, y: 4),
          ),
          child: compact
              ? const Icon(Icons.chat_rounded, size: 18, color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        S.of('hero_contact_us'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
