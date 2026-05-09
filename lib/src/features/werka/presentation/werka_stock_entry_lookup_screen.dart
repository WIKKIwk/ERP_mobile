import 'dart:async';

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
import '../../shared/models/stock_entry_lookup.dart';
import 'werka_success_screen.dart';
import 'widgets/m3_picker_sheet.dart';
import 'package:flutter/material.dart';

class WerkaStockEntryLookupArgs {
  const WerkaStockEntryLookupArgs({
    required this.scannedBarcode,
    this.rawValue = '',
  });

  final String scannedBarcode;
  final String rawValue;
}

abstract class WerkaStockEntryLookupApi {
  Future<StockEntryBarcodeLookup> stockEntryLookup({
    required String barcode,
  });

  Future<List<CustomerDirectoryEntry>> customersForItem({
    required String itemCode,
    required String itemName,
    String query = '',
    required int limit,
    int offset = 0,
  });

  Future<WerkaCustomerIssueRecord> createCustomerIssue({
    required String customerRef,
    required String itemCode,
    required double qty,
    required String sourceBarcode,
    required String sourceStockEntryName,
    required int sourceLineIndex,
  });
}

class MobileWerkaStockEntryLookupApi implements WerkaStockEntryLookupApi {
  const MobileWerkaStockEntryLookupApi();

  @override
  Future<StockEntryBarcodeLookup> stockEntryLookup({
    required String barcode,
  }) {
    return MobileApi.instance.werkaStockEntryLookup(barcode: barcode);
  }

