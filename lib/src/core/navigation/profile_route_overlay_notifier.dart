import '../../app/app_router.dart';
import 'package:flutter/material.dart';

class ProfileRouteOverlayNotifier extends ChangeNotifier {
  ProfileRouteOverlayNotifier._();
  static final ProfileRouteOverlayNotifier instance =
      ProfileRouteOverlayNotifier._();

  bool _profileRouteOnStack = false;

  bool get obscuresDockPrimaryFab => _profileRouteOnStack;

  void syncProfileOnStack(bool value) {
    if (_profileRouteOnStack == value) {
      return;
    }
    _profileRouteOnStack = value;
    notifyListeners();
  }
}

class ProfileRouteOverlayObserver extends NavigatorObserver {
  ProfileRouteOverlayObserver._();
  static final ProfileRouteOverlayObserver instance =
      ProfileRouteOverlayObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == AppRoutes.profile) {
      ProfileRouteOverlayNotifier.instance.syncProfileOnStack(true);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == AppRoutes.profile) {
      ProfileRouteOverlayNotifier.instance.syncProfileOnStack(false);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == AppRoutes.profile) {
      ProfileRouteOverlayNotifier.instance.syncProfileOnStack(false);
    }
  }
}
