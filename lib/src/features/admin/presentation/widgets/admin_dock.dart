import '../../../../app/app_router.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/logout_prompt.dart';
import 'package:flutter/material.dart';

enum AdminDockTab {
  home,
  suppliers,
  settings,
  activity,
  profile,
}

class AdminDock extends StatelessWidget {
  const AdminDock({
    super.key,
    required this.activeTab,
    this.compact = true,
    this.tightToEdges = true,
  });

  final AdminDockTab activeTab;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NativeDockBridge.instance,
      builder: (context, _) {
        final int selectedIndex = switch (activeTab) {
          AdminDockTab.home => 0,
          AdminDockTab.suppliers => 1,
          AdminDockTab.settings => 2,
          AdminDockTab.activity => 3,
          AdminDockTab.profile => 4,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == AdminDockTab.home) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.adminHome,
              (route) => false,
            );
            return;
          }
          if (index == 1) {
            if (activeTab == AdminDockTab.suppliers) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.adminSuppliers,
              (route) => false,
            );
            return;
          }
          if (index == 2) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.adminCreateHub,
              (route) => false,
            );
            return;
          }
          if (index == 3) {
            if (activeTab == AdminDockTab.activity) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.adminActivity,
              (route) => false,
            );
            return;
          }
          if (activeTab == AdminDockTab.profile) return;
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
                  id: 'admin-home',
                  label: 'Uy',
                  iconCodePoint: Icons.home_outlined.codePoint,
                  selectedIconCodePoint: Icons.home_rounded.codePoint,
                  active: activeTab == AdminDockTab.home,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.adminHome,
                  replaceStack: true,
                  onTap: () => handleSelection(0),
                ),
                NativeDockItem(
                  id: 'admin-suppliers',
                  label: 'Yetkazuvchilar',
                  iconCodePoint: Icons.groups_outlined.codePoint,
                  selectedIconCodePoint: Icons.groups_rounded.codePoint,
                  active: activeTab == AdminDockTab.suppliers,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.adminSuppliers,
                  replaceStack: true,
                  onTap: () => handleSelection(1),
                ),
                NativeDockItem(
                  id: 'admin-create',
                  label: 'Yangi',
                  iconCodePoint: Icons.add_rounded.codePoint,
                  selectedIconCodePoint: Icons.add_rounded.codePoint,
                  active: activeTab == AdminDockTab.settings,
                  primary: true,
                  showBadge: false,
                  routeName: AppRoutes.adminCreateHub,
                  replaceStack: true,
                  onTap: () => handleSelection(2),
                ),
                NativeDockItem(
                  id: 'admin-activity',
                  label: 'Faoliyat',
                  iconCodePoint: Icons.history_outlined.codePoint,
                  selectedIconCodePoint: Icons.history_rounded.codePoint,
                  active: activeTab == AdminDockTab.activity,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.adminActivity,
                  replaceStack: true,
                  onTap: () => handleSelection(3),
                ),
                NativeDockItem(
                  id: 'admin-profile',
                  label: 'Profil',
                  iconCodePoint: Icons.account_circle_outlined.codePoint,
                  selectedIconCodePoint: Icons.account_circle_rounded.codePoint,
                  active: activeTab == AdminDockTab.profile,
                  primary: false,
                  showBadge: false,
                  routeName: AppRoutes.profile,
                  replaceStack: true,
                  onTap: () => handleSelection(4),
                  onHoldComplete: activeTab == AdminDockTab.profile
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
            selectedIndex: selectedIndex,
            destinations: [
              const AppNavigationDestination(
                label: 'Uy',
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
              ),
              const AppNavigationDestination(
                label: 'Yetkazuvchilar',
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
              ),
              const AppNavigationDestination(
                label: 'Yangi',
                icon: Icon(Icons.add_rounded),
                selectedIcon: Icon(Icons.add_rounded),
                isPrimary: true,
              ),
              const AppNavigationDestination(
                label: 'Faoliyat',
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
              ),
              AppNavigationDestination(
                label: 'Profil',
                icon: const Icon(Icons.account_circle_outlined),
                selectedIcon: const Icon(Icons.account_circle_rounded),
                onLongPress: activeTab == AdminDockTab.profile
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
