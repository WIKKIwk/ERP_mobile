import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class WerkaHomeScreen extends StatelessWidget {
  const WerkaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Werka',
      subtitle: 'Pending qabul qilish ro‘yxati.',
      actions: [
        AppShellIconAction(
          icon: Icons.person_outline_rounded,
          onTap: () => Navigator.of(context).pushNamed('/profile'),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DispatchRecord>>(
              future: MobileApi.instance.werkaPending(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: SoftCard(
                      child: Text('Pending list yuklanmadi: ${snapshot.error}'),
                    ),
                  );
                }

                final items = snapshot.data ?? <DispatchRecord>[];

                return Column(
                  children: [
                    SmoothAppear(
                      child: SoftCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${items.length} ta pending bildirishnoma',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const Icon(Icons.inventory_2_outlined),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final DispatchRecord record = items[index];
                          return SmoothAppear(
                            delay: Duration(milliseconds: 70 + (index * 80)),
                            offset: const Offset(0, 18),
                            child: PressableScale(
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.werkaDetail,
                                arguments: record,
                              ),
                              child: SoftCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(record.supplierName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge),
                                        ),
                                        const StatusPill(
                                            status: DispatchStatus.pending),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                        '${record.itemCode} • ${record.itemName}'),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${record.sentQty.toStringAsFixed(0)} ${record.uom}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(record.createdLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
