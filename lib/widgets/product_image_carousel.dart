import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';
import '../utils/web_platform.dart';

/// Single product photo for grids and lists (no carousel timers).
class ProductThumbnail extends StatelessWidget {
  final String imageUrl;
  final int extraPhotoCount;
  final BoxFit fit;

  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    this.extraPhotoCount = 0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ProductNetworkImage(
          url: imageUrl,
          fit: fit,
          cacheWidth: ProductImageSettings.displayCacheSize,
          cacheHeight: ProductImageSettings.displayCacheSize,
        ),
        if (extraPhotoCount > 0)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, size: 12, color: AppColors.white),
                  const SizedBox(width: 4),
                  Text(
                    '+$extraPhotoCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Product photos — swipeable carousel when [interactive] and multiple URLs.
class ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final bool autoPlay;
  final Duration interval;
  final BoxFit fit;
  final bool showIndicators;
  final bool interactive;
  final int? focusIndex;

  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 3),
    this.fit = BoxFit.cover,
    this.showIndicators = false,
    this.interactive = false,
    this.focusIndex,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  Timer? _timer;
  int _index = 0;
  PageController? _pageController;

  List<String> get _urls => widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();

  bool get _canSwipe => widget.interactive && _urls.length > 1;

  int get _detailCacheSize => ProductImageSettings.detailCacheSize;

  @override
  void initState() {
    super.initState();
    if (_canSwipe) _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final couldSwipe = oldWidget.interactive &&
        oldWidget.imageUrls.where((u) => u.trim().isNotEmpty).length > 1;
    if (_canSwipe && !couldSwipe) {
      _pageController ??= PageController();
    } else if (!_canSwipe && couldSwipe) {
      _pageController?.dispose();
      _pageController = null;
    }

    if (oldWidget.imageUrls != widget.imageUrls || oldWidget.autoPlay != widget.autoPlay) {
      _index = 0;
      if (_pageController?.hasClients == true) {
        _pageController!.jumpToPage(0);
      }
      _restartAutoPlay();
    } else if (widget.focusIndex != null &&
        widget.focusIndex != oldWidget.focusIndex &&
        widget.focusIndex! >= 0 &&
        widget.focusIndex! < _urls.length) {
      _index = widget.focusIndex!;
      if (_pageController?.hasClients == true) {
        _pageController!.jumpToPage(_index);
      } else {
        setState(() {});
      }
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (!widget.autoPlay || _urls.length < 2 || WebPlatform.isMobileWeb) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _urls.length < 2) return;
      setState(() => _index = (_index + 1) % _urls.length);
      if (_pageController?.hasClients == true) {
        _pageController!.animateToPage(
          _index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _restartAutoPlay() {
    _timer?.cancel();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Widget _carouselImage(String url) {
    return ProductNetworkImage(
      url: url,
      fit: widget.fit,
      cacheWidth: _detailCacheSize,
      cacheHeight: _detailCacheSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return const ColoredBox(
        color: AppColors.creamDark,
        child: Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 32)),
      );
    }

    if (!_canSwipe) {
      final idx = _index.clamp(0, urls.length - 1);
      return _carouselImage(urls[idx]);
    }

    final lazyLoad = WebPlatform.isMobileWeb;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          clipBehavior: Clip.hardEdge,
          itemCount: urls.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            WebPlatform.trimImageCacheIfNeeded();
          },
          itemBuilder: (context, i) {
            if (lazyLoad && i != _index) {
              return const ColoredBox(color: AppColors.creamDark);
            }
            return _carouselImage(urls[i]);
          },
        ),
        if (widget.showIndicators)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _CarouselDotIndicator(count: urls.length, index: _index),
          ),
      ],
    );
  }
}

class _CarouselDotIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _CarouselDotIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.white : AppColors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.35), blurRadius: 4)]
                : null,
          ),
        );
      }),
    );
  }
}

class ProductNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  const ProductNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 32));
    }

    return Image.network(
      url,
      fit: fit,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      filterQuality: WebPlatform.networkImageQuality,
      webHtmlElementStrategy: WebPlatform.networkImageStrategy,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: AppColors.creamDark,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Product image load failed: $error');
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32));
      },
    );
  }
}
