import 'package:flutter/animation.dart';

class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 440);

  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve smooth = Curves.easeInOutCubicEmphasized;
  static const Curve settle = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
}
