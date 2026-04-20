import 'package:erpnext_stock_mobile/src/core/widgets/app_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary navigation button is tappable and sized like a FAB',
      (tester) async {
    int selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppNavigationBar(
            height: 60,
            destinations: const [
              AppNavigationDestination(
                label: 'Home',
                icon: Icon(Icons.home_outlined),
              ),
              AppNavigationDestination(
                label: 'Search',
                icon: Icon(Icons.search_outlined),
              ),
              AppNavigationDestination(
                label: 'Create',
                icon: Icon(Icons.add_rounded),
                isPrimary: true,
              ),
              AppNavigationDestination(
                label: 'Files',
                icon: Icon(Icons.folder_outlined),
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (index) {
              selectedIndex = index;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final buttonFinder =
        find.byKey(const ValueKey('app-primary-navigation-button'));
    final navBarFinder = find.byType(NavigationBar);
    expect(buttonFinder, findsOneWidget);
    expect(navBarFinder, findsOneWidget);
    expect(tester.getSize(buttonFinder), const Size(84, 84));

    final buttonRect = tester.getRect(buttonFinder);
    final navBarRect = tester.getRect(navBarFinder);
    expect(buttonRect.top, lessThan(navBarRect.top));
    expect(buttonRect.bottom, lessThan(navBarRect.top - 8));

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('navigation bar ignores bottom system padding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(bottom: 32),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: AppNavigationBar(
              destinations: const [
                AppNavigationDestination(
                  label: 'Home',
                  icon: Icon(Icons.home_outlined),
                ),
                AppNavigationDestination(
                  label: 'Search',
                  icon: Icon(Icons.search_outlined),
                ),
              ],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final navBarFinder = find.byType(NavigationBar);
    expect(navBarFinder, findsOneWidget);
    expect(tester.getSize(navBarFinder).height, 80);
  });

  testWidgets('navigation bar lifts above system bottom inset', (tester) async {
    addTearDown(() {
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.systemGestureInsets = FakeViewPadding.zero;
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: 32);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppNavigationBar(
            height: 60,
            destinations: const [
              AppNavigationDestination(
                label: 'Home',
                icon: Icon(Icons.home_outlined),
              ),
              AppNavigationDestination(
                label: 'Search',
                icon: Icon(Icons.search_outlined),
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final hostFinder = find.byKey(const ValueKey('app-navigation-bar-host'));
    final shellFinder = find.byKey(const ValueKey('app-navigation-bar-shell'));
    expect(hostFinder, findsOneWidget);
    expect(shellFinder, findsOneWidget);
    expect(tester.getSize(shellFinder).height, 92);
    expect(tester.getSize(hostFinder).height, 92);
  });

  testWidgets('navigation bar also lifts above gesture inset', (tester) async {
    addTearDown(() {
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.systemGestureInsets = FakeViewPadding.zero;
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.systemGestureInsets = const FakeViewPadding(bottom: 24);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppNavigationBar(
            height: 60,
            destinations: const [
              AppNavigationDestination(
                label: 'Home',
                icon: Icon(Icons.home_outlined),
              ),
              AppNavigationDestination(
                label: 'Search',
                icon: Icon(Icons.search_outlined),
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final hostFinder = find.byKey(const ValueKey('app-navigation-bar-host'));
    final shellFinder = find.byKey(const ValueKey('app-navigation-bar-shell'));
    expect(hostFinder, findsOneWidget);
    expect(shellFinder, findsOneWidget);
    expect(tester.getSize(shellFinder).height, 84);
    expect(tester.getSize(hostFinder).height, 84);
  });
}
