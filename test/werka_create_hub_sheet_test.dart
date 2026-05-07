import 'package:erpnext_stock_mobile/src/app/app_router.dart';
import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/features/werka/presentation/widgets/werka_create_hub_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    onGenerateRoute: (settings) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          body: Center(
            child: Text(settings.name ?? 'root'),
          ),
        ),
      );
    },
    navigatorObservers: navigatorObservers,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('Werka create hub starts as a medium expressive FAB',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final toggleFinder = find.byKey(const ValueKey('werka-hub-toggle-button'));
    expect(toggleFinder, findsOneWidget);
    expect(tester.getSize(toggleFinder).width, greaterThan(56));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('Werka create hub keeps the ordered action stack',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final orderedKeys = [
      const ValueKey('werka-hub-unannounced'),
      const ValueKey('werka-hub-qr-scan'),
      const ValueKey('werka-hub-gscale-mode'),
      const ValueKey('werka-hub-customer-issue'),
      const ValueKey('werka-hub-batch-dispatch'),
    ];
    final orderedFinders = [
      for (final key in orderedKeys) find.byKey(key),
    ];
    for (final finder in orderedFinders) {
      expect(finder, findsOneWidget);
    }

    final toggleSize =
        tester.getSize(find.byKey(const ValueKey('werka-hub-toggle-button')));
    expect(toggleSize.width, closeTo(56, 1.5));
    expect(toggleSize.height, closeTo(56, 1.5));
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    final centers = [
      for (final finder in orderedFinders) tester.getCenter(finder),
    ];
    for (var i = 1; i < centers.length; i++) {
      expect(
        centers[i].dy - centers[i - 1].dy,
        inInclusiveRange(60.0, 68.0),
      );
    }

    final bottomRect = tester.getRect(
      find.byKey(const ValueKey('werka-hub-batch-dispatch')),
    );
    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('werka-hub-toggle-button')),
    );
    expect(
      toggleRect.top - bottomRect.bottom,
      inInclusiveRange(8.0, 14.0),
    );
  });

  testWidgets('Werka create hub exposes GScale switch action', (tester) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
        navigatorObservers: [observer],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey('werka-hub-gscale-mode'));
    expect(switchFinder, findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(
      observer.pushedRouteNames,
      contains(AppRoutes.gscaleMode),
    );
  });

  testWidgets('Werka create hub toggle can reverse while opening',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final toggleFinder = find.byKey(const ValueKey('werka-hub-toggle-button'));
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(toggleFinder, findsNothing);
    expect(
      find.byKey(const ValueKey('werka-hub-batch-dispatch')),
      findsNothing,
    );
  });

  testWidgets('Werka create hub cards are full-surface tappable',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('werka-hub-batch-dispatch'));
    expect(
      find.descendant(of: cardFinder, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardFinder, matching: find.byType(Material)),
      findsWidgets,
    );
  });

  testWidgets('Werka create hub reveals cards from right to left',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final revealFinder = find.byKey(const ValueKey('werka-hub-reveal-0'));
    final revealEarly = tester.getSize(revealFinder);
    final titleFinder = find.text('Aytilmagan mahsulot');
    final titleEarly = tester.getTopLeft(titleFinder);

    await tester.pumpAndSettle();

    final revealLate = tester.getSize(revealFinder);
    final titleLate = tester.getTopLeft(titleFinder);

    expect(revealEarly.width, lessThan(revealLate.width));
    expect(titleEarly.dx, closeTo(titleLate.dx, 0.01));
  });

  testWidgets('Werka create hub toggle can reopen while closing',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            capturedContext = context;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showWerkaCreateHubSheet(context);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final toggleFinder = find.byKey(const ValueKey('werka-hub-toggle-button'));
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 40));
    showWerkaCreateHubSheet(capturedContext);
    await tester.pumpAndSettle();

    expect(toggleFinder, findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
        find.byKey(const ValueKey('werka-hub-batch-dispatch')), findsOneWidget);
  });
}

class _TestNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
