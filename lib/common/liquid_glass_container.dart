import 'dart:ui';

import 'package:flutter/material.dart';

/// A reusable container that applies a "Liquid Glass" (glassmorphism) effect.
///
/// It combines a backdrop blur with subtle gradients, borders, and glow to
/// deliver the shimmering translucent panels typical of liquid glass design.
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blurSigma = 24,
    this.opacity = 0.12,
    this.showShadow = true,
    this.showBorder = true,
    this.borderColor,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.enableBlur = true,
  });

  /// Content to display inside the liquid glass panel.
  final Widget child;

  /// Optional inner padding.
  final EdgeInsetsGeometry? padding;

  /// Optional outer margin.
  final EdgeInsetsGeometry? margin;

  /// Border radius used for clipping and decoration.
  final double borderRadius;

  /// Blur intensity for the background.
  final double blurSigma;

  /// Base opacity for the glass color when no gradient is provided.
  final double opacity;

  /// Enables or disables the soft shadow below the panel.
  final bool showShadow;

  /// Enables or disables the subtle border stroke.
  final bool showBorder;

  /// Optional custom border color.
  final Color? borderColor;

  /// Optional gradient override. When null a neutral translucent color is used.
  final List<Color>? gradientColors;

  /// Gradient start alignment when [gradientColors] is provided.
  final Alignment gradientBegin;

  /// Gradient end alignment when [gradientColors] is provided.
  final Alignment gradientEnd;

  /// Set to false to skip the expensive backdrop blur while keeping styling.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: gradientColors != null
          ? LinearGradient(
              begin: gradientBegin,
              end: gradientEnd,
              colors: gradientColors!,
            )
          : null,
      color: gradientColors == null
          ? Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
          : null,
      border: showBorder
          ? Border.all(
              color: (borderColor ?? Colors.white).withValues(alpha: 0.22),
              width: 1,
            )
          : null,
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.25 * opacity.clamp(0.0, 1.0)),
                blurRadius: 28,
                spreadRadius: -16,
                offset: const Offset(0, 18),
              ),
            ]
          : null,
    );

    final panel = Container(
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );

    final clippedPanel = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: panel,
    );

    if (!enableBlur) {
      return clippedPanel;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: panel,
      ),
    );
  }
}
