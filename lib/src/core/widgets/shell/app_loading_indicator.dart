import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 64,
    this.glyphSize = 38,
  });

  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = glyphSize / 38;

    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: ExpressiveLoadingIndicator(
            color: scheme.primary,
            constraints: const BoxConstraints.tightFor(
              width: 48,
              height: 48,
            ),
            semanticsLabel: 'Loading',
          ),
        ),
      ),
    );
  }
}
