import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/top_slider_slide.dart';
import '../services/locale_service.dart';
import '../services/top_slider_service.dart' show TopSliderService;
import '../theme/app_theme.dart';
import '../utils/hero_slider_settings.dart';
import 'family_zone_brand.dart';
import 'hero_slider_manage_sheet.dart';

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
              : _slides.isEmpty
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
          itemBuilder: (context, index) => _SlidePage(
            slide: _slides[index],
            sliderSize: _sliderSize,
            isActive: index == _page,
            onTap: () => _onSlideTap(_slides[index]),
          ),
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
          Positioned(
            left: 0,
            right: 0,
            top: widget.isWide ? 52 : 46,
            child: Center(
              child: _categoryChip(_slides[_page.clamp(0, _slides.length - 1)]),
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

  Widget _categoryChip(TopSliderSlide slide) {
    final label = _slideLabel(slide.category);
    if (label.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
        ),
      ),
    );
  }

  String _slideLabel(TopSliderCategory category) {
    switch (category) {
      case TopSliderCategory.male:
        return S.of('hero_slide_male');
      case TopSliderCategory.female:
        return S.of('hero_slide_female');
      case TopSliderCategory.boy:
        return S.of('hero_slide_boy');
      case TopSliderCategory.girl:
        return S.of('hero_slide_girl');
      case TopSliderCategory.sale:
        return S.of('hero_slide_sale');
      case TopSliderCategory.unknown:
        return '';
    }
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

class _SlidePage extends StatefulWidget {
  final TopSliderSlide slide;
  final HeroSliderSize sliderSize;
  final bool isActive;
  final VoidCallback onTap;

  const _SlidePage({
    required this.slide,
    required this.sliderSize,
    required this.isActive,
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
    final error = DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.heroGradient),
      child: Center(child: Icon(Icons.image_outlined, color: AppColors.white.withValues(alpha: 0.6), size: 40)),
    );

    final cacheWidth = kIsWeb ? null : HeroSliderSettings.uploadMaxWidth(widget.sliderSize);

    return SizedBox.expand(
      child: Image.network(
        widget.slide.imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheWidth,
        webHtmlElementStrategy: WebHtmlElementStrategy.never,
        errorBuilder: (_, __, err) {
          debugPrint('Hero slide failed (${widget.slide.imageUrl}): $err');
          return error;
        },
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
