import 'package:flutter/material.dart';

import '../pages/cart_page.dart';

/// @deprecated Use [CartPage.open] — cart is a full screen, not a bottom sheet.
class CartSheet {
  const CartSheet._();

  static Future<void> show(BuildContext context) => CartPage.open(context);
}
