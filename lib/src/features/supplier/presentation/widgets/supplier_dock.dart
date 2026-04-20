import '../../../../app/app_router.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/notifications/notification_unread_store.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/logout_prompt.dart';
import 'package:flutter/material.dart';

enum SupplierDockTab {
  home,
  notifications,
  recent,
  profile,
}

class SupplierDock extends StatelessWidget {
  const SupplierDock({
    super.key,
    required this.activeTab,
    this.centerActive = false,
    this.compact = true,
    this.tightToEdges = true,
  });

  final SupplierDockTab? activeTab;
  final bool centerActive;
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
            activeTab != SupplierDockTab.notifications;
        final bool selectionVisible = activeTab != null || centerActive;
        final int selectedIndex = switch (activeTab) {
          SupplierDockTab.home => 0,
          SupplierDockTab.notifications => 1,
          SupplierDockTab.recent => 3,
          SupplierDockTab.profile => 4,
          null => centerActive ? 2 : 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == SupplierDockTab.home && !centerActive) {
              return;
            }
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.supplierHome,
              (route) => false,
            );
            return;
          }
          if (index == 1) {
            if (activeTab == SupplierDockTab.notifications) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.supplierNotifications,
              (route) => false,
            );
            return;
          }
          if (index == 2) {
            if (centerActive) return;
            Navigator.of(context).pushNamed(AppRoutes.supplierItemPicker);
            return;
          }
          if (index == 3) {
            if (activeTab == SupplierDockTab.recent) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.supplierRecent,
              (route) => false,
            );
            return;
          }
          if (activeTab == SupplierDockTab.profile) return;
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
                  id: 'supplier-home',
                  label: 'Uy',
                  iconCodePoint: Icons.home_outlined.codePoint,
                  selectedIconCodePoint: Icons.home_rounded.codePoint,
                  active: activeTab == SupplierDockTab.home && !centerActive,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.supplierHome,
                  replaceStack: true,
                  onTap: () => handleSelection(0),
                ),
                NativeDockItem(
                  id: 'supplier-notifications',
                  label: 'Bildirish',
                  iconCodePoint: Icons.notifications_outlined.codePoint,
                  selectedIconCodePoint: Icons.notifications_rounded.codePoint,
                  active: activeTab == SupplierDockTab.notifications,
                  primary: false,
                  showBadge: showBadge,
                  routeName: AppRoutes.supplierNotifications,
                  replaceStack: true,
                  onTap: () => handleSelection(1),
                ),
                NativeDockItem(
                  id: 'supplier-create',
                  label: 'Yangi',
                  iconCodePoint: Icons.add_rounded.codePoint,
                  selectedIconCodePoint: Icons.add_rounded.codePoint,
                  active: centerActive,
                  primary: true,
                  showBadge: false,
                  onTap: () => handleSelection(2),
                ),
                NativeDockItem(
                  id: 'supplier-recent',
                  label: 'Tarix',
                  iconCodePoint: Icons.history_outlined.codePoint,
                  selectedIconCodePoint: Icons.history_rounded.codePoint,
                  active: activeTab == SupplierDockTab.recent,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.supplierRecent,
                  replaceStack: true,
                  onTap: () => handleSelection(3),
                ),
                NativeDockItem(
                  id: 'supplier-profile',
                  label: 'Profil',
                  iconCodePoint: Icons.account_circle_outlined.codePoint,
                  selectedIconCodePoint: Icons.account_circle_rounded.codePoint,
                  active: activeTab == SupplierDockTab.profile,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.profile,
                  replaceStack: true,
                  onTap: () => handleSelection(4),
                  onHoldComplete: activeTab == SupplierDockTab.profile
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
                selectedIcon: Icon(Icons.home_rounded),
              ),
              AppNavigationDestination(
                label: 'Bildirish',
                icon: const Icon(Icons.notifications_outlined),
                selectedIcon: const Icon(Icons.notifications_rounded),
                showBadge: showBadge,
              ),
              const AppNavigationDestination(
                label: 'Yangi',
                icon: Icon(Icons.add_rounded),
                selectedIcon: Icon(Icons.add_rounded),
                isPrimary: true,
              ),
              const AppNavigationDestination(
                label: 'Tarix',
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
              ),
              AppNavigationDestination(
                label: 'Profil',
                icon: const Icon(Icons.account_circle_outlined),
                selectedIcon: const Icon(Icons.account_circle_rounded),
                onLongPress: activeTab == SupplierDockTab.profile
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
