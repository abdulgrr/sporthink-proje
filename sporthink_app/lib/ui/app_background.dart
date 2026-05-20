import 'dart:ui';

import 'package:flutter/material.dart';

import '../main.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.imageAsset,
    this.imageAlignment = Alignment.topCenter,
    this.imageOpacity = 0.18,
    this.overlayOpacity = 0.10,
    this.padding,
    this.useSafeArea = true,
    this.showBlobs = true,
    this.backgroundGradient,
    this.imageOverlayGradient,
    this.blurSigma = 8,
  });

  final Widget child;
  final String? imageAsset;
  final Alignment imageAlignment;
  final double imageOpacity;
  final double overlayOpacity;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;
  final bool showBlobs;
  final Gradient? backgroundGradient;
  final Gradient? imageOverlayGradient;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: backgroundGradient ??
            const LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
      ),
      child: Stack(
        children: [
          if (showBlobs) ...[
            // Soft blobs
            Positioned(
              top: -120,
              left: -120,
              child: _Blob(color: AppColors.primary.withOpacity(0.16), size: 260),
            ),
            Positioned(
              bottom: -140,
              right: -140,
              child: _Blob(color: AppColors.secondary.withOpacity(0.16), size: 300),
            ),
            Positioned(
              top: 120,
              right: -80,
              child: _Blob(color: AppColors.accent.withOpacity(0.12), size: 220),
            ),
          ],

          // Optional hero image
          if (imageAsset != null)
            Positioned.fill(
              child: Align(
                alignment: imageAlignment,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: imageOpacity,
                    child: Image.asset(
                      imageAsset!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

          if (imageOverlayGradient != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(gradient: imageOverlayGradient)),
              ),
            ),

          // A subtle frost overlay to unify visuals (optional)
          if (overlayOpacity > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: ColoredBox(color: Colors.black.withOpacity(overlayOpacity)),
                ),
              ),
            ),

          if (useSafeArea)
            SafeArea(
              child: Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            )
          else
            Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 60,
            spreadRadius: 18,
          ),
        ],
      ),
    );
  }
}

