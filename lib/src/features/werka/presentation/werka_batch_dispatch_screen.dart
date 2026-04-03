import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/app_preview.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/refresh_hub.dart';
import '../../../core/notifications/werka_runtime_store.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'dart:math';
import 'widgets/m3_picker_sheet.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaBatchDispatchScreen extends StatefulWidget {
  const WerkaBatchDispatchScreen({super.key});

  @override
  State<WerkaBatchDispatchScreen> createState() =>
      _WerkaBatchDispatchScreenState();
}

class _WerkaBatchDispatchScreenState extends State<WerkaBatchDispatchScreen> {
  final TextEditingController _qtyController = TextEditingController();
  final List<_WerkaBatchDraftLine> _drafts = <_WerkaBatchDraftLine>[];
  final bool _previewMode = AppPreview.batchDispatchDemo;

  CustomerDirectoryEntry? _selectedCustomer;
  SupplierItem? _selectedItem;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  CustomerDirectoryEntry _customerFromOption(CustomerItemOption option) {
    return CustomerDirectoryEntry(
      ref: option.customerRef,
      name: option.customerName,
      phone: option.customerPhone,
    );
  }

  SupplierItem _itemFromOption(CustomerItemOption option) {
    return SupplierItem(
      code: option.itemCode,
      name: option.itemName,
      uom: option.uom,
      warehouse: option.warehouse,
    );
  }

  double get _currentQty => double.tryParse(_qtyController.text.trim()) ?? 0;

  bool get _hasCurrentValidLine =>
      _selectedCustomer != null && _selectedItem != null && _currentQty > 0;

  Future<void> _pickCustomer() async {
    if (_previewMode) {
      final previewCustomers = _selectedItem == null
          ? _previewCustomers
          : _previewOptions
              .where((item) => item.itemCode == _selectedItem!.code)
              .map(_customerFromOption)
              .fold<List<CustomerDirectoryEntry>>(<CustomerDirectoryEntry>[], (
              result,
              customer,
            ) {
              if (result.any((item) => item.ref == customer.ref)) {
                return result;
              }
              return [...result, customer];
            });
      final picked = await showModalBottomSheet<CustomerDirectoryEntry>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3PickerSheet<CustomerDirectoryEntry>(
            title: context.l10n.selectCustomer,
            hintText: context.l10n.searchCustomer,
            items: previewCustomers,
            itemTitle: (item) => item.name,
            itemSubtitle: (item) => item.phone,
            matchesQuery: (item, query) => searchMatches(query, [
              item.name,
              item.phone,
            ]),
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedCustomer = picked;
        if (_selectedItem == null) {
          _qtyController.clear();
        }
      });
      return;
    }

    final picked = await showModalBottomSheet<CustomerDirectoryEntry>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerDirectoryEntry>(
          title: context.l10n.selectCustomer,
          hintText: context.l10n.searchCustomer,
          loadPage: (query, offset, limit) => _selectedItem != null
              ? MobileApi.instance.werkaCustomersForItem(
                  itemCode: _selectedItem!.code,
                  itemName: _selectedItem!.name,
                  query: query,
                  offset: offset,
                  limit: limit,
                )
              : MobileApi.instance.werkaCustomers(
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
    setState(() {
      _selectedCustomer = picked;
      if (_selectedItem == null) {
        _qtyController.clear();
      }
    });
  }

  Future<void> _pickItem() async {
    if (_previewMode) {
      if (_selectedCustomer != null) {
        final items = _previewOptions
            .where((item) => item.customerRef == _selectedCustomer!.ref)
            .map(_itemFromOption)
            .toList();
        final picked = await showModalBottomSheet<SupplierItem>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          sheetAnimationStyle: kM3PickerSheetAnimation,
          builder: (context) {
            return M3PickerSheet<SupplierItem>(
              title: context.l10n.selectItem,
              supportingText: _selectedCustomer!.name,
              hintText: context.l10n.searchItem,
              items: items,
              itemTitle: (item) => item.name,
              itemSubtitle: (item) => item.code,
              matchesQuery: (item, query) => searchMatches(query, [
                item.name,
                item.code,
                _selectedCustomer!.name,
              ]),
              onSelected: (item) => Navigator.of(context).pop(item),
            );
          },
        );
        if (picked == null || !mounted) {
          return;
        }
        setState(() {
          _selectedItem = picked;
          _qtyController.clear();
        });
        return;
      }

      final picked = await showModalBottomSheet<CustomerItemOption>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3PickerSheet<CustomerItemOption>(
            title: context.l10n.selectItem,
            hintText: context.l10n.searchItem,
            items: _previewOptions,
            itemTitle: (item) => item.itemName,
            itemSubtitle: (item) => '${item.customerName} • ${item.itemCode}',
            matchesQuery: (item, query) => searchMatches(query, [
              item.itemName,
              item.itemCode,
              item.customerName,
            ]),
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedCustomer = _customerFromOption(picked);
        _selectedItem = _itemFromOption(picked);
        _qtyController.clear();
      });
      return;
    }

