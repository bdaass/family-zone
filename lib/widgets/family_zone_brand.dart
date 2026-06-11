import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Store logo + "FAMILY ZONE" title.
class FamilyZoneBrand extends StatelessWidget {
  static const logoAssetPath = 'assets/images/logo.png';
  static const logoFullAssetPath = 'assets/images/logo_full.png';

  final double logoSize;
  final double fontSize;
  final double spacing;
  final double letterSpacing;
  final bool showTitle;

  const FamilyZoneBrand({
    super.key,
    this.logoSize = 44,
    this.fontSize = 18,
    this.spacing = 10,
    this.letterSpacing = 2,
    this.showTitle = true,
  });

  const FamilyZoneBrand.compact({super.key})
      : logoSize = 38,
        fontSize = 17,
        spacing = 10,
        letterSpacing = -0.3,
        showTitle = true;

  const FamilyZoneBrand.logoOnly({super.key, double size = 44})
      : logoSize = size,
        fontSize = 18,
        spacing = 10,
        letterSpacing = 2,
        showTitle = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          logoAssetPath,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
        if (showTitle) ...[
          SizedBox(width: spacing),
          ShaderMask(
            shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
            child: Text(
              S.of('brand_name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: letterSpacing,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
