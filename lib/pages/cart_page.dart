import 'package:flutter/material.dart';

import '../config/store_config.dart';
import '../l10n/app_strings.dart';
import '../models/cart_item.dart';
import '../models/product_catalog.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_image_settings.dart';
import '../widgets/product_image_carousel.dart';

/// Full-screen cart — avoids stacking modals over product detail.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CartPage(),
      ),
    );
  }

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkout() async {
    final items = CartService.instance.items;
    if (items.isEmpty || _checkingOut) return;

    setState(() => _checkingOut = true);
    try {
      final result = await OrderService.checkoutViaWhatsApp(items);
      if (!mounted) return;

      switch (result) {
        case WhatsAppLaunchResult.opened:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                OrderService.checkoutHint != null
                    ? S.of('checkout_whatsapp_web_opened')
                    : S.of('checkout_whatsapp_opened'),
              ),
            ),
          );
        case WhatsAppLaunchResult.copiedToClipboard:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                S.fmt('checkout_order_copied', {'phone': StoreConfig.storeDisplayNumber}),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        case WhatsAppLaunchResult.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of('checkout_failed'))),
          );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, color: AppColors.ink, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                S.fmt('cart_title', {'count': '${cart.itemCount}'}),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
            ),
          ],
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(onPressed: () => cart.clear(), child: Text(S.of('clear'))),
        ],
      ),
      body: cart.items.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartLineTile(
                        item: item,
                        onQuantityChanged: (q) => cart.updateQuantity(item.cartKey, q),
                        onRemove: () => cart.removeItem(item.cartKey),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(S.of('subtotal'), style: const TextStyle(fontSize: 14, color: AppColors.inkMuted)),
                            Text(
                              '\$${cart.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (OrderService.checkoutHint != null) ...[
                          Text(
                            OrderService.checkoutHint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _checkingOut ? null : _checkout,
                            icon: _checkingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.chat_rounded),
                            label: Text(OrderService.checkoutButtonLabel),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.inkMuted.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              S.of('cart_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _CartLineTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
            child: SizedBox(
              width: 72,
              height: 72,
              child: item.imageUrl.isEmpty
                  ? const ColoredBox(color: AppColors.creamDark, child: Icon(Icons.image_outlined))
                  : ProductNetworkImage(
                      url: item.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: ProductImageSettings.displayCacheSize,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.fmt('cart_line_size', {'size': item.selectedSize}),
                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
                  if (item.selectedColor.isNotEmpty)
                    Text(
                      S.fmt('cart_line_color', {'color': ProductCatalog.colorDisplayName(item.selectedColor)}),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _smallIconBtn(Icons.remove, item.quantity > 1 ? () => onQuantityChanged(item.quantity - 1) : null),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      _smallIconBtn(Icons.add, () => onQuantityChanged(item.quantity + 1)),
                      const Spacer(),
                      Text(
                        '\$${item.lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _smallIconBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.creamDark),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.inkMuted : AppColors.ink),
      ),
    );
  }
}
