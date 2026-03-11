import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaNotificationsScreen extends StatefulWidget {
  const WerkaNotificationsScreen({super.key});

  @override
  State<WerkaNotificationsScreen> createState() =>
      _WerkaNotificationsScreenState();
}

class _WerkaNotificationsScreenState extends State<WerkaNotificationsScreen>
    with WidgetsBindingObserver {
  late Future<List<DispatchRecord>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _itemsFuture = MobileApi.instance.werkaHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final future = MobileApi.instance.werkaHistory();
    setState(() {
      _itemsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Bildirishnomalar',
      subtitle: '',
      bottom: const WerkaDock(activeTab: WerkaDockTab.notifications),
      child: FutureBuilder<List<DispatchRecord>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return RefreshIndicator.adaptive(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bildirishnomalar yuklanmadi',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _reload,
                            child: const Text('Qayta urinish'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? <DispatchRecord>[];
          if (items.isEmpty) {
            return const Center(
              child: SoftCard(
                child: Text('Hali bildirishnomalar yo‘q.'),
              ),
            );
          }

          return RefreshIndicator.adaptive(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.notificationDetail,
                    arguments: record.id,
                  ),
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _notificationTitle(record),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            _NotificationStatusBadge(status: record.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${record.itemCode} • ${record.itemName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Jo‘natildi: ${record.sentQty.toStringAsFixed(0)} ${record.uom}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (record.acceptedQty > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Qabul qilindi: ${record.acceptedQty.toStringAsFixed(0)} ${record.uom}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (record.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            record.note,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          record.createdLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _notificationTitle(DispatchRecord record) {
  switch (record.status) {
    case DispatchStatus.pending:
      return record.supplierName;
    case DispatchStatus.accepted:
    case DispatchStatus.partial:
    case DispatchStatus.rejected:
    case DispatchStatus.cancelled:
    case DispatchStatus.draft:
      return record.itemCode;
  }
}

class _NotificationStatusBadge extends StatelessWidget {
  const _NotificationStatusBadge({
    required this.status,
  });

  final DispatchStatus status;

  IconData get icon {
    switch (status) {
      case DispatchStatus.draft:
        return Icons.schedule_rounded;
      case DispatchStatus.pending:
        return Icons.schedule_outlined;
      case DispatchStatus.accepted:
        return Icons.done_all_rounded;
      case DispatchStatus.partial:
        return Icons.check_rounded;
      case DispatchStatus.rejected:
        return Icons.close_rounded;
      case DispatchStatus.cancelled:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
