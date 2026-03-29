import 'package:flutter/material.dart';

class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration pageEnter = Duration(milliseconds: 360);
  static const Duration pageExit = Duration(milliseconds: 300);

  static const Curve standard = Easing.standard;
  static const Curve standardAccelerate = Easing.standardAccelerate;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
  static const Curve smooth = Easing.standard;
  static const Curve settle = Easing.emphasizedDecelerate;
  static const Curve pageIn = Easing.emphasizedDecelerate;
  static const Curve pageOut = Easing.emphasizedAccelerate;
  static const Curve spring = Curves.easeOutBack;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static bool isCupertinoPlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  static Duration adaptiveDuration(
    BuildContext context,
    Duration base, {
    Duration reducedDuration = Duration.zero,
    double cupertinoFactor = 0.88,
  }) {
    if (reduceMotion(context)) {
      return reducedDuration;
    }
    if (isCupertinoPlatform(context)) {
      return Duration(
        microseconds: (base.inMicroseconds * cupertinoFactor).round(),
      );
    }
    return base;
  }

  static Offset adaptiveOffset(
    BuildContext context,
    Offset base, {
    double cupertinoFactor = 0.72,
  }) {
    if (reduceMotion(context)) {
      return Offset.zero;
    }
    if (isCupertinoPlatform(context)) {
      return Offset(base.dx * cupertinoFactor, base.dy * cupertinoFactor);
    }
    return base;
  }

  static double adaptivePressScale(
    BuildContext context,
    double base, {
    double cupertinoFactor = 0.7,
  }) {
    if (reduceMotion(context)) {
      return 1;
    }
    if (isCupertinoPlatform(context)) {
      return 1 - ((1 - base) * cupertinoFactor);
    }
    return base;
  }
}
