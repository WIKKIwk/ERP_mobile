import '../native_back_button_bridge.dart';
import 'package:flutter/material.dart';

bool useNativeBackButton(BuildContext context) {
  return NativeBackButtonBridge.shouldUseNativeBackButton(context);
}

bool useNativeNavigationTitle(BuildContext context, String title) {
  return NativeBackButtonBridge.useNativeNavigationTitle(context, title);
}

class NativeNavigationTitleHeader extends StatelessWidget {
  const NativeNavigationTitleHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final String title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final showFlutterBackButton = !useNativeNavigationTitle(context, title);
    if (!showFlutterBackButton) {
      return const SizedBox(height: 8);
    }
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          NativeBackButtonSlot(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class NativeBackButtonSlot extends StatelessWidget {
  const NativeBackButtonSlot({
    super.key,
    required this.onPressed,
    this.iconSize = 28,
  });

  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (useNativeBackButton(context)) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 52,
      width: 52,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(Icons.arrow_back_rounded, size: iconSize),
      ),
    );
  }
}
