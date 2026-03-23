import '../../../../core/theme/app_motion.dart';
import '../../../shared/presentation/profile_screen.dart';
import '../customer_home_screen.dart';
import '../customer_notifications_screen.dart';
import 'customer_dock.dart';
import 'package:flutter/material.dart';

enum CustomerTabTransitionDirection {
  forward,
  backward,
}

int _customerTabIndex(CustomerDockTab tab) {
  switch (tab) {
    case CustomerDockTab.home:
      return 0;
    case CustomerDockTab.notifications:
      return 1;
    case CustomerDockTab.profile:
      return 2;
  }
}

Widget _customerTabScreen(CustomerDockTab tab) {
  switch (tab) {
    case CustomerDockTab.home:
      return const CustomerHomeScreen();
    case CustomerDockTab.notifications:
      return const CustomerNotificationsScreen();
    case CustomerDockTab.profile:
      return const ProfileScreen();
  }
}

void navigateToCustomerTab(
  BuildContext context, {
  required CustomerDockTab from,
  required CustomerDockTab to,
}) {
  if (from == to) {
    return;
  }

  final direction = _customerTabIndex(to) > _customerTabIndex(from)
      ? CustomerTabTransitionDirection.forward
      : CustomerTabTransitionDirection.backward;

  Navigator.of(context).pushReplacement(
    _CustomerTabRoute(
      child: _customerTabScreen(to),
      direction: direction,
    ),
  );
}

void handleCustomerTabSwipe(
  BuildContext context, {
  required CustomerDockTab activeTab,
  required DragEndDetails details,
}) {
  final velocity = details.primaryVelocity ?? 0;
  if (velocity.abs() < 240) {
    return;
  }

  if (velocity < 0) {
    switch (activeTab) {
      case CustomerDockTab.home:
        navigateToCustomerTab(
          context,
          from: activeTab,
          to: CustomerDockTab.notifications,
        );
      case CustomerDockTab.notifications:
        navigateToCustomerTab(
          context,
          from: activeTab,
          to: CustomerDockTab.profile,
        );
      case CustomerDockTab.profile:
        return;
    }
    return;
  }

  switch (activeTab) {
    case CustomerDockTab.home:
      return;
    case CustomerDockTab.notifications:
      navigateToCustomerTab(
        context,
        from: activeTab,
        to: CustomerDockTab.home,
      );
    case CustomerDockTab.profile:
      navigateToCustomerTab(
        context,
        from: activeTab,
        to: CustomerDockTab.notifications,
      );
  }
}

class _CustomerTabRoute extends PageRouteBuilder<void> {
  _CustomerTabRoute({
    required this.child,
    required this.direction,
  }) : super(
          transitionDuration: AppMotion.pageEnter,
          reverseTransitionDuration: AppMotion.pageExit,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: AppMotion.pageIn,
              reverseCurve: AppMotion.pageOut,
            );
            final slide = Tween<Offset>(
              begin: direction == CustomerTabTransitionDirection.forward
                  ? const Offset(0.12, 0)
                  : const Offset(-0.12, 0),
              end: Offset.zero,
            ).animate(curve);
            final fade = Tween<double>(begin: 0.72, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: AppMotion.emphasizedDecelerate,
              ),
            );
            final outgoing = Tween<Offset>(
              begin: Offset.zero,
              end: direction == CustomerTabTransitionDirection.forward
                  ? const Offset(-0.06, 0)
                  : const Offset(0.06, 0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: AppMotion.pageOut,
              ),
            );

            return SlideTransition(
              position: outgoing,
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: slide,
                  child: child,
                ),
              ),
            );
          },
        );

  final Widget child;
  final CustomerTabTransitionDirection direction;
}
