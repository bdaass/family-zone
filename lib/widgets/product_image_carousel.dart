import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';

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
        ProductNetworkImage(url: imageUrl, fit: fit),
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

/// Cycles through product photos (public images only — no barcode).
class ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final bool autoPlay;
  final Duration interval;
  final BoxFit fit;
  final bool showIndicators;
  final bool interactive;

  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 3),
    this.fit = BoxFit.cover,
    this.showIndicators = false,
    this.interactive = false,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  Timer? _timer;
  int _index = 0;
  late PageController? _pageController;

  List<String> get _urls => widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _pageController = widget.interactive ? PageController() : null;
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls || oldWidget.autoPlay != widget.autoPlay) {
      _index = 0;
      _pageController?.jumpToPage(0);
      _restartAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (!widget.autoPlay || _urls.length < 2) return;
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

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 32));
    }

    if (widget.interactive) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => ProductNetworkImage(url: _urls[i], fit: widget.fit),
          ),
          if (widget.showIndicators && _urls.length > 1) _dots(),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: ProductNetworkImage(
            key: ValueKey(_urls[_index]),
            url: _urls[_index],
            fit: widget.fit,
          ),
        ),
        if (widget.showIndicators && _urls.length > 1) _dots(),
      ],
    );
  }

  Widget _dots() {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_urls.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 8 : 6,
            height: active ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.white : AppColors.white.withValues(alpha: 0.55),
              boxShadow: active ? AppColors.elevationShadow(opacity: 0.2, blur: 4, y: 1) : null,
            ),
          );
        }),
      ),
    );
  }
}

class ProductNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const ProductNetworkImage({super.key, required this.url, required this.fit});

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
      cacheWidth: ProductImageSettings.displayCacheSize,
      cacheHeight: ProductImageSettings.displayCacheSize,
      webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Product image load failed: $error');
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32));
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        if (kIsWeb) {
          return const Center(child: Icon(Icons.image_outlined, color: AppColors.inkMuted, size: 28));
        }
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
          ),
        );
      },
    );
  }
}