  @override
  Future<List<CustomerDirectoryEntry>> customersForItem({
    required String itemCode,
    required String itemName,
    String query = '',
    required int limit,
    int offset = 0,
  }) {
    return MobileApi.instance.werkaCustomersForItem(
      itemCode: itemCode,
      itemName: itemName,
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<WerkaCustomerIssueRecord> createCustomerIssue({
    required String customerRef,
    required String itemCode,
    required double qty,
    required String sourceBarcode,
    required String sourceStockEntryName,
    required int sourceLineIndex,
  }) {
    return MobileApi.instance.createWerkaCustomerIssue(
      customerRef: customerRef,
      itemCode: itemCode,
      qty: qty,
      sourceBarcode: sourceBarcode,
      sourceStockEntryName: sourceStockEntryName,
      sourceLineIndex: sourceLineIndex,
    );
  }
}

class WerkaStockEntryLookupScreen extends StatefulWidget {
  const WerkaStockEntryLookupScreen({
    super.key,
    required this.args,
    this.api = const MobileWerkaStockEntryLookupApi(),
  });

  final WerkaStockEntryLookupArgs args;
  final WerkaStockEntryLookupApi api;

  @override
  State<WerkaStockEntryLookupScreen> createState() =>
      _WerkaStockEntryLookupScreenState();
}

class _WerkaStockEntryLookupScreenState
    extends State<WerkaStockEntryLookupScreen> {
  late Future<StockEntryBarcodeLookup> _future;
  String? _errorText;
  String? _submittingEntryKey;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StockEntryBarcodeLookup> _load() {
    return widget.api.stockEntryLookup(
      barcode: widget.args.scannedBarcode,
    );
  }

  Future<void> _retry() async {
    setState(() {
      _errorText = null;
      _future = _load();
    });
    try {
      await _future;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = _messageForError(error));
    }
  }

  String _messageForError(Object error) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'stock_entry_not_found' => 'Bu barcode bo‘yicha stock entry topilmadi.',
        'direct_db_lookup_unavailable' =>
          'Barcode lookup vaqtincha ishlamayapti.',
        'stock_entry_lookup_bad_request' => 'Barcode bo‘sh yoki noto‘g‘ri.',
        _ => error.message.isEmpty
            ? 'Barcode tekshirishda xatolik.'
            : error.message,
      };
    }
    return 'Barcode tekshirishda xatolik.';
  }

  String _docStatusLabel(int value) {
    return switch (value) {
      0 => 'Draft',
      1 => 'Submitted',
      2 => 'Cancelled',
      _ => 'Doc $value',
    };
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _warehouseText(String source, String target) {
    final left = source.trim().isEmpty ? '—' : source.trim();
    final right = target.trim().isEmpty ? '—' : target.trim();
    return '$left → $right';
  }

  String _entryKey(StockEntryBarcodeEntry entry) {
    return '${entry.stockEntryName}|${entry.lineIndex}|${entry.barcode}';
  }

  Future<void> _createCustomerIssueFromEntry(
    StockEntryBarcodeEntry entry,
    CustomerDirectoryEntry customer,
  ) async {
    final l10n = context.l10n;
    final itemCode = entry.itemCode.trim();
    if (itemCode.isEmpty || entry.qty <= 0 || customer.ref.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.qtyRequired)),
      );
      return;
    }

    final key = _entryKey(entry);
    setState(() => _submittingEntryKey = key);
    try {
      final created = await widget.api.createCustomerIssue(
        customerRef: customer.ref,
        itemCode: itemCode,
        qty: entry.qty,
        sourceBarcode: entry.barcode.trim().isNotEmpty
            ? entry.barcode
            : widget.args.scannedBarcode,
        sourceStockEntryName: entry.stockEntryName,
        sourceLineIndex: entry.lineIndex,
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
              : error is MobileApiException &&
                      error.code == 'duplicate_customer_issue_source'
                  ? 'Bu QR oldin customerga jo‘natilgan.'
                  : error is MobileApiException &&
                          error.code == 'customer_not_found'
                      ? 'Bu mahsulot uchun customer topilmadi.'
                      : l10n.customerIssueFailed(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted && _submittingEntryKey == key) {
        setState(() => _submittingEntryKey = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppShell(
      title: 'QR natija',
      subtitle: widget.args.scannedBarcode,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      backgroundColor: scheme.surface,
      child: FutureBuilder<StockEntryBarcodeLookup>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _LoadingView(
              barcode: widget.args.scannedBarcode,
              rawValue: widget.args.rawValue,
            );
          }

          if (snapshot.hasError) {
            final message = _errorText ?? _messageForError(snapshot.error!);
            return _ErrorView(
              message: message,
              onRetry: _retry,
              onBackToScan: () => Navigator.of(context).pushReplacementNamed(
                AppRoutes.werkaStockEntryQrScan,
              ),
            );
          }

          final lookup = snapshot.data;
          if (lookup == null) {
            return _ErrorView(
              message: 'Barcode bo‘yicha ma’lumot topilmadi.',
              onRetry: _retry,
              onBackToScan: () => Navigator.of(context).pushReplacementNamed(
                AppRoutes.werkaStockEntryQrScan,
              ),
            );
          }

          return _ResultView(
            lookup: lookup,
            args: widget.args,
            formatQty: _formatQty,
            docStatusLabel: _docStatusLabel,
            warehouseText: _warehouseText,
            submittingEntryKey: _submittingEntryKey,
            entryKey: _entryKey,
            api: widget.api,
            onCreateCustomerIssue: _createCustomerIssueFromEntry,
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({
    required this.barcode,
    required this.rawValue,
  });

  final String barcode;
  final String rawValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(barcode, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Serverdan stock entry qidirilmoqda...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (rawValue.trim().isNotEmpty &&
                    rawValue.trim() != barcode) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Raw QR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    rawValue,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 18),
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 10),
                Text(
                  'Loading...',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBackToScan,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onBackToScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lookup xatosi',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          unawaited(onRetry());
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Qayta urinish'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onBackToScan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Qayta scan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.lookup,
    required this.args,
    required this.formatQty,
    required this.docStatusLabel,
    required this.warehouseText,
    required this.submittingEntryKey,
    required this.entryKey,
    required this.api,
    required this.onCreateCustomerIssue,
  });

  final StockEntryBarcodeLookup lookup;
  final WerkaStockEntryLookupArgs args;
  final WerkaStockEntryLookupApi api;
  final String Function(double value) formatQty;
  final String Function(int value) docStatusLabel;
  final String Function(String source, String target) warehouseText;
  final String Function(StockEntryBarcodeEntry entry) entryKey;
  final String? submittingEntryKey;
  final Future<void> Function(
    StockEntryBarcodeEntry entry,
    CustomerDirectoryEntry customer,
  ) onCreateCustomerIssue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
      children: [
        _LookupSummary(
          barcode: lookup.barcode,
          rawValue: args.rawValue,
          scannedBarcode: args.scannedBarcode,
          lineCount: lookup.count,
          hasMultipleEntries: lookup.hasMultipleEntries,
        ),
        const SizedBox(height: 10),
        for (int index = 0; index < lookup.entries.length; index++) ...[
          _LookupEntryPanel(
            entry: lookup.entries[index],
            formatQty: formatQty,
            docStatusLabel: docStatusLabel,
            warehouseText: warehouseText,
            api: api,
            isSubmitting: submittingEntryKey == entryKey(lookup.entries[index]),
            onCreateCustomerIssue: onCreateCustomerIssue,
          ),
          if (index != lookup.entries.length - 1) const SizedBox(height: 12),
        ],
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
    );
  }
}

class _LookupSummary extends StatelessWidget {
  const _LookupSummary({
    required this.barcode,
    required this.rawValue,
    required this.scannedBarcode,
    required this.lineCount,
    required this.hasMultipleEntries,
  });

  final String barcode;
  final String rawValue;
  final String scannedBarcode;
  final int lineCount;
  final bool hasMultipleEntries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showRaw =
        rawValue.trim().isNotEmpty && rawValue.trim() != scannedBarcode;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    barcode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(
                  label: hasMultipleEntries ? '$lineCount line' : '1 line',
                ),
              ],
            ),
            if (showRaw) ...[
              const SizedBox(height: 8),
              SelectableText(
                rawValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LookupEntryPanel extends StatefulWidget {
  const _LookupEntryPanel({
    required this.entry,
    required this.formatQty,
    required this.docStatusLabel,
    required this.warehouseText,
    required this.api,
    required this.isSubmitting,
    required this.onCreateCustomerIssue,
  });

  final StockEntryBarcodeEntry entry;
  final WerkaStockEntryLookupApi api;
  final String Function(double value) formatQty;
  final String Function(int value) docStatusLabel;
  final String Function(String source, String target) warehouseText;
  final bool isSubmitting;
  final Future<void> Function(
    StockEntryBarcodeEntry entry,
    CustomerDirectoryEntry customer,
  ) onCreateCustomerIssue;

  @override
  State<_LookupEntryPanel> createState() => _LookupEntryPanelState();
}

class _LookupEntryPanelState extends State<_LookupEntryPanel> {
  CustomerDirectoryEntry? _selectedCustomer;
  bool _loadingCustomer = true;
  Object? _customerError;
  int _customerGeneration = 0;

  StockEntryBarcodeEntry get entry => widget.entry;

  bool get _canCreateCustomerIssue {
    return entry.itemCode.trim().isNotEmpty &&
        entry.qty > 0 &&
        _selectedCustomer != null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDefaultCustomer());
  }

  @override
  void didUpdateWidget(covariant _LookupEntryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.itemCode != widget.entry.itemCode ||
        oldWidget.entry.itemName != widget.entry.itemName ||
        oldWidget.entry.lineIndex != widget.entry.lineIndex) {
      _selectedCustomer = null;
      unawaited(_loadDefaultCustomer());
    }
  }

  Future<void> _loadDefaultCustomer() async {
    final itemCode = entry.itemCode.trim();
    final generation = ++_customerGeneration;
    if (itemCode.isEmpty) {
      setState(() {
        _loadingCustomer = false;
        _customerError = null;
      });
      return;
    }

    setState(() {
      _loadingCustomer = true;
      _customerError = null;
    });
    try {
      final customers = await widget.api.customersForItem(
        itemCode: itemCode,
        itemName: entry.itemName,
        limit: 200,
        offset: 0,
      );
      final customer = preferPrimaryCustomer<CustomerDirectoryEntry>(
        customers,
        customerName: (item) => item.name,
      );
      if (!mounted || generation != _customerGeneration) {
        return;
      }
      setState(() {
        _selectedCustomer = customer;
        _loadingCustomer = false;
      });
    } catch (error) {
      if (!mounted || generation != _customerGeneration) {
        return;
      }
      setState(() {
        _customerError = error;
        _loadingCustomer = false;
      });
    }
  }

  Future<void> _pickCustomer() async {
    if (widget.isSubmitting || entry.itemCode.trim().isEmpty) {
      return;
    }

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
          supportingText: entry.itemName,
          hintText: context.l10n.searchCustomer,
          loadPage: (query, offset, limit) => widget.api.customersForItem(
            itemCode: entry.itemCode,
            itemName: entry.itemName,
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
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedCustomer = picked;
      _customerError = null;
      _loadingCustomer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final itemTitle = entry.itemName.isEmpty ? entry.itemCode : entry.itemName;
    final customer = _selectedCustomer;
    return DecoratedBox(
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
                        entry.stockEntryName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.stockEntryType.isEmpty
                            ? 'Stock Entry'
                            : entry.stockEntryType,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: widget.docStatusLabel(entry.docStatus),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Miqdor',
                    value: '${widget.formatQty(entry.qty)} ${entry.uom}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Holat',
                    value: entry.status.trim().isEmpty
                        ? widget.docStatusLabel(entry.docStatus)
                        : entry.status,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Mahsulot',
              value: itemTitle,
            ),
            _InfoRow(
              label: 'Kod',
              value: entry.itemCode,
            ),
            if (entry.company.trim().isNotEmpty)
              _InfoRow(
                label: 'Kompaniya',
                value: entry.company,
              ),
            _InfoRow(
              label: 'Haridor',
              value: _customerLabel,
              icon: Icons.person_outline_rounded,
              onTap: _loadingCustomer ? null : _pickCustomer,
              trailing: _loadingCustomer
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
            ),
            if (entry.barcode.trim().isNotEmpty)
              _InfoRow(
                label: 'Barcode',
                value: entry.barcode,
                selectable: true,
              ),
            if (entry.sourceWarehouse.trim().isNotEmpty ||
                entry.targetWarehouse.trim().isNotEmpty)
              _InfoRow(
                label: 'Ombor',
                value: widget.warehouseText(
                  entry.sourceWarehouse,
                  entry.targetWarehouse,
                ),
                icon: Icons.warehouse_outlined,
              ),
            if (entry.remarks.trim().isNotEmpty)
              _InfoRow(
                label: 'Izoh',
                value: entry.remarks,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Line ${entry.lineIndex}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canCreateCustomerIssue && !widget.isSubmitting
                    ? () => unawaited(
                          widget.onCreateCustomerIssue(entry, customer!),
                        )
                    : null,
                icon: widget.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.local_shipping_outlined),
                label: Text(
                  widget.isSubmitting
                      ? 'Jo‘natilmoqda...'
                      : 'Customerga jo‘natish',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _customerLabel {
    if (_loadingCustomer) {
      return 'Haridor qidirilmoqda...';
    }
    final customer = _selectedCustomer;
    if (customer != null && customer.name.trim().isNotEmpty) {
      return customer.name;
    }
    if (_customerError != null) {
      return 'Haridorni yuklab bo‘lmadi';
    }
    return 'Haridor topilmadi';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
    final scheme = theme.colorScheme;
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
    this.selectable = false,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool selectable;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: onTap == null ? 0 : 10,
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
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
            child: selectable
                ? SelectableText(
                    displayValue,
                    style: valueStyle,
                  )
                : Text(
                    displayValue,
                    style: valueStyle,
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
