import '../../../../app/app_router.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/notifications/notification_unread_store.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/logout_prompt.dart';
import 'package:flutter/material.dart';

enum CustomerDockTab {
  home,
  notifications,
  profile,
}

class CustomerDock extends StatelessWidget {
  const CustomerDock({
    super.key,
    required this.activeTab,
    this.onTabSelected,
    this.compact = true,
    this.tightToEdges = true,
  });

  final CustomerDockTab? activeTab;
  final ValueChanged<CustomerDockTab>? onTabSelected;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        NotificationUnreadStore.instance,
        NativeDockBridge.instance,
      ]),
      builder: (context, _) {
        final showBadge = NotificationUnreadStore.instance.hasUnreadForProfile(
              AppSession.instance.profile,
            ) &&
            activeTab != CustomerDockTab.notifications;
        final bool selectionVisible = activeTab != null;
        final int selectedIndex = switch (activeTab) {
          CustomerDockTab.home => 0,
          CustomerDockTab.notifications => 1,
          CustomerDockTab.profile => 2,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == CustomerDockTab.home) return;
            if (onTabSelected != null) {
              onTabSelected!(CustomerDockTab.home);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.customerHome,
                (route) => false,
              );
            }
            return;
          }
          if (index == 1) {
            if (activeTab == CustomerDockTab.notifications) return;
            if (onTabSelected != null) {
              onTabSelected!(CustomerDockTab.notifications);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.customerNotifications,
                (route) => false,
              );
            }
            return;
          }
          if (activeTab == CustomerDockTab.profile) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.profile,
            (route) => false,
          );
        }

        final useNativeDock = NativeDockBridge.isSupportedPlatform &&
            NativeDockBridge.instance.supportsSystemDock;
        if (useNativeDock) {
          NativeDockBridge.instance.register(
            NativeDockState(
              visible: true,
              compact: compact,
              tightToEdges: tightToEdges,
              items: [
                NativeDockItem(
                  id: 'customer-home',
                  label: 'Uy',
                  iconCodePoint: Icons.home_outlined.codePoint,
                  selectedIconCodePoint: Icons.home_filled.codePoint,
                  active: activeTab == CustomerDockTab.home,
                  primary: false,
                  showBadge: false,
                  routeName:
                      onTabSelected == null ? AppRoutes.customerHome : null,
                  replaceStack: onTabSelected == null,
                  onTap: () => handleSelection(0),
                ),
                NativeDockItem(
                  id: 'customer-notifications',
                  label: 'Bildirish',
                  iconCodePoint: Icons.notifications_outlined.codePoint,
                  selectedIconCodePoint: Icons.notifications.codePoint,
                  active: activeTab == CustomerDockTab.notifications,
                  primary: false,
                  showBadge: showBadge,
                  routeName: onTabSelected == null
                      ? AppRoutes.customerNotifications
                      : null,
                  replaceStack: onTabSelected == null,
                  onTap: () => handleSelection(1),
                ),
                NativeDockItem(
                  id: 'customer-profile',
                  label: 'Profil',
                  iconCodePoint: Icons.account_circle_outlined.codePoint,
                  selectedIconCodePoint: Icons.account_circle.codePoint,
                  active: activeTab == CustomerDockTab.profile,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.profile,
                  replaceStack: true,
                  onTap: () => handleSelection(2),
                  onHoldComplete: activeTab == CustomerDockTab.profile
                      ? () => showLogoutPrompt(context)
                      : null,
                ),
              ],
            ),
          );
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tightToEdges ? 0 : 8),
          child: AppNavigationBar(
            height: compact ? 60 : 64,
            selectionVisible: selectionVisible,
            selectedIndex: selectedIndex,
            destinations: [
              const AppNavigationDestination(
                label: 'Uy',
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_filled),
              ),
              AppNavigationDestination(
                label: 'Bildirish',
                icon: const Icon(Icons.notifications_outlined),
                selectedIcon: const Icon(Icons.notifications),
                showBadge: showBadge,
              ),
              AppNavigationDestination(
                label: 'Profil',
                icon: const Icon(Icons.account_circle_outlined),
                selectedIcon: const Icon(Icons.account_circle),
                onLongPress: activeTab == CustomerDockTab.profile
                    ? () => showLogoutPrompt(context)
                    : null,
              ),
            ],
            onDestinationSelected: handleSelection,
          ),
        );
      },
    );
  }
}
