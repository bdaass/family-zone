import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen product view — used on web so nothing from the catalog paints above it.
class ProductDetailPage extends StatelessWidget {
  final Widget child;

  const ProductDetailPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: child),
    );
  }
}
