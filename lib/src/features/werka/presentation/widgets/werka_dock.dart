import '../../../../app/app_router.dart';
import '../../../../core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

enum WerkaDockTab {
  home,
  notifications,
  profile,
}

class WerkaDock extends StatelessWidget {
  const WerkaDock({
    super.key,
    required this.activeTab,
  });

  final WerkaDockTab activeTab;

  @override
  Widget build(BuildContext context) {
    return ActionDock(
      leading: [
        DockButton(
          icon: Icons.home_rounded,
          active: activeTab == WerkaDockTab.home,
          onTap: () {
            if (activeTab == WerkaDockTab.home) {
              return;
            }
            Navigator.of(context).pushReplacementNamed(AppRoutes.werkaHome);
          },
        ),
        DockButton(
          icon: Icons.notifications_none_rounded,
          active: activeTab == WerkaDockTab.notifications,
          onTap: () {
            if (activeTab == WerkaDockTab.notifications) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Werka bildirishnomalari keyingi bosqichda')),
            );
          },
        ),
      ],
      center: DockButton(
        icon: Icons.inventory_2_outlined,
        primary: true,
        onTap: () {
          if (activeTab == WerkaDockTab.home) {
            return;
          }
          Navigator.of(context).pushReplacementNamed(AppRoutes.werkaHome);
        },
      ),
      trailing: [
        DockButton(
          icon: Icons.history_rounded,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Werka recent keyingi bosqichda')),
            );
          },
        ),
        DockButton(
          icon: Icons.person_outline_rounded,
          active: activeTab == WerkaDockTab.profile,
          onTap: () {
            if (activeTab == WerkaDockTab.profile) {
              return;
            }
            Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
          },
        ),
      ],
    );
  }
}
