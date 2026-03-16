import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import 'werka_status_breakdown_screen.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaStatusDetailScreen extends StatefulWidget {
  const WerkaStatusDetailScreen({
    super.key,
    required this.args,
  });

  final WerkaStatusDetailArgs args;

  @override
  State<WerkaStatusDetailScreen> createState() =>
      _WerkaStatusDetailScreenState();
}

class _WerkaStatusDetailScreenState extends State<WerkaStatusDetailScreen> {
  late Future<List<DispatchRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.werkaStatusDetails(
      kind: widget.args.kind,
      supplierRef: widget.args.supplierRef,
    );
  }

  Future<void> _reload() async {
    final future = MobileApi.instance.werkaStatusDetails(
      kind: widget.args.kind,
      supplierRef: widget.args.supplierRef,
    );
    setState(() {
      _future = future;
    });
    await future;
  }

  String get _title {
    switch (widget.args.kind) {
      case WerkaStatusKind.pending:
        return 'Jarayonda • ${widget.args.supplierName}';
      case WerkaStatusKind.confirmed:
        return 'Tasdiqlangan • ${widget.args.supplierName}';
      case WerkaStatusKind.returned:
        return 'Qaytarilgan • ${widget.args.supplierName}';
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
                child: FutureBuilder<List<DispatchRecord>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
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
                                Text(
                                    'Receiptlar yuklanmadi: ${snapshot.error}'),
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

                    final items = snapshot.data ?? const <DispatchRecord>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Card.filled(
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'Bu supplierda hozircha receipt yo‘q.',
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              children: [
                                for (int index = 0;
                                    index < items.length;
                                    index++) ...[
                                  _WerkaStatusRecordRow(
                                    record: items[index],
                                    onTap: () {
                                      if (widget.args.kind ==
                                          WerkaStatusKind.pending) {
                                        Navigator.of(context).pushNamed(
                                          AppRoutes.werkaDetail,
                                          arguments: items[index],
                                        );
                                        return;
                                      }
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.notificationDetail,
                                        arguments: items[index].id,
                                      );
                                    },
                                  ),
                                  if (index != items.length - 1)
                                    const Divider(height: 1, thickness: 1),
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
          padding: EdgeInsets.fromLTRB(20, 0, 24, 0),
          child: WerkaDock(activeTab: null),
        ),
      ),
    );
  }
}

class _WerkaStatusRecordRow extends StatelessWidget {
  const _WerkaStatusRecordRow({
    required this.record,
    required this.onTap,
  });

  final DispatchRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.itemCode,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${record.itemCode} • ${record.itemName}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${record.sentQty.toStringAsFixed(0)} ${record.uom}',
              style: theme.textTheme.headlineMedium,
            ),
            if (record.acceptedQty > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Qabul: ${record.acceptedQty.toStringAsFixed(0)} ${record.uom}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (record.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.note,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              record.createdLabel,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
