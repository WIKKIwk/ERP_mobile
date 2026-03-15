import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import 'widgets/customer_dock.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class CustomerDeliveryDetailScreen extends StatefulWidget {
  const CustomerDeliveryDetailScreen({
    super.key,
    required this.deliveryNoteID,
  });

  final String deliveryNoteID;

  @override
  State<CustomerDeliveryDetailScreen> createState() =>
      _CustomerDeliveryDetailScreenState();
}

class _CustomerDeliveryDetailScreenState
    extends State<CustomerDeliveryDetailScreen> {
  late Future<CustomerDeliveryDetail> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.customerDeliveryDetail(widget.deliveryNoteID);
  }

  Future<void> _reload() async {
    final future =
        MobileApi.instance.customerDeliveryDetail(widget.deliveryNoteID);
    setState(() => _future = future);
    await future;
  }

  Future<void> _respond(bool approve) async {
    String reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        builder: (context) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              title: const Text('Rad etish'),
              content: TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Sabab (ixtiyoriy)',
                ),
              ),
              actions: [
                SizedBox(
                  width: 110,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Yo‘q'),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Ha'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (confirmed != true) {
        return;
      }
      reason = controller.text.trim();
    } else {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        builder: (context) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              title: const Text('Tasdiqlash'),
              content: const Text('Haqiqatan ham tasdiqlaysizmi?'),
              actions: [
                SizedBox(
                  width: 110,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Yo‘q'),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Ha'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final updated = await MobileApi.instance.customerRespondDelivery(
        deliveryNoteID: widget.deliveryNoteID,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _future = Future<CustomerDeliveryDetail>.value(updated);
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Javob yuborilmadi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Batafsil',
      subtitle: '',
      leading: AppShellIconAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      bottom: const CustomerDock(activeTab: null),
      child: FutureBuilder<CustomerDeliveryDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Card.filled(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${snapshot.error}'),
                ),
              ),
            );
          }
          final detail = snapshot.data!;
          final record = detail.record;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return RefreshIndicator.adaptive(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                Card.filled(
                  margin: EdgeInsets.zero,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CustomerDetailSectionHeader(
                        label: 'Jo‘natma ma’lumoti',
                        topRounded: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailLine(
                                label: 'Customer', value: record.supplierName),
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: 'Mahsulot',
                              value: '${record.itemCode} • ${record.itemName}',
                            ),
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: 'Jo‘natilgan',
                              value:
                                  '${record.sentQty.toStringAsFixed(2)} ${record.uom}',
                            ),
                            if (record.acceptedQty > 0) ...[
                              const SizedBox(height: 12),
                              _DetailLine(
                                label: 'Qabul qilingan',
                                value:
                                    '${record.acceptedQty.toStringAsFixed(2)} ${record.uom}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: 'Status',
                              value: _statusLabel(record.status),
                            ),
                          ],
                        ),
                      ),
                      if (record.note.trim().isNotEmpty) ...[
                        const Divider(height: 1, thickness: 1),
                        const _CustomerDetailSectionHeader(
                          label: 'Izoh',
                          topRounded: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            record.note,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      if (detail.canApprove || detail.canReject) ...[
                        const Divider(height: 1, thickness: 1),
                        const _CustomerDetailSectionHeader(
                          label: 'Javob',
                          topRounded: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              if (detail.canReject)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _respond(false),
                                    child: const Text('Rad etaman'),
                                  ),
                                ),
                              if (detail.canReject && detail.canApprove)
                                const SizedBox(width: 12),
                              if (detail.canApprove)
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _respond(true),
                                    child: Text(
                                      _submitting
                                          ? 'Yuborilmoqda...'
                                          : 'Tasdiqlayman',
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
    );
  }

  String _statusLabel(DispatchStatus status) {
    switch (status) {
      case DispatchStatus.accepted:
        return 'Tasdiqlandi';
      case DispatchStatus.rejected:
        return 'Rad etildi';
      default:
        return 'Kutilmoqda';
    }
  }
}

class _CustomerDetailSectionHeader extends StatelessWidget {
  const _CustomerDetailSectionHeader({
    required this.label,
    required this.topRounded,
  });

  final String label;
  final bool topRounded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: topRounded
            ? const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              )
            : BorderRadius.zero,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
