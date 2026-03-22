import 'package:flutter/widgets.dart';

/// Scroll physics that keeps pull-to-refresh available at the top edge while
/// preventing bottom-edge overscroll on short lists.
class TopRefreshScrollPhysics extends BouncingScrollPhysics {
  const TopRefreshScrollPhysics({super.parent});

  static const double _maxTopRefreshOverscroll = 88.0;

  @override
  TopRefreshScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TopRefreshScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double minTopOffset =
        position.minScrollExtent - _maxTopRefreshOverscroll;
    if (value < minTopOffset) {
      return value - minTopOffset;
    }
    if (position.maxScrollExtent <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}
