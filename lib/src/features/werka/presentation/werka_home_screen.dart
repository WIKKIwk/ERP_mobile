import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/notifications/refresh_hub.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_retry_state.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/m3_segmented_list.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/top_refresh_scroll_physics.dart';
import '../../shared/models/app_models.dart';
import '../state/werka_store.dart';
import 'widgets/werka_dock.dart';
import 'widgets/werka_create_hub_sheet.dart';
import 'package:flutter/material.dart';

class WerkaHomeScreen extends StatefulWidget {
  const WerkaHomeScreen({super.key});

  @override
  State<WerkaHomeScreen> createState() => _WerkaHomeScreenState();
}

class _WerkaHomeScreenState extends State<WerkaHomeScreen>
    with WidgetsBindingObserver {
  int _refreshVersion = 0;
  final ValueNotifier<double> _bottomDockFadeStrength = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WerkaStore.instance.bootstrapHome();
    RefreshHub.instance.addListener(_handlePushRefresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RefreshHub.instance.removeListener(_handlePushRefresh);
    _bottomDockFadeStrength.dispose();
    super.dispose();
  }

  bool _onDockScrollRelated(Notification notification) {
    ScrollMetrics? metrics;
    if (notification is ScrollMetricsNotification) {
      metrics = notification.metrics;
    } else if (notification is ScrollNotification) {
      metrics = notification.metrics;
    }
    if (metrics == null) {
      return false;
    }
    final next = dockFadeStrengthFromScrollMetrics(metrics);
    if ((next - _bottomDockFadeStrength.value).abs() > 0.008) {
      _bottomDockFadeStrength.value = next;
    }
    return false;
  }

  void _handlePushRefresh() {
    if (!mounted || RefreshHub.instance.topic != 'werka') {
      return;
    }
    if (_refreshVersion == RefreshHub.instance.version) {
      return;
    }
    _refreshVersion = RefreshHub.instance.version;
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  Future<void> _reload() async {
    await WerkaStore.instance.refreshHome();
  }

  void _openDrawerRoute(String route) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      title: context.l10n.werkaRoleName,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: _WerkaHomeDrawer(onNavigate: _openDrawerRoute),
      bottom: const WerkaDock(activeTab: WerkaDockTab.home),
      bottomDockFadeStrength: _bottomDockFadeStrength,
      contentPadding: EdgeInsets.zero,
      child: NotificationListener<Notification>(
        onNotification: _onDockScrollRelated,
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: WerkaStore.instance,
                builder: (context, _) {
                  final store = WerkaStore.instance;
                  if (store.loadingHome && !store.loadedHome) {
                    return const Center(child: AppLoadingIndicator());
                  }
                  if (store.homeError != null && !store.loadedHome) {
                    return AppRefreshIndicator(
                      onRefresh: _reload,
                      allowRefreshOnShortContent: true,
                      child: ListView(
                        physics: const TopRefreshScrollPhysics(),
                        children: [
                          AppRetryState(onRetry: _reload),
                        ],
                      ),
                    );
                  }
                  final currentSummary = store.summary;
                  final pendingItems = store.pendingItems;

                  return AppRefreshIndicator(
                    onRefresh: _reload,
                    allowRefreshOnShortContent: true,
                    child: ListView(
                      physics: const TopRefreshScrollPhysics(),
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      children: [
                        const SizedBox(height: 4),
                        _WerkaSummaryList(summary: currentSummary),
                        if (pendingItems.isNotEmpty) const SizedBox(height: 16),
                        if (pendingItems.isNotEmpty)
                          _WerkaPendingSection(items: pendingItems),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WerkaHomeDrawer extends StatelessWidget {
  const _WerkaHomeDrawer({
    required this.onNavigate,
  });

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    const selectedIndex = 0;
    return SizedBox(
      width: 272,
      child: NavigationDrawer(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        selectedIndex: selectedIndex,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
            return;
          }
          if (index == 1) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.werkaNotifications);
            return;
          }
          if (index == 2) {
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              showWerkaCreateHubSheet(context);
            });
            return;
          }
          if (index == 3) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.werkaArchive);
            return;
          }
          if (index == 4) {
            Navigator.of(context).pop();
            onNavigate(AppRoutes.profile);
          }
        },
        header: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bo‘limlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
              ),
          ),
        ),
        children: [
          const NavigationDrawerDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Uy'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: Text('Bildirish'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.add_rounded),
            selectedIcon: Icon(Icons.add_rounded),
            label: Text('Yangi'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.archive_outlined),
            selectedIcon: const Icon(Icons.archive_rounded),
            label: Text(context.l10n.archiveTitle),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: Text(context.l10n.profileTitle),
          ),
        ],
      ),
    );
  }
}

