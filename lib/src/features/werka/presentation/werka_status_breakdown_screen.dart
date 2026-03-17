import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import '../state/werka_store.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaStatusBreakdownScreen extends StatefulWidget {
  const WerkaStatusBreakdownScreen({
    super.key,
    required this.kind,
  });

  final WerkaStatusKind kind;

  @override
  State<WerkaStatusBreakdownScreen> createState() =>
      _WerkaStatusBreakdownScreenState();
}

class _WerkaStatusBreakdownScreenState
    extends State<WerkaStatusBreakdownScreen> {
  @override
  void initState() {
    super.initState();
    WerkaStore.instance.bootstrapBreakdown(widget.kind);
  }

  Future<void> _reload() async {
    await WerkaStore.instance.refreshBreakdown(widget.kind);
  }

  String get _title {
    switch (widget.kind) {
      case WerkaStatusKind.pending:
        return 'Jarayonda';
      case WerkaStatusKind.confirmed:
        return 'Tasdiqlangan';
      case WerkaStatusKind.returned:
        return 'Qaytarilgan';
    }
  }

  String _metricLabel(WerkaStatusBreakdownEntry entry) {
    switch (widget.kind) {
      case WerkaStatusKind.pending:
        return '${entry.totalSentQty.toStringAsFixed(0)} ${entry.uom} jarayonda';
      case WerkaStatusKind.confirmed:
        return '${entry.totalAcceptedQty.toStringAsFixed(0)} ${entry.uom} tasdiqlangan';
      case WerkaStatusKind.returned:
        return '${entry.totalReturnedQty.toStringAsFixed(0)} ${entry.uom} qaytarilgan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      backgroundColor: AppTheme.shellStart(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _title,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                child: AnimatedBuilder(
                  animation: WerkaStore.instance,
                  builder: (context, _) {
                    final store = WerkaStore.instance;
                    if (store.loadingBreakdown(widget.kind) &&
                        store.breakdownItems(widget.kind).isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final error = store.breakdownError(widget.kind);
                    if (error != null &&
                        store.breakdownItems(widget.kind).isEmpty) {
                      return Center(
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status ro‘yxati yuklanmadi: $error'),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _reload,
                                  child: const Text('Qayta urinish'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final items = store.breakdownItems(widget.kind);
                    if (items.isEmpty) {
                      return Center(
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'Bu statusda hozircha yozuv yo‘q.',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator.adaptive(
                      onRefresh: _reload,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          Card.filled(
                            margin: EdgeInsets.zero,
                            color: scheme.surfaceContainerLow,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              children: [
                                for (int index = 0;
                                    index < items.length;
                                    index++) ...[
                                  _WerkaBreakdownRow(
                                    entry: items[index],
                                    metricLabel: _metricLabel(items[index]),
                                    isFirst: index == 0,
                                    isLast: index == items.length - 1,
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                      AppRoutes.werkaStatusDetail,
                                      arguments: WerkaStatusDetailArgs(
                                        kind: widget.kind,
                                        supplierRef: items[index].supplierRef,
                                        supplierName: items[index].supplierName,
                                      ),
                                    ),
                                  ),
                                  if (index != items.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: 18,
                                      endIndent: 18,
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withValues(alpha: 0.55),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: WerkaDock(activeTab: null),
        ),
      ),
    );
  }
}

class WerkaStatusDetailArgs {
  const WerkaStatusDetailArgs({
    required this.kind,
    required this.supplierRef,
    required this.supplierName,
  });

  final WerkaStatusKind kind;
  final String supplierRef;
  final String supplierName;
}

class _WerkaBreakdownRow extends StatelessWidget {
  const _WerkaBreakdownRow({
    required this.entry,
    required this.metricLabel,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final WerkaStatusBreakdownEntry entry;
  final String metricLabel;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 28 : 0),
      topRight: Radius.circular(isFirst ? 28 : 0),
      bottomLeft: Radius.circular(isLast ? 28 : 0),
      bottomRight: Radius.circular(isLast ? 28 : 0),
    );
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.supplierName,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                metricLabel,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.receiptCount} ta receipt',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
