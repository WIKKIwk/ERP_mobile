import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/customer/customer_priority.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/search/search_activity_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'werka_archive_batch_qr.dart';
import 'werka_success_screen.dart';
import 'widgets/m3_picker_sheet.dart';

CustomerItemOption? resolveExactArchiveBatchItemOption(
  String itemName,
  List<CustomerItemOption> options,
) {
  final normalizedItem = _normalizeArchiveBatchItem(itemName);
  if (normalizedItem.isEmpty) {
    return null;
  }
  for (final option in options) {
    if (_normalizeArchiveBatchItem(option.itemName) == normalizedItem ||
        _normalizeArchiveBatchItem(option.itemCode) == normalizedItem) {
      return option;
    }
  }
  return null;
}

String _normalizeArchiveBatchItem(String value) {
  return value.trim().toLowerCase();
}

CustomerDirectoryEntry archiveBatchCustomerFromOption(
  CustomerItemOption option,
) {
  return CustomerDirectoryEntry(
    ref: option.customerRef,
    name: option.customerName,
    phone: option.customerPhone,
  );
}

CustomerDirectoryEntry resolveArchiveBatchDefaultCustomer(
  CustomerItemOption option,
  List<CustomerDirectoryEntry> customers,
) {
  return preferPrimaryCustomer<CustomerDirectoryEntry>(
        customers.where((item) => item.ref.trim().isNotEmpty),
        customerName: (item) => item.name,
      ) ??
      archiveBatchCustomerFromOption(option);
}

class WerkaArchiveBatchQrLookupArgs {
  const WerkaArchiveBatchQrLookupArgs({
    required this.payload,
  });

  final WerkaArchiveBatchQrPayload payload;
}

class WerkaArchiveBatchQrLookupScreen extends StatefulWidget {
  const WerkaArchiveBatchQrLookupScreen({
    super.key,
    required this.args,
  });

  final WerkaArchiveBatchQrLookupArgs args;

  @override
  State<WerkaArchiveBatchQrLookupScreen> createState() =>
      _WerkaArchiveBatchQrLookupScreenState();
}

class _WerkaArchiveBatchQrLookupScreenState
    extends State<WerkaArchiveBatchQrLookupScreen> {
  late Future<_ArchiveBatchQrResolution> _future;
  CustomerDirectoryEntry? _selectedCustomer;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _resolveItem();
  }

  Future<_ArchiveBatchQrResolution> _resolveItem() async {
    final payload = widget.args.payload;
    final options = await MobileApi.instance.werkaCustomerItemOptions(
      query: payload.itemName,
      limit: 200,
    );
    final option = resolveExactArchiveBatchItemOption(
      payload.itemName,
      options,
    );
    if (option == null) {
      throw StateError('batch_item_not_found');
    }
    var customers = <CustomerDirectoryEntry>[];
    try {
      customers = await MobileApi.instance.werkaCustomersForItem(
        itemCode: option.itemCode,
        itemName: option.itemName,
        limit: 200,
        offset: 0,
      );
    } catch (_) {
      customers = const <CustomerDirectoryEntry>[];
    }
    return _ArchiveBatchQrResolution(
      option: option,
      defaultCustomer: resolveArchiveBatchDefaultCustomer(option, customers),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _pickCustomer(_ArchiveBatchQrResolution resolved) async {
    if (_submitting) {
      return;
    }

    final option = resolved.option;
    final picked = await showModalBottomSheet<CustomerDirectoryEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerDirectoryEntry>(
          title: context.l10n.selectCustomer,
          supportingText: option.itemName,
          hintText: context.l10n.searchCustomer,
          loadPage: (query, offset, limit) =>
              MobileApi.instance.werkaCustomersForItem(
            itemCode: option.itemCode,
            itemName: option.itemName,
            query: query,
            offset: offset,
            limit: limit,
          ),
          itemTitle: (item) => item.name,
          itemSubtitle: (item) => item.phone,
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedCustomer = picked);
  }

  Future<void> _send(_ArchiveBatchQrResolution resolved) async {
    final option = resolved.option;
    final customer = _selectedCustomer ?? resolved.defaultCustomer;
    final payload = widget.args.payload;
    final l10n = context.l10n;
    if (customer.ref.trim().isEmpty || option.itemCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer yoki mahsulot topilmadi.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await MobileApi.instance.createWerkaCustomerIssue(
        customerRef: customer.ref,
        itemCode: option.itemCode,
        qty: payload.qty,
      );
      await SearchActivityStore.instance.recordItemSelection(created.itemCode);
      if (!mounted) {
        return;
      }

      final record = DispatchRecord(
        id: created.entryID,
        supplierRef: created.customerRef,
        supplierName: created.customerName,
        itemCode: created.itemCode,
        itemName: created.itemName,
        uom: created.uom,
        sentQty: created.qty,
        acceptedQty: 0,
        amount: 0,
        currency: '',
        note: '',
        eventType: 'customer_issue_pending',
        highlight: '',
        status: DispatchStatus.pending,
        createdLabel: created.createdLabel,
      );
      WerkaRuntimeStore.instance.recordCreatedPending(record);
      RefreshHub.instance.emit('werka');
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.werkaSuccess,
        (route) => route.isFirst,
        arguments: WerkaSuccessArgs(
          record: record,
          returnRouteName: AppRoutes.werkaStockEntryQrScan,
          returnLabel: 'QR scan ga qaytish',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is MobileApiException && error.code == 'insufficient_stock'
              ? l10n.insufficientStockMessage
              : l10n.customerIssueFailed(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final payload = widget.args.payload;

    return AppShell(
      title: 'Batch QR',
      subtitle: payload.sessionID,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      backgroundColor: scheme.surface,
      child: FutureBuilder<_ArchiveBatchQrResolution>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _ArchiveBatchQrPanel(
              payload: payload,
              title: payload.itemName,
              subtitle: 'Mahsulot customer ro‘yxatidan qidirilmoqda...',
              trailing: const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              formatQty: _formatQty,
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ArchiveBatchQrPanel(
              payload: payload,
              title: 'Mahsulot topilmadi',
              subtitle:
                  'Batch QR ichidagi mahsulot customer jo‘natish ro‘yxatidan topilmadi.',
              trailing: Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
              ),
              formatQty: _formatQty,
              showScanActions: true,
            );
          }

          final resolved = snapshot.data!;
          final option = resolved.option;
          final selectedCustomer =
              _selectedCustomer ?? resolved.defaultCustomer;
          return _ArchiveBatchQrPanel(
            payload: payload,
            title: option.itemName,
            subtitle: selectedCustomer.name,
            trailing: Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
            ),
            formatQty: _formatQty,
            resolvedOption: option,
            selectedCustomer: selectedCustomer,
            onPickCustomer: () => _pickCustomer(resolved),
            isSubmitting: _submitting,
            onSend: _submitting ? null : () => _send(resolved),
            showScanActions: true,
          );
        },
      ),
    );
  }
}