class _WerkaSummaryList extends StatelessWidget {
  const _WerkaSummaryList({
    required this.summary,
  });

  final WerkaHomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return SmoothAppear(
      child: M3SegmentSpacedColumn(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _WerkaSummarySegmentCard(
            slot: M3SegmentVerticalSlot.top,
            cornerRadius: M3SegmentedListGeometry.cornerLarge,
            label: context.l10n.pendingStatus,
            value: summary.pendingCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.werkaStatusBreakdown,
              arguments: WerkaStatusKind.pending,
            ),
          ),
          _WerkaSummarySegmentCard(
            slot: M3SegmentVerticalSlot.middle,
            cornerRadius: M3SegmentedListGeometry.cornerMiddle,
            label: context.l10n.confirmedStatus,
            value: summary.confirmedCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.werkaStatusBreakdown,
              arguments: WerkaStatusKind.confirmed,
            ),
          ),
          _WerkaSummarySegmentCard(
            slot: M3SegmentVerticalSlot.bottom,
            cornerRadius: M3SegmentedListGeometry.cornerLarge,
            label: context.l10n.returnedStatus,
            value: summary.returnedCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.werkaStatusBreakdown,
              arguments: WerkaStatusKind.returned,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bitta **to‘ldirilgan** list elementi — segmentlar bir-biriga ulanmaydi (faqat gap).
class _WerkaSummarySegmentCard extends StatelessWidget {
  const _WerkaSummarySegmentCard({
    required this.slot,
    required this.cornerRadius,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final double cornerRadius;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final BorderRadius radius =
        M3SegmentedListGeometry.borderRadius(slot, cornerRadius);
    final Color bg = switch (theme.brightness) {
      Brightness.dark => scheme.surfaceContainerLow,
      Brightness.light => scheme.surfaceContainerHighest,
    };
    final Color foreground = scheme.onSurface;
    final Color accent = scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WerkaPendingSection extends StatefulWidget {
  const _WerkaPendingSection({
    required this.items,
  });

  final List<DispatchRecord> items;

  @override
  State<_WerkaPendingSection> createState() => _WerkaPendingSectionState();
}

class _WerkaPendingSectionState extends State<_WerkaPendingSection> {
  /// Yopiq holatda pastdagi kartalar **build** qilinmaydi.
  late bool _itemsExpanded;

  @override
  void initState() {
    super.initState();
    _itemsExpanded = WerkaStore.instance.homePendingListExpanded;
  }

  void _toggleExpanded() {
    setState(() => _itemsExpanded = !_itemsExpanded);
    WerkaStore.instance.setHomePendingListExpanded(_itemsExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = widget.items.length;

    return SmoothAppear(
      delay: const Duration(milliseconds: 90),
      offset: const Offset(0, 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            M3SegmentFilledSurface(
              slot: M3SegmentVerticalSlot.top,
              cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(
                M3SegmentVerticalSlot.top,
              ),
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.inProgressItemsTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Icon(
                      _itemsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 28,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.smooth,
              alignment: Alignment.topCenter,
              child: _itemsExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: M3SegmentedListGeometry.gap),
                        for (int index = 0; index < n; index++) ...[
                          if (index > 0)
                            const SizedBox(
                              height: M3SegmentedListGeometry.gap,
                            ),
                          _WerkaPendingItemTile(
                            record: widget.items[index],
                            index: index,
                            itemCount: n,
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WerkaPendingItemTile extends StatelessWidget {
  const _WerkaPendingItemTile({
    required this.record,
    required this.index,
    required this.itemCount,
  });

  final DispatchRecord record;
  final int index;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slot =
        M3SegmentedListGeometry.bodySlotForIndex(index, itemCount);
    final r = M3SegmentedListGeometry.cornerRadiusForSlot(slot);

    void navigate() => Navigator.of(context).pushNamed(
          record.isDeliveryNote
              ? AppRoutes.werkaCustomerDeliveryDetail
              : AppRoutes.werkaDetail,
          arguments: record,
        );

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: r,
      onTap: navigate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.sentQty.toStringAsFixed(0)} ${record.uom}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.createdLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
