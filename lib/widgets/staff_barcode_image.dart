import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/product_image_service.dart';
import '../utils/staff_media_auth.dart';
import '../utils/storage_media_url.dart';
import 'product_image_carousel.dart';

/// Admin barcode preview — same web rendering path as catalog product photos.
class StaffBarcodeImage extends StatefulWidget {
  final String imageUrl;
  final String storageProductId;
  final BoxFit fit;

  const StaffBarcodeImage({
    super.key,
    required this.imageUrl,
    required this.storageProductId,
    this.fit = BoxFit.contain,
  });

  static Future<({String url, Map<String, String>? headers})> resolve({
    required String imageUrl,
    required String storageProductId,
  }) async {
    final resolved = await ProductImageService.resolveBarcodeViewUrl(
      productStorageId: storageProductId,
      storedUrl: imageUrl,
    );
    final url = StorageMediaUrl.displayStaffUrl(resolved);
    final headers = kIsWeb ? await StaffMediaAuth.headers() : null;
    return (url: url, headers: headers);
  }

  @override
  State<StaffBarcodeImage> createState() => _StaffBarcodeImageState();
}

class _StaffBarcodeImageState extends State<StaffBarcodeImage> {
  late Future<({String url, Map<String, String>? headers})> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = StaffBarcodeImage.resolve(
      imageUrl: widget.imageUrl,
      storageProductId: widget.storageProductId,
    );
  }

  @override
  void didUpdateWidget(StaffBarcodeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.storageProductId != widget.storageProductId) {
      _loadFuture = StaffBarcodeImage.resolve(
        imageUrl: widget.imageUrl,
        storageProductId: widget.storageProductId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String url, Map<String, String>? headers})>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.url.isEmpty) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: AppColors.inkMuted, size: 32),
          );
        }
        final data = snapshot.data!;
        return ProductNetworkImage(
          url: data.url,
          fit: widget.fit,
          httpHeaders: data.headers,
        );
      },
    );
  }
}
