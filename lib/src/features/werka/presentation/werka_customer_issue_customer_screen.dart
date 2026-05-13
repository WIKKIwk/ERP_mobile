import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/customer/customer_priority.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/search/search_activity_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'werka_customer_issue_prefill.dart';
import 'werka_success_screen.dart';
import 'widgets/m3_picker_sheet.dart';
import 'widgets/werka_dock.dart';

import 'package:flutter/material.dart';

class WerkaCustomerIssueCustomerScreen extends StatefulWidget {
  const WerkaCustomerIssueCustomerScreen({
    super.key,
    this.prefill,
  });

  final WerkaCustomerIssuePrefillArgs? prefill;

  @override
  State<WerkaCustomerIssueCustomerScreen> createState() =>
      _WerkaCustomerIssueCustomerScreenState();
}

class _WerkaCustomerIssueCustomerScreenState
    extends State<WerkaCustomerIssueCustomerScreen> {
  final TextEditingController _qtyController = TextEditingController(text: '1');

  CustomerDirectoryEntry? _selectedCustomer;
  SupplierItem? _selectedItem;
  bool _submitting = false;
  bool _qrPrefillActive = false;
  bool _prefillCustomerLoading = false;
  int _prefillCustomerGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) {
      final prefill = widget.prefill!;
      _qrPrefillActive = prefill.hasSource;
      if (prefill.hasCustomer) {
        _selectedCustomer = CustomerDirectoryEntry(
          ref: prefill.customerRef,
          name: prefill.customerName,
          phone: '',
        );
      }
      _selectedItem = SupplierItem(
        code: prefill.itemCode,
        name: prefill.itemName.trim().isEmpty
            ? prefill.itemCode
            : prefill.itemName,
        uom: prefill.uom,
        warehouse: prefill.warehouse,
      );
      _qtyController.text = _formatQty(prefill.qty);
      if (_selectedCustomer == null) {
        _prefillCustomerLoading = true;
        _loadPreferredCustomerForPrefill();
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
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

  Future<CustomerDirectoryEntry> _preferredCustomerForOption(
    CustomerItemOption option,
  ) async {
    final fallback = _customerFromOption(option);
    try {
      final customers = await MobileApi.instance.werkaCustomersForItem(
        itemCode: option.itemCode,
        itemName: option.itemName,
        limit: 200,
        offset: 0,
      );
      return preferPrimaryCustomer<CustomerDirectoryEntry>(
            customers,
            customerName: (item) => item.name,
          ) ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadPreferredCustomerForPrefill() async {
    final item = _selectedItem;
    if (item == null) {
      return;
    }
    final generation = ++_prefillCustomerGeneration;
    try {
      final customers = await MobileApi.instance.werkaCustomersForItem(
        itemCode: item.code,
        itemName: item.name,
        limit: 200,
        offset: 0,
      );
      final preferred = preferPrimaryCustomer<CustomerDirectoryEntry>(
        customers,
        customerName: (item) => item.name,
      );
      if (!mounted ||
          generation != _prefillCustomerGeneration ||
          _selectedCustomer != null ||
          _selectedItem?.code != item.code) {
        return;
      }
      setState(() {
        _selectedCustomer = preferred;
        _prefillCustomerLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _prefillCustomerGeneration) {
        return;
      }
      setState(() => _prefillCustomerLoading = false);
    }
  }

  void _clearSelectedItem() {
    setState(() {
      _selectedItem = null;
      _qrPrefillActive = false;
      _prefillCustomerLoading = false;
      _prefillCustomerGeneration++;
      _qtyController.clear();
    });
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
      _prefillCustomerLoading = false;
      _prefillCustomerGeneration++;
    });
  }

  Future<void> _pickCustomer() async {
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
      _prefillCustomerLoading = false;
      _prefillCustomerGeneration++;
    });
  }

  Future<void> _pickItem() async {
    if (_submitting) {
      return;
    }

    if (_selectedCustomer != null) {
      final picked = await showModalBottomSheet<SupplierItem>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3AsyncPickerSheet<SupplierItem>(
            title: context.l10n.selectItem,
            supportingText: _selectedCustomer!.name,
            hintText: context.l10n.searchItem,
            showScanIcon: true,
            pageSize: 100,
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
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _selectedItem = picked;
        _qrPrefillActive = false;
        _prefillCustomerLoading = false;
        _prefillCustomerGeneration++;
      });
      return;
    }

    final picked = await showModalBottomSheet<CustomerItemOption>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerItemOption>(
          title: context.l10n.selectItem,
          hintText: context.l10n.searchItem,
          showScanIcon: true,
          pageSize: 200,
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
    if (!mounted || picked == null) {
      return;
    }
    final preferredCustomer = await _preferredCustomerForOption(picked);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCustomer = preferredCustomer;
      _selectedItem = _itemFromOption(picked);
      _qrPrefillActive = false;
      _prefillCustomerLoading = false;
      _prefillCustomerGeneration++;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_selectedCustomer == null || _selectedItem == null) {
      return;
    }
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.qtyRequired)),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.confirmTitle,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                Text(
                  _selectedCustomer!.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedItem!.name,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${qty.toStringAsFixed(0)} ${_selectedItem!.uom}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: M3SegmentFilledSurface(
                        slot: M3SegmentVerticalSlot.middle,
                        cornerRadius: 22,
                        borderRadiusOverride: const BorderRadius.horizontal(
                          left: Radius.circular(22),
                          right: Radius.circular(22),
                        ),
                        backgroundColor: scheme.surface,
                        onTap: () => Navigator.of(context).pop(false),
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: Text(
                              l10n.no,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: M3SegmentFilledSurface(
                        slot: M3SegmentVerticalSlot.middle,
                        cornerRadius: 22,
                        borderRadiusOverride: const BorderRadius.horizontal(
                          left: Radius.circular(22),
                          right: Radius.circular(22),
                        ),
                        backgroundColor: scheme.primary,
                        onTap: () => Navigator.of(context).pop(true),
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: Text(
                              l10n.yes,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await MobileApi.instance.createWerkaCustomerIssue(
        customerRef: _selectedCustomer!.ref,
        itemCode: _selectedItem!.code,
        qty: qty,
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
          returnRouteName: AppRoutes.werkaCustomerIssueCustomer,
          returnLabel: l10n.backToFlow(l10n.customerIssueTitle),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSubmit =
        _selectedCustomer != null && _selectedItem != null && !_submitting;
    final customerLabel = _selectedCustomer?.name ??
        (_prefillCustomerLoading
            ? 'Customer tanlanmoqda...'
            : l10n.selectCustomer);
    final source = widget.prefill;
    final pickerButtonStyle = FilledButton.styleFrom(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      disabledBackgroundColor: scheme.surfaceContainerLow,
      disabledForegroundColor: scheme.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(58),
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
    final qtyInputDecoration = InputDecoration(
      hintText: '0',
      suffixText: _selectedItem?.uom,
      filled: true,
      fillColor: scheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );

    return AppShell(
      title: l10n.customerIssueTitle,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      leading: NativeBackButtonSlot(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.customerIssueTitle,
                style: theme.textTheme.headlineMedium,
              ),
              if (_qrPrefillActive && source != null && source.hasSource) ...[
                const SizedBox(height: 12),
                _QrPrefillBanner(prefill: source),
              ],
              const SizedBox(height: 18),
              Text(l10n.itemLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: pickerButtonStyle,
                      onPressed: _submitting ? null : _pickItem,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedItem?.name ?? l10n.selectItem,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedItem != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Clear item',
                      onPressed: _submitting ? null : _clearSelectedItem,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(l10n.customerLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: pickerButtonStyle,
                      onPressed: _submitting ? null : _pickCustomer,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_prefillCustomerLoading)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Clear customer',
                      onPressed: _submitting ? null : _clearSelectedCustomer,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              if (_selectedCustomer != null &&
                  _selectedItem == null &&
                  _selectedCustomer!.phone.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: qtyInputDecoration,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: Text(
                    _submitting ? l10n.pinSaving : l10n.confirmTitle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrPrefillBanner extends StatelessWidget {
  const _QrPrefillBanner({required this.prefill});

  final WerkaCustomerIssuePrefillArgs prefill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sourceLabel = prefill.sourceStockEntryName.trim().isNotEmpty
        ? prefill.sourceStockEntryName.trim()
        : prefill.sourceBarcode.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR orqali to‘ldirildi',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sourceLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
