import 'package:flutter/material.dart';

class AppAnimations {
  static Duration fast = const Duration(milliseconds: 200);
  static Duration normal = const Duration(milliseconds: 300);
  static Duration slow = const Duration(milliseconds: 400);

  static Curve easeInOut = Curves.easeInOut;
  static Curve easeOut = Curves.easeOut;

  static Widget fadeScale(
    Widget child, {
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: duration ?? normal,
      curve: curve ?? easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  static Widget slideUp(
    Widget child, {
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(
        begin: const Offset(0, 20),
        end: Offset.zero,
      ),
      duration: duration ?? normal,
      curve: curve ?? easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
