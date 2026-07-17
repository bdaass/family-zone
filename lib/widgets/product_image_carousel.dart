import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';
import '../utils/storage_media_url.dart';
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
  final bool showNavigationArrows;
  final bool enableKeyboardNavigation;
  final int? focusIndex;
  final int? decodeCacheSize;

  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 3),
    this.fit = BoxFit.cover,
    this.showIndicators = false,
    this.interactive = false,
    this.showNavigationArrows = false,
    this.enableKeyboardNavigation = false,
    this.focusIndex,
    this.decodeCacheSize,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  Timer? _timer;
  int _index = 0;
  PageController? _pageController;
  final FocusNode _focusNode = FocusNode();

  List<String> get _urls => widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();

  bool get _canSwipe => widget.interactive && _urls.length > 1;

  int get _imageCacheSize => widget.decodeCacheSize ?? ProductImageSettings.detailCacheSize;

  bool get _lazyLoadNeighbors => WebPlatform.isIOSWeb && !widget.showNavigationArrows;

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
      _goToIndex(widget.focusIndex!, animate: false);
    }
  }

  void _goToIndex(int index, {bool animate = true}) {
    final next = index.clamp(0, _urls.length - 1);
    if (next == _index && _pageController?.hasClients == true) return;
    setState(() => _index = next);
    if (_pageController?.hasClients == true) {
      if (animate) {
        _pageController!.animateToPage(
          next,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController!.jumpToPage(next);
      }
    }
  }

  void _goPrevious() {
    if (!_canSwipe || _index <= 0) return;
    _goToIndex(_index - 1);
  }

  void _goNext() {
    if (!_canSwipe || _index >= _urls.length - 1) return;
    _goToIndex(_index + 1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enableKeyboardNavigation || !_canSwipe) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _goPrevious();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _goNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (!widget.autoPlay || _urls.length < 2 || WebPlatform.isMobileWeb) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _urls.length < 2) return;
      final next = (_index + 1) % _urls.length;
      _goToIndex(next);
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
    _focusNode.dispose();
    super.dispose();
  }

  Widget _carouselImage(String url) {
    return ProductNetworkImage(
      url: url,
      fit: widget.fit,
      cacheWidth: _imageCacheSize,
      cacheHeight: _imageCacheSize,
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      clipBehavior: Clip.hardEdge,
      itemCount: _urls.length,
      onPageChanged: (i) {
        setState(() => _index = i);
        WebPlatform.trimImageCacheIfNeeded();
      },
      itemBuilder: (context, i) {
        if (_lazyLoadNeighbors && (i - _index).abs() > 1) {
          return const ColoredBox(color: AppColors.creamDark);
        }
        return _carouselImage(_urls[i]);
      },
    );
  }

  Widget _buildCarouselBody() {
    final pageView = _buildPageView();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.enableKeyboardNavigation && _canSwipe)
          Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: const SizedBox.expand(),
          ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (!_canSwipe) return;
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120) {
              _goNext();
            } else if (velocity > 120) {
              _goPrevious();
            }
          },
          child: pageView,
        ),
        if (widget.showNavigationArrows && _canSwipe) ...[
          PositionedDirectional(
            start: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselNavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: S.of('carousel_prev'),
                onPressed: _index > 0 ? _goPrevious : null,
              ),
            ),
          ),
          PositionedDirectional(
            end: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselNavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: S.of('carousel_next'),
                onPressed: _index < _urls.length - 1 ? _goNext : null,
              ),
            ),
          ),
        ],
        if (widget.showIndicators)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _CarouselDotIndicator(count: _urls.length, index: _index),
          ),
      ],
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

    return _buildCarouselBody();
  }
}

class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CarouselNavButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white.withValues(alpha: enabled ? 0.94 : 0.55),
        shape: const CircleBorder(),
        elevation: enabled ? 3 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 26,
              color: enabled ? AppColors.ink : AppColors.inkMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
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
  final Map<String, String>? httpHeaders;

  const ProductNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.cacheWidth,
    this.cacheHeight,
    this.httpHeaders,
  });

  Widget _placeholder() {
    return const ColoredBox(
      color: AppColors.creamDark,
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 28),
      ),
    );
  }

  WebHtmlElementStrategy _webImageStrategy(String url) {
    if (!kIsWeb) return WebPlatform.networkImageStrategy;
    final path = Uri.tryParse(url)?.path ?? url;
    if (path.contains('/media/product_images/')) {
      return WebHtmlElementStrategy.never;
    }
    return WebPlatform.networkImageStrategy;
  }

  @override
  Widget build(BuildContext context) {
    final raw = url.trim();
    if (raw.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 32));
    }

    final objectPath = StorageMediaUrl.objectPathFromUrl(raw);
    final resolvedUrl = objectPath != null && StorageMediaUrl.isStaffBarcodePath(objectPath)
        ? StorageMediaUrl.displayStaffUrl(raw)
        : StorageMediaUrl.displayUrl(raw);

    // Hero carousel uses null cache sizes on web — resize decode breaks <img> in some Chrome profiles.
    final effectiveCacheWidth = kIsWeb ? null : cacheWidth;
    final effectiveCacheHeight = kIsWeb ? null : cacheHeight;

    // Same-origin /media URLs: canvas decode — HTML <img> overlays break inside catalog grids.
    final htmlStrategy = _webImageStrategy(resolvedUrl);

    return Image.network(
      resolvedUrl,
      headers: httpHeaders,
      fit: fit,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: effectiveCacheWidth,
      cacheHeight: effectiveCacheHeight,
      gaplessPlayback: true,
      filterQuality: WebPlatform.networkImageQuality,
      webHtmlElementStrategy: htmlStrategy,
      loadingBuilder: kIsWeb
          ? null
          : (context, child, progress) {
              if (progress == null) return child;
              return _placeholder();
            },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Product image load failed: $error');
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32));
      },
    );
  }
}
