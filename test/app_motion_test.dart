import 'package:erpnext_stock_mobile/src/core/theme/app_motion.dart';
import 'package:erpnext_stock_mobile/src/core/widgets/motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppMotion shortens durations on iOS', (tester) async {
    Duration? resolved;

    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(platform: TargetPlatform.iOS),
          child: Builder(
            builder: (context) {
              resolved = AppMotion.adaptiveDuration(context, AppMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(resolved, isNotNull);
    expect(resolved! < AppMotion.medium, isTrue);
  });

  testWidgets('SmoothAppear skips decorative animation when disabled',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(
            body: SmoothAppear(
              child: Text('motion'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('motion'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('SoftReveal skips decorative animation when disabled',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(
            body: SoftReveal(
              child: Text('reveal'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('reveal'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}
