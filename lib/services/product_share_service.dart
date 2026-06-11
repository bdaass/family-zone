import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';

class ProductShareService {
  ProductShareService._();

  static String productUrl(String productId) {
    final id = Uri.encodeComponent(productId.trim());
    return '${StoreConfig.webBaseUrl}/?p=$id';
  }

  static Future<void> shareProduct({
    required String productId,
    required String title,
    Rect? sharePositionOrigin,
  }) async {
    final url = productUrl(productId);
    final message = S.fmt('share_product_message', {'title': title, 'url': url});

    try {
      await Share.share(message, subject: title, sharePositionOrigin: sharePositionOrigin);
    } catch (e) {
      debugPrint('ProductShareService.share failed: $e');
      await Clipboard.setData(ClipboardData(text: url));
    }
  }
}
