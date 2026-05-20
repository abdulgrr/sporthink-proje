import 'package:flutter/material.dart';

import '../main.dart';
import 'app_assets.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 120,
    this.showGlow = true,
    this.borderRadius,
  });

  final double size;
  final bool showGlow;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: AppColors.primaryGradient,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 28,
                  spreadRadius: 6,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius * 0.75),
        child: Image.asset(
          AppAssets.logo,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.directions_run_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

