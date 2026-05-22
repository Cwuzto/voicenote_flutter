import 'dart:ui';

import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8F1),
            Color(0xFFFFF3FA),
            Color(0xFFF4F7FF),
            Color(0xFFF2FFFA),
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _PastelBlob(
              width: 260,
              height: 260,
              color: Color(0xFFFFCFE1),
              opacity: 0.55,
            ),
          ),

          Positioned(
            top: 80,
            right: -100,
            child: _PastelBlob(
              width: 300,
              height: 300,
              color: Color(0xFFDCCBFF),
              opacity: 0.48,
            ),
          ),

          Positioned(
            bottom: 80,
            left: -110,
            child: _PastelBlob(
              width: 280,
              height: 280,
              color: Color(0xFFBFEFFF),
              opacity: 0.45,
            ),
          ),

          Positioned(
            bottom: -120,
            right: -80,
            child: _PastelBlob(
              width: 330,
              height: 330,
              color: Color(0xFFCFF8E8),
              opacity: 0.52,
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          child,
        ],
      ),
    );
  }
}

class _PastelBlob extends StatelessWidget {
  const _PastelBlob({
    required this.width,
    required this.height,
    required this.color,
    required this.opacity,
  });

  final double width;
  final double height;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}