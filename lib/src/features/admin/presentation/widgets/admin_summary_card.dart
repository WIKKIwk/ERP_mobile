import '../../../../core/widgets/m3_segmented_list.dart';
import 'package:flutter/material.dart';

class AdminSummaryCard extends StatelessWidget {
  const AdminSummaryCard({
    super.key,
    required this.slot,
    required this.cornerRadius,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderRadiusOverride,
  });

  final M3SegmentVerticalSlot slot;
  final double cornerRadius;
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadiusOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final BorderRadius radius = borderRadiusOverride ??
        M3SegmentedListGeometry.borderRadius(slot, cornerRadius);
    final Color bg = backgroundColor ??
        switch (brightness) {
          Brightness.dark => scheme.surfaceContainerLow,
          Brightness.light => scheme.surfaceContainerHighest,
        };

    final Widget ink = Ink(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: child,
    );

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(onTap: onTap, borderRadius: radius, child: ink)
          : ink,
    );
  }
}
