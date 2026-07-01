import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/top_slider_slide.dart';
import '../services/locale_service.dart';
import '../services/top_slider_service.dart' show TopSliderService;
import '../theme/app_theme.dart';
import '../utils/hero_slider_settings.dart';
import '../utils/web_platform.dart';
import 'family_zone_brand.dart';
import 'hero_slider_manage_sheet.dart';
import 'product_image_carousel.dart';

typedef TopSliderFilterCallback = void Function(TopSliderFilterAction action);

class DashboardHero extends StatefulWidget {
  final VoidCallback? onContactTap;
  final TopSliderFilterCallback? onCategoryTap;
  final bool isWide;
  final bool canManageSlides;
  final int refreshToken;

  const DashboardHero({
    super.key,
    this.onContactTap,
    this.onCategoryTap,
    this.isWide = false,
    this.canManageSlides = false,
    this.refreshToken = 0,
  });

  @override
  State<DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends State<DashboardHero> {
  final _pageController = PageController();
  Timer? _autoTimer;
  int _page = 0;
  List<TopSliderSlide> _slides = const [];
  bool _loading = true;

  static const _autoInterval = Duration(seconds: 5);

  HeroSliderSize get _sliderSize => HeroSliderSettings.sizeForLayout(isWideLayout: widget.isWide);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSlides();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWide != widget.isWide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSlides(clearCache: true);
      });
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSlides(clearCache: true);
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSlides({bool clearCache = false}) async {
    _autoTimer?.cancel();
    if (clearCache) TopSliderService.invalidateCache();
    if (!mounted) return;

    // iPhone Safari: skip hero images entirely — static banner only (prevents OOM on swipe).
    if (WebPlatform.isIOSWeb) {
      setState(() {
        _slides = const [];
        _loading = false;
        _page = 0;
      });
      return;
    }

    setState(() => _loading = true);

    final slides = await TopSliderService.fetchSlides(
      isArabic: LocaleService.instance.isArabic,
      size: _sliderSize,
    );
    if (!mounted) return;

    setState(() {
      _slides = slides;
      _loading = false;
      _page = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restartAutoPlay();
    });
  }

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    if (!mounted || _slides.length < 2) return;
    // Auto-advance is heavy on iPhone Safari; let shoppers swipe manually.
    if (WebPlatform.isMobileWeb) return;

    _autoTimer = Timer.periodic(_autoInterval, (_) {
      if (!mounted || !_pageController.hasClients || _slides.isEmpty) return;
      final next = (_page + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _page = index);
    _restartAutoPlay();
  }

  void _onSlideTap(TopSliderSlide slide) {
    final action = slide.filterAction;
    if (action != null) widget.onCategoryTap?.call(action);
  }

  void _openManageSheet() {
    HeroSliderManageSheet.show(
      context,
      initialSize: _sliderSize,
      onUpdated: () => _loadSlides(clearCache: true),
    );
  }

  Widget _heroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: AppColors.creamDark,
        elevation: 0,
        shadowColor: AppColors.ink.withValues(alpha: 0.12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.elevationShadow(opacity: 0.14, blur: 28, y: 12),
          ),
          child: _loading
              ? _loadingState()
              : !WebPlatform.showDashboardHero || _slides.isEmpty
                  ? _fallbackHero()
                  : _sliderHero(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.isWide ? 20.0 : 16.0;
    final height = HeroSliderSettings.displayHeight(isWideLayout: widget.isWide);

    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(horizontal, 8, horizontal, 6),
          child: SizedBox(
            height: height,
            child: _heroCard(),
          ),
        );
      },
    );
  }

  Widget _loadingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
        Center(
          child: kIsWeb
              ? Icon(Icons.image_outlined, color: AppColors.white.withValues(alpha: 0.55), size: 32)
              : const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white),
                ),
        ),
      ],
    );
  }

  Widget _fallbackHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
        _logoBadge(compact: !widget.isWide),
        if (widget.canManageSlides) _manageButton(),
        PositionedDirectional(
          end: 14,
          bottom: 14,
          child: _whatsappButton(compact: !widget.isWide),
        ),
      ],
    );
  }

  Widget _sliderHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          clipBehavior: Clip.hardEdge,
          onPageChanged: _onPageChanged,
          itemCount: _slides.length,
          itemBuilder: (context, index) {
            // Phones: only decode the visible slide (same UX, less memory).
            final loadImage = !WebPlatform.isMobileWeb || index == _page;
            return _SlidePage(
              slide: _slides[index],
              sliderSize: _sliderSize,
              isActive: index == _page,
              loadImage: loadImage,
              onTap: () => _onSlideTap(_slides[index]),
            );
          },
        ),
        PositionedDirectional(
          top: 12,
          start: 12,
          child: _logoBadge(compact: !widget.isWide),
        ),
        if (widget.canManageSlides) _manageButton(),
        PositionedDirectional(
          end: 12,
          bottom: 12,
          child: _whatsappButton(compact: !widget.isWide),
        ),
        if (_slides.isNotEmpty)
          PositionedDirectional(
            start: 14,
            bottom: 26,
            end: 14,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: _HeroCategoryBadge(
                key: ValueKey(_slides[_page.clamp(0, _slides.length - 1)].category),
                category: _slides[_page.clamp(0, _slides.length - 1)].category,
                compact: !widget.isWide,
                lite: WebPlatform.isMobileWeb,
              ),
            ),
          ),
        if (_slides.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _dotIndicator(),
          ),
      ],
    );
  }

  Widget _manageButton() {
    return PositionedDirectional(
      top: 12,
      end: 12,
      child: Material(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _openManageSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_rounded, size: 16, color: AppColors.coral),
                if (widget.isWide) ...[
                  const SizedBox(width: 6),
                  Text(
                    S.of('hero_manage_slides'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.coral),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoBadge({required bool compact}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.elevationShadow(opacity: 0.1, blur: 16, y: 4),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 8),
        child: compact
            ? FamilyZoneBrand.logoOnly(size: compact ? 34 : 38)
            : FamilyZoneBrand.compact(),
      ),
    );
  }

  Widget _dotIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.white : AppColors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _whatsappButton({required bool compact}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onContactTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: compact ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppColors.elevationShadow(opacity: 0.18, blur: 14, y: 4),
          ),
          child: compact
              ? const Icon(Icons.chat_rounded, size: 18, color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(S.of('hero_contact_us'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroCategoryBadge extends StatefulWidget {
  final TopSliderCategory category;
  final bool compact;
  final bool lite;

  const _HeroCategoryBadge({
    super.key,
    required this.category,
    required this.compact,
    this.lite = false,
  });

  @override
  State<_HeroCategoryBadge> createState() => _HeroCategoryBadgeState();
}

class _HeroCategoryBadgeState extends State<_HeroCategoryBadge> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.lite) return;
    final pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulse = pulse;
    pulse.forward();
  }

  @override
  void didUpdateWidget(covariant _HeroCategoryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lite) return;
    if (oldWidget.category != widget.category) {
      _pulse?.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  ({String label, IconData icon, Gradient gradient}) _style(TopSliderCategory category) {
    switch (category) {
      case TopSliderCategory.male:
        return (
          label: S.of('hero_slide_male'),
          icon: Icons.man_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
        );
      case TopSliderCategory.female:
        return (
          label: S.of('hero_slide_female'),
          icon: Icons.woman_rounded,
          gradient: AppColors.primaryGradient,
        );
      case TopSliderCategory.boy:
        return (
          label: S.of('hero_slide_boy'),
          icon: Icons.boy_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0F766E)]),
        );
      case TopSliderCategory.girl:
        return (
          label: S.of('hero_slide_girl'),
          icon: Icons.girl_rounded,
          gradient: const LinearGradient(colors: [Color(0xFFDB2777), Color(0xFF7C3AED)]),
        );
      case TopSliderCategory.sale:
        return (
          label: S.of('hero_slide_sale'),
          icon: Icons.local_offer_rounded,
          gradient: AppColors.goldGradient,
        );
      case TopSliderCategory.unknown:
        return (
          label: '',
          icon: Icons.category_rounded,
          gradient: const LinearGradient(colors: [AppColors.ink, AppColors.ink]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(widget.category);
    if (style.label.isEmpty) return const SizedBox.shrink();

    final badge = _badgeBody(style);
    if (widget.lite) {
      return IgnorePointer(child: badge);
    }

    final pulse = _pulse!;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.06), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOutCubic));

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(scale: scale.value, child: child),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: badge,
        ),
      ),
    );
  }

  Widget _badgeBody(({String label, IconData icon, Gradient gradient}) style) {
    return Container(
      key: ValueKey(widget.category),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: widget.lite
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                ...AppColors.glowShadow(AppColors.coral, blur: 24),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(style.icon, color: AppColors.white, size: widget.compact ? 18 : 22),
            ),
          ),
          SizedBox(width: widget.compact ? 8 : 10),
          Text(
            style.label.toUpperCase(),
            style: TextStyle(
              color: AppColors.white,
              fontSize: widget.compact ? 13 : 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              shadows: widget.lite
                  ? null
                  : const [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatefulWidget {
  final TopSliderSlide slide;
  final HeroSliderSize sliderSize;
  final bool isActive;
  final bool loadImage;
  final VoidCallback onTap;

  const _SlidePage({
    super.key,
    required this.slide,
    required this.sliderSize,
    required this.isActive,
    this.loadImage = true,
    required this.onTap,
  });

  @override
  State<_SlidePage> createState() => _SlidePageState();
}

class _SlidePageState extends State<_SlidePage> with SingleTickerProviderStateMixin {
  AnimationController? _zoomController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _zoomController = AnimationController(vsync: this, duration: const Duration(seconds: 6));
      if (widget.isActive) _zoomController!.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _SlidePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _zoomController;
    if (controller == null) return;

    if (widget.isActive && !oldWidget.isActive) {
      controller.forward(from: 0);
    } else if (!widget.isActive && oldWidget.isActive) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    _zoomController?.dispose();
    super.dispose();
  }

  Widget _slideImage() {
    if (!widget.loadImage) {
      return SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)));
    }

    final cacheWidth = HeroSliderSettings.displayCacheWidth(widget.sliderSize);

    return SizedBox.expand(
      child: ProductNetworkImage(
        url: widget.slide.imageUrl,
        fit: BoxFit.cover,
        cacheWidth: kIsWeb ? null : cacheWidth,
      ),
    );
  }

  Widget _slideGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.ink.withValues(alpha: 0.35),
            AppColors.ink.withValues(alpha: 0.05),
            AppColors.ink.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _zoomController;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller == null)
            _slideImage()
          else
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final scale = 1.0 + (controller.value * 0.06);
                return Transform.scale(scale: scale, child: child);
              },
              child: _slideImage(),
            ),
          _slideGradient(),
        ],
      ),
    );
  }
}
