import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/stock_entry_lookup.dart';
import 'package:flutter/material.dart';

class WerkaStockEntryLookupArgs {
  const WerkaStockEntryLookupArgs({
    required this.scannedBarcode,
    this.rawValue = '',
  });

  final String scannedBarcode;
  final String rawValue;
}

class WerkaStockEntryLookupScreen extends StatefulWidget {
  const WerkaStockEntryLookupScreen({
    super.key,
    required this.args,
  });

  final WerkaStockEntryLookupArgs args;

  @override
  State<WerkaStockEntryLookupScreen> createState() =>
      _WerkaStockEntryLookupScreenState();
}

class _WerkaStockEntryLookupScreenState
    extends State<WerkaStockEntryLookupScreen> {
  late Future<StockEntryBarcodeLookup> _future;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StockEntryBarcodeLookup> _load() {
    return MobileApi.instance.werkaStockEntryLookup(
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
  });

  final StockEntryBarcodeLookup lookup;
  final WerkaStockEntryLookupArgs args;
  final String Function(double value) formatQty;
  final String Function(int value) docStatusLabel;
  final String Function(String source, String target) warehouseText;

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
                        Icons.qr_code_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lookup.barcode,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lookup.hasMultipleEntries
                                ? '${lookup.count} ta line topildi'
                                : '1 ta line topildi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: const Text('Barcode'),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ],
                ),
                if (args.rawValue.trim().isNotEmpty &&
                    args.rawValue.trim() != args.scannedBarcode) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Raw QR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    args.rawValue,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (int index = 0; index < lookup.entries.length; index++) ...[
          _LookupEntryCard(
            entry: lookup.entries[index],
            formatQty: formatQty,
            docStatusLabel: docStatusLabel,
            warehouseText: warehouseText,
          ),
          if (index != lookup.entries.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
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

class _LookupEntryCard extends StatelessWidget {
  const _LookupEntryCard({
    required this.entry,
    required this.formatQty,
    required this.docStatusLabel,
    required this.warehouseText,
  });

  final StockEntryBarcodeEntry entry;
  final String Function(double value) formatQty;
  final String Function(int value) docStatusLabel;
  final String Function(String source, String target) warehouseText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.stockEntryName,
                        style: theme.textTheme.titleLarge,
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
                Chip(
                  label: Text(docStatusLabel(entry.docStatus)),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: 'Item',
                  value:
                      entry.itemName.isEmpty ? entry.itemCode : entry.itemName,
                ),
                _MetaChip(
                  label: 'Code',
                  value: entry.itemCode,
                ),
                _MetaChip(
                  label: 'Qty',
                  value: '${formatQty(entry.qty)} ${entry.uom}',
                ),
                if (entry.status.trim().isNotEmpty)
                  _MetaChip(
                    label: 'Status',
                    value: entry.status,
                  ),
                if (entry.company.trim().isNotEmpty)
                  _MetaChip(
                    label: 'Company',
                    value: entry.company,
                  ),
                if (entry.barcode.trim().isNotEmpty)
                  _MetaChip(
                    label: 'Barcode',
                    value: entry.barcode,
                  ),
              ],
            ),
            if (entry.sourceWarehouse.trim().isNotEmpty ||
                entry.targetWarehouse.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warehouseText(
                        entry.sourceWarehouse,
                        entry.targetWarehouse,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (entry.remarks.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                entry.remarks,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Line ${entry.lineIndex}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
    final scheme = theme.colorScheme;
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