    if (_selectedCustomer != null) {
      final picked = await showModalBottomSheet<SupplierItem>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3AsyncPickerSheet<SupplierItem>(
            title: context.l10n.selectItem,
            supportingText: _selectedCustomer!.name,
            hintText: context.l10n.searchItem,
            loadPage: (query, offset, limit) =>
                MobileApi.instance.werkaCustomerItems(
              customerRef: _selectedCustomer!.ref,
              query: query,
              offset: offset,
              limit: limit,
            ),
            itemTitle: (item) => item.name,
            itemSubtitle: (item) => item.code,
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedItem = picked;
        _qtyController.clear();
      });
      return;
    }

    final picked = await showModalBottomSheet<CustomerItemOption>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerItemOption>(
          title: context.l10n.selectItem,
          hintText: context.l10n.searchItem,
          loadPage: (query, offset, limit) =>
              MobileApi.instance.werkaCustomerItemOptions(
            query: query,
            offset: offset,
            limit: limit,
          ),
          itemTitle: (item) => item.itemName,
          itemSubtitle: (item) => '${item.customerName} • ${item.itemCode}',
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedCustomer = _customerFromOption(picked);
      _selectedItem = _itemFromOption(picked);
      _qtyController.clear();
    });
  }

  _WerkaBatchDraftLine _buildCurrentLine() {
    return _WerkaBatchDraftLine(
      localID: DateTime.now().microsecondsSinceEpoch.toString(),
      customer: _selectedCustomer!,
      item: _selectedItem!,
      qty: _currentQty,
    );
  }

  void _prepareNextLine() {
    _selectedItem = null;
    _qtyController.clear();
  }

  void _saveCurrentLine() {
    if (!_hasCurrentValidLine) {
      return;
    }
    final line = _buildCurrentLine();
    setState(() {
      _drafts.add(line);
      _prepareNextLine();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.batchDraftAdded)),
    );
  }

  Future<void> _openReview({bool saveCurrentLine = false}) async {
    if (saveCurrentLine && !_hasCurrentValidLine) {
      return;
    }

    final lines = <_WerkaBatchDraftLine>[
      ..._drafts,
      if (saveCurrentLine) _buildCurrentLine(),
    ];
    if (lines.isEmpty) {
      return;
    }

    if (saveCurrentLine) {
      setState(() {
        _drafts
          ..clear()
          ..addAll(lines);
        _prepareNextLine();
      });
    }

    final updated =
        await Navigator.of(context).push<List<_WerkaBatchDraftLine>>(
      MaterialPageRoute<List<_WerkaBatchDraftLine>>(
        builder: (context) => _WerkaBatchDispatchReviewScreen(
          initialLines: lines,
          previewMode: _previewMode,
        ),
        settings: const RouteSettings(name: 'werka-batch-dispatch-review'),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _drafts
        ..clear()
        ..addAll(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasSavedLines = _drafts.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.shellStart(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _BatchDispatchHeader(title: l10n.batchDispatchTitle, theme: theme),
            const SizedBox(height: 20),
            Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.batchDispatchTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.batchDispatchDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (_previewMode) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Preview mode',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                    if (hasSavedLines) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          l10n.batchDraftCountLabel(_drafts.length),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(l10n.itemLabel, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _pickItem,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_selectedItem?.name ?? l10n.selectItem),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.customerLabel, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _pickCustomer,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _selectedCustomer?.name ?? l10n.selectCustomer,
                          ),
                        ),
                      ),
                    ),
                    if (_selectedCustomer != null &&
                        _selectedItem == null &&
                        _selectedCustomer!.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        _selectedCustomer!.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_selectedItem != null) ...[
                      const SizedBox(height: 14),
                      Text(l10n.amountLabel, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '0',
                          suffixText: _selectedItem!.uom,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (!hasSavedLines)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _hasCurrentValidLine ? _saveCurrentLine : null,
                          child: Text(l10n.nextItemAction),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _hasCurrentValidLine
                                  ? _saveCurrentLine
                                  : null,
                              child: Text(l10n.addAnotherAction),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _hasCurrentValidLine
                                  ? () => _openReview(saveCurrentLine: true)
                                  : _drafts.length >= 2
                                      ? () => _openReview()
                                      : null,
                              child: Text(l10n.confirmTitle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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

class _WerkaBatchDispatchReviewScreen extends StatefulWidget {
  const _WerkaBatchDispatchReviewScreen({
    required this.initialLines,
    required this.previewMode,
  });

  final List<_WerkaBatchDraftLine> initialLines;
  final bool previewMode;

  @override
  State<_WerkaBatchDispatchReviewScreen> createState() =>
      _WerkaBatchDispatchReviewScreenState();
}

class _WerkaBatchDispatchReviewScreenState
    extends State<_WerkaBatchDispatchReviewScreen> {
  final ScrollController _scrollController = ScrollController();

  late List<_WerkaBatchDraftLine> _lines;
  bool _reviewUnlocked = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lines = List<_WerkaBatchDraftLine>.from(widget.initialLines);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final atEnd = position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 12;
    if (_reviewUnlocked == atEnd) {
      return;
    }
    setState(() => _reviewUnlocked = atEnd);
  }

  int get _customerCount =>
      _lines.map((item) => item.customer.ref).toSet().length;

  DispatchRecord _recordFromIssue(WerkaCustomerIssueRecord created) {
    return DispatchRecord(
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
  }

  Future<void> _submit() async {
    if (_submitting || _lines.length < 2 || !_reviewUnlocked) {
      return;
    }

    if (widget.previewMode) {
      setState(() => _submitting = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => _WerkaBatchSuccessScreen(
            createdCount: _lines.length,
            failedCount: 0,
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final batchID =
        'batch-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
    final result = await MobileApi.instance.createWerkaCustomerIssueBatch(
      clientBatchID: batchID,
      lines: _lines
          .map(
            (line) => WerkaCustomerIssueBatchLineRequest(
              customerRef: line.customer.ref,
              itemCode: line.item.code,
              qty: line.qty,
            ),
          )
          .toList(),
    );

    final failedIndices = result.failed.map((item) => item.lineIndex).toSet();
    final failed = <_WerkaBatchDraftLine>[
      for (var i = 0; i < _lines.length; i++)
        if (failedIndices.contains(i)) _lines[i],
    ];
    final createdCount = result.created.length;

    for (final created in result.created) {
      final record = created.record;
      if (record == null) {
        continue;
      }
      WerkaRuntimeStore.instance.recordCreatedPending(
        _recordFromIssue(record),
      );
    }

    RefreshHub.instance.emit('werka');

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    final l10n = context.l10n;
    if (failed.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => _WerkaBatchSuccessScreen(
            createdCount: createdCount,
            failedCount: 0,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.batchSubmitResultTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.batchCreatedCountLabel(createdCount)),
              const SizedBox(height: 8),
              Text(l10n.batchFailedCountLabel(failed.length)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.closeAction),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSubmit = !_submitting && _reviewUnlocked && _lines.length >= 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_lines);
      },
      child: Scaffold(
        backgroundColor: AppTheme.shellStart(context),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _BatchDispatchHeader(
                  title: l10n.batchReviewTitle,
                  theme: theme,
                  onBackPressed: () => Navigator.of(context).pop(_lines),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Card.filled(
                      margin: EdgeInsets.zero,
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.batchReviewTitle,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SummaryChip(
                                  label: l10n.batchCustomerCountLabel(
                                    _customerCount,
                                  ),
                                ),
                                _SummaryChip(
                                  label:
                                      l10n.batchDraftCountLabel(_lines.length),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final line in _lines) ...[
                      Card.filled(
                        margin: EdgeInsets.zero,
                        color: scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.customer.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      line.item.name,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${line.qty.toStringAsFixed(0)} ${line.item.uom} • ${line.item.code}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .deleteButtonTooltip,
                                onPressed: _submitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _lines = _lines
                                              .where(
                                                (item) =>
                                                    item.localID !=
                                                    line.localID,
                                              )
                                              .toList();
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                          (_) => _handleScroll(),
                                        );
                                      },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _lines.length < 2
                      ? l10n.batchNeedAtLeastTwoItems
                      : l10n.batchReviewUnlockHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: Text(
                    _submitting ? l10n.sending : l10n.confirmTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WerkaBatchDraftLine {
  const _WerkaBatchDraftLine({
    required this.localID,
    required this.customer,
    required this.item,
    required this.qty,
  });

  final String localID;
  final CustomerDirectoryEntry customer;
  final SupplierItem item;
  final double qty;
}

class _BatchDispatchHeader extends StatelessWidget {
  const _BatchDispatchHeader({
    required this.title,
    required this.theme,
    this.onBackPressed,
  });

  final String title;
  final ThemeData theme;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final showFlutterBackButton = !useNativeBackButton(context);
    return Row(
      children: [
        if (showFlutterBackButton) ...[
          NativeBackButtonSlot(
            onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WerkaBatchSuccessScreen extends StatelessWidget {
  const _WerkaBatchSuccessScreen({
    required this.createdCount,
    required this.failedCount,
  });

  final int createdCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppShell(
      title: l10n.sentSuccess,
      subtitle: '',
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      bottom: const WerkaDock(activeTab: null),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 140),
          Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 44,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.batchCreatedCountLabel(createdCount),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    failedCount > 0
                        ? l10n.batchFailedCountLabel(failedCount)
                        : l10n.batchSentLine(createdCount),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.werkaCreateHub,
                (route) => route.isFirst,
              ),
              child: Text(l10n.createFlowBack),
            ),
          ),
        ],
      ),
    );
  }
}

const List<CustomerDirectoryEntry> _previewCustomers = [
  CustomerDirectoryEntry(
    ref: 'CUST-001',
    name: 'Aziz Market',
    phone: '+998901111111',
  ),
  CustomerDirectoryEntry(
    ref: 'CUST-002',
    name: 'Sardor Do\'kon',
    phone: '+998902222222',
  ),
  CustomerDirectoryEntry(
    ref: 'CUST-003',
    name: 'Dilnoza Shop',
    phone: '+998903333333',
  ),
];

const List<CustomerItemOption> _previewOptions = [
  CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Aziz Market',
    customerPhone: '+998901111111',
    itemCode: 'ITEM-001',
    itemName: 'Un 5kg',
    uom: 'Qop',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Aziz Market',
    customerPhone: '+998901111111',
    itemCode: 'ITEM-002',
    itemName: 'Yog\' 1L',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-002',
    customerName: 'Sardor Do\'kon',
    customerPhone: '+998902222222',
    itemCode: 'ITEM-003',
    itemName: 'Shakar 5kg',
    uom: 'Qop',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-003',
    customerName: 'Dilnoza Shop',
    customerPhone: '+998903333333',
    itemCode: 'ITEM-004',
    itemName: 'Guruch 1kg',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-003',
    customerName: 'Dilnoza Shop',
    customerPhone: '+998903333333',
    itemCode: 'ITEM-005',
    itemName: 'Makaron',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
];
