import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft animated mesh orbs behind the catalogue — static offsets on web for stability.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drift;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _drift = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (!kIsWeb) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) {
        final t = _drift.value;
        return IgnorePointer(
          child: Stack(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.meshGradient),
                child: SizedBox.expand(),
              ),
              _orb(
                color: AppColors.coral.withValues(alpha: 0.18),
                size: 340,
                left: -80 + (t * 40),
                top: 40 + (t * 30),
              ),
              _orb(
                color: AppColors.violet.withValues(alpha: 0.14),
                size: 420,
                right: -120 - (t * 35),
                top: 180 - (t * 25),
              ),
              _orb(
                color: AppColors.gold.withValues(alpha: 0.12),
                size: 280,
                left: MediaQuery.sizeOf(context).width * 0.35,
                bottom: 120 + (t * 20),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orb({
    required Color color,
    required double size,
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
