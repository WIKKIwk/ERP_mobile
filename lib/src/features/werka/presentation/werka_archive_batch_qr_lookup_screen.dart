import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'werka_archive_batch_qr.dart';
import 'werka_customer_issue_prefill.dart';

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
  late Future<CustomerItemOption> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolveItem();
  }

  Future<CustomerItemOption> _resolveItem() async {
    final payload = widget.args.payload;
    final options = await MobileApi.instance.werkaCustomerItemOptions(
      query: payload.itemName,
      limit: 200,
    );
    if (options.isEmpty) {
      throw StateError('batch_item_not_found');
    }

    final normalizedItem = _normalize(payload.itemName);
    return options.firstWhere(
      (option) =>
          _normalize(option.itemName) == normalizedItem ||
          _normalize(option.itemCode) == normalizedItem,
      orElse: () => options.first,
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
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

  void _send(CustomerItemOption option) {
    final payload = widget.args.payload;
    Navigator.of(context).pushNamed(
      AppRoutes.werkaCustomerIssueCustomer,
      arguments: WerkaCustomerIssuePrefillArgs(
        customerRef: option.customerRef,
        customerName: option.customerName,
        itemCode: option.itemCode,
        itemName:
            option.itemName.trim().isEmpty ? payload.itemName : option.itemName,
        qty: payload.qty,
        uom: option.uom.trim().isEmpty ? 'Kg' : option.uom,
        warehouse: option.warehouse,
        sourceStockEntryName: 'Batch ${payload.sessionID}',
        sourceBarcode: payload.rawValue,
      ),
    );
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
      child: FutureBuilder<CustomerItemOption>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _ArchiveBatchQrCard(
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
            return _ArchiveBatchQrCard(
              payload: payload,
              title: 'Mahsulot topilmadi',
              subtitle:
                  'Batch QR ichidagi mahsulot customer jo‘natish ro‘yxatidan topilmadi.',
              trailing: Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
              ),
              formatQty: _formatQty,
              actions: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.werkaStockEntryQrScan),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Qayta scan'),
                  ),
                ),
              ],
            );
          }

          final option = snapshot.data!;
          return _ArchiveBatchQrCard(
            payload: payload,
            title: option.itemName,
            subtitle: option.customerName,
            trailing: Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
            ),
            formatQty: _formatQty,
            resolvedOption: option,
            actions: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _send(option),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Customerga jo‘natish'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveBatchQrCard extends StatelessWidget {
  const _ArchiveBatchQrCard({
    required this.payload,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.formatQty,
    this.resolvedOption,
    this.actions = const <Widget>[],
  });

  final WerkaArchiveBatchQrPayload payload;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String Function(double qty) formatQty;
  final CustomerItemOption? resolvedOption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final option = resolvedOption;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
      children: [
        Card.filled(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
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
                    trailing,
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      label: 'Netto',
                      value: '${formatQty(payload.nettoQty)} Kg',
                    ),
                    _MetaChip(
                      label: 'Brutto',
                      value: '${formatQty(payload.bruttoQty)} Kg',
                    ),
                    _MetaChip(label: 'Session', value: payload.sessionID),
                    if (payload.batchTime.trim().isNotEmpty)
                      _MetaChip(label: 'Date', value: payload.batchTime),
                    if (option != null)
                      _MetaChip(label: 'Code', value: option.itemCode),
                    if (option?.warehouse.trim().isNotEmpty ?? false)
                      _MetaChip(label: 'Warehouse', value: option!.warehouse),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(children: actions),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '—' : value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
