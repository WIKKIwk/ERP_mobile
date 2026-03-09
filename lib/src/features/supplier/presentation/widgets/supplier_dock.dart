import '../../../../app/app_router.dart';
import '../../../../core/widgets/common_widgets.dart';
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
  });

  final SupplierDockTab activeTab;

  @override
  Widget build(BuildContext context) {
    return ActionDock(
      leading: [
        DockButton(
          icon: Icons.home_rounded,
          active: activeTab == SupplierDockTab.home,
          onTap: () {
            if (activeTab == SupplierDockTab.home) {
              return;
            }
            Navigator.of(context).pushReplacementNamed(AppRoutes.supplierHome);
          },
        ),
        DockButton(
          icon: Icons.notifications_none_rounded,
          active: activeTab == SupplierDockTab.notifications,
          onTap: () {
            if (activeTab == SupplierDockTab.notifications) {
              return;
            }
            Navigator.of(context)
                .pushReplacementNamed(AppRoutes.supplierNotifications);
          },
        ),
      ],
      center: DockButton(
        icon: Icons.add_rounded,
        primary: true,
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.supplierItemPicker),
      ),
      trailing: [
        DockButton(
          icon: Icons.history_rounded,
          active: activeTab == SupplierDockTab.recent,
          onTap: () {
            if (activeTab == SupplierDockTab.recent) {
              return;
            }
            Navigator.of(context)
                .pushReplacementNamed(AppRoutes.supplierRecent);
          },
        ),
        DockButton(
          icon: Icons.person_outline_rounded,
          active: activeTab == SupplierDockTab.profile,
          onTap: () {
            if (activeTab == SupplierDockTab.profile) {
              return;
            }
            Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
          },
        ),
      ],
    );
  }
}