class _ArchiveBatchQrResolution {
  const _ArchiveBatchQrResolution({
    required this.option,
    required this.defaultCustomer,
  });

  final CustomerItemOption option;
  final CustomerDirectoryEntry defaultCustomer;
}

class _ArchiveBatchQrPanel extends StatelessWidget {
  const _ArchiveBatchQrPanel({
    required this.payload,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.formatQty,
    this.resolvedOption,
    this.isSubmitting = false,
    this.onSend,
    this.showScanActions = false,
    this.selectedCustomer,
    this.onPickCustomer,
  });

  final WerkaArchiveBatchQrPayload payload;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String Function(double qty) formatQty;
  final CustomerItemOption? resolvedOption;
  final bool isSubmitting;
  final Future<void> Function()? onSend;
  final bool showScanActions;
  final CustomerDirectoryEntry? selectedCustomer;
  final VoidCallback? onPickCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final option = resolvedOption;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    trailing,
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Netto',
                        value: '${formatQty(payload.nettoQty)} Kg',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Brutto',
                        value: '${formatQty(payload.bruttoQty)} Kg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Session', value: payload.sessionID),
                if (payload.batchTime.trim().isNotEmpty)
                  _InfoRow(label: 'Sana', value: payload.batchTime),
                if (option != null)
                  _InfoRow(label: 'Kod', value: option.itemCode),
                if (selectedCustomer != null)
                  _InfoRow(
                    label: 'Haridor',
                    value: selectedCustomer!.name,
                    icon: Icons.person_outline_rounded,
                    onTap: onPickCustomer,
                    trailing: const Icon(Icons.expand_more_rounded),
                  ),
                if (option?.warehouse.trim().isNotEmpty ?? false)
                  _InfoRow(
                    label: 'Ombor',
                    value: option!.warehouse,
                    icon: Icons.warehouse_outlined,
                  ),
                if (onSend != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              final send = onSend;
                              if (send != null) {
                                send();
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Icon(Icons.local_shipping_outlined),
                      label: Text(
                        isSubmitting
                            ? 'Jo‘natilmoqda...'
                            : 'Customerga jo‘natish',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showScanActions) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pushReplacementNamed(
                    AppRoutes.werkaStockEntryQrScan,
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Qayta scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Ortga'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: onTap == null ? 0 : 10,
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayValue,
              textAlign: trailing == null ? TextAlign.start : TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            IconTheme.merge(
              data: IconThemeData(
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}
