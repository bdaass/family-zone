import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/cart_item.dart';

enum WhatsAppLaunchResult { opened, copiedToClipboard, failed }

class OrderService {
  static const _maxEncodedTextLength = 1800;

  static String buildWhatsAppMessage(List<CartItem> items) {
    final user = FirebaseAuth.instance.currentUser;
    final buffer = StringBuffer();
    buffer.writeln(S.fmt('order_msg_greeting', {'store': S.of('store_name')}));
    buffer.writeln();

    var total = 0.0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      total += item.lineTotal;
      buffer.writeln('${i + 1}. ${item.title}');
      buffer.writeln('   ${S.fmt('order_msg_id', {'id': item.productId})}');
      buffer.writeln('   ${S.fmt('order_msg_size', {'size': item.selectedSize})}');
      if (item.selectedColor.isNotEmpty) {
        buffer.writeln('   ${S.fmt('order_msg_color', {'color': item.selectedColor})}');
      }
      buffer.writeln('   ${S.fmt('order_msg_qty', {'qty': '${item.quantity}'})}');
      buffer.writeln('   ${S.fmt('order_msg_price_each', {'price': item.unitPrice.toStringAsFixed(2)})}');
      buffer.writeln('   ${S.fmt('order_msg_subtotal', {'amount': item.lineTotal.toStringAsFixed(2)})}');
      buffer.writeln();
    }

    buffer.writeln(S.fmt('order_msg_total', {'amount': total.toStringAsFixed(2)}));
    buffer.writeln();
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      buffer.writeln(S.fmt('order_msg_customer', {'name': user.displayName!}));
    }
    if (user?.email != null) {
      buffer.writeln(S.fmt('order_msg_email', {'email': user!.email!}));
    }
    buffer.writeln(S.of('order_msg_footer'));

    return buffer.toString();
  }

  static String buildContactMessage() {
    final user = FirebaseAuth.instance.currentUser;
    final buffer = StringBuffer();
    buffer.writeln(S.fmt('contact_msg_greeting', {'store': S.of('store_name')}));
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      buffer.writeln(S.fmt('contact_msg_name', {'name': user.displayName!}));
    }
    if (user?.email != null) {
      buffer.writeln(S.fmt('order_msg_email', {'email': user!.email!}));
    }
    return buffer.toString();
  }

  static bool get _isMobileNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _useWhatsAppWeb =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static String get checkoutButtonLabel =>
      _useWhatsAppWeb ? S.of('checkout_button_web') : S.of('checkout_button_native');

  static String? get checkoutHint => _useWhatsAppWeb
      ? S.fmt('checkout_hint_web', {'phone': StoreConfig.storeDisplayNumber})
      : null;

  static Uri whatsAppUri(String message, {bool includeText = true}) {
    final phone = StoreConfig.whatsappNumber;
    final textFits = !includeText || Uri.encodeComponent(message).length <= _maxEncodedTextLength;

    if (_useWhatsAppWeb) {
      return Uri.https(
        'api.whatsapp.com',
        '/send',
        {
          'phone': phone,
          if (textFits) 'text': message,
        },
      );
    }

    if (textFits) {
      return Uri(scheme: 'https', host: 'wa.me', path: '/$phone', queryParameters: {'text': message});
    }

    return Uri(scheme: 'https', host: 'wa.me', path: '/$phone');
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: _useWhatsAppWeb ? '_blank' : null,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<WhatsAppLaunchResult> openWhatsApp(String message) async {
    if (message.trim().isEmpty) return WhatsAppLaunchResult.failed;

    final phone = StoreConfig.whatsappNumber;
    final textTooLong = Uri.encodeComponent(message).length > _maxEncodedTextLength;

    if (_isMobileNative) {
      final candidates = <Uri>[
        Uri(
          scheme: 'whatsapp',
          host: 'send',
          queryParameters: {
            'phone': phone,
            if (!textTooLong) 'text': message,
          },
        ),
        whatsAppUri(message, includeText: !textTooLong),
        Uri.https('api.whatsapp.com', '/send', {
          'phone': phone,
          if (!textTooLong) 'text': message,
        }),
      ];

      for (final uri in candidates) {
        if (await _tryLaunch(uri)) {
          if (textTooLong) await Clipboard.setData(ClipboardData(text: message));
          return WhatsAppLaunchResult.opened;
        }
      }
    } else {
      final webCandidates = <Uri>[
        whatsAppUri(message, includeText: !textTooLong),
        Uri.https('web.whatsapp.com', '/send', {
          'phone': phone,
          if (!textTooLong) 'text': message,
        }),
      ];

      for (final uri in webCandidates) {
        if (await _tryLaunch(uri)) {
          if (textTooLong) await Clipboard.setData(ClipboardData(text: message));
          return textTooLong ? WhatsAppLaunchResult.copiedToClipboard : WhatsAppLaunchResult.opened;
        }
      }
    }

    await Clipboard.setData(ClipboardData(text: message));
    return WhatsAppLaunchResult.copiedToClipboard;
  }

  static Future<WhatsAppLaunchResult> checkoutViaWhatsApp(List<CartItem> items) async {
    if (items.isEmpty) return WhatsAppLaunchResult.failed;
    return openWhatsApp(buildWhatsAppMessage(items));
  }

  static Future<WhatsAppLaunchResult> contactViaWhatsApp() async {
    return openWhatsApp(buildContactMessage());
  }
}
