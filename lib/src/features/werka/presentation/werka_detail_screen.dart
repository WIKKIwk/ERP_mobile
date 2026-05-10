import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WerkaDetailScreen extends StatefulWidget {
  const WerkaDetailScreen({
    super.key,
    required this.record,
  });

  final DispatchRecord record;

  @override
  State<WerkaDetailScreen> createState() => _WerkaDetailScreenState();
}

class _WerkaDetailScreenState extends State<WerkaDetailScreen> {
  late final TextEditingController controller;
  late final TextEditingController returnedController;
  late final TextEditingController returnCommentController;
  bool showReturnFields = false;
  bool fullReturnMode = false;
  bool submitting = false;
  String? returnReason;
  String? _acceptedQtyBeforeFullReturn;

  static const List<String> _returnReasons = <String>[
    'Yaroqsiz',
    'Ko‘p berilgan',
    'Hujjatdagi mahsulot emas',
  ];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    returnedController = TextEditingController();
    returnCommentController = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    returnedController.dispose();
    returnCommentController.dispose();
    super.dispose();
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _toggleFullReturnMode() {
    setState(() {
      fullReturnMode = !fullReturnMode;
      if (fullReturnMode) {
        _acceptedQtyBeforeFullReturn = controller.text;
        controller.text = '0';
        showReturnFields = false;
        returnedController.clear();
        return;
      }
      controller.text = _acceptedQtyBeforeFullReturn ?? '';
      showReturnFields = false;
    });
  }

  Future<void> _submit() async {
    final double acceptedQty =
        fullReturnMode ? 0.0 : (double.tryParse(controller.text.trim()) ?? 0.0);
    if (acceptedQty <= 0) {
      if (fullReturnMode) {
        // full return mode handles zero accepted qty
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qabul qilingan miqdorni kiriting.')),
        );
        return;
      }
    }
    if (acceptedQty > widget.record.sentQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Qabul qilingan miqdor ${widget.record.sentQty.toStringAsFixed(2)} ${widget.record.uom} dan oshmasin.',
          ),
        ),
      );
      return;
    }

    final difference = widget.record.sentQty - acceptedQty;
    final returnComment = returnCommentController.text.trim();
    if (difference > 0.0001 && !showReturnFields) {
      setState(() {
        showReturnFields = true;
        returnedController.text = _formatQty(difference);
      });
      return;
    }

    final returnedText = returnedController.text.trim();
    double returnedQty = 0;
    if (returnedText.isNotEmpty) {
      returnedQty = double.tryParse(returnedText) ?? -1;
      if (returnedQty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qaytarilayotgan miqdor noto‘g‘ri.')),
        );
        return;
      }
      if (returnedQty - difference > 0.0001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Qaytarilayotgan miqdor farqdan oshmasin.'),
          ),
        );
        return;
      }
    }

    final bool? confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Tasdiqlash',
      message: 'Haqiqatan ham shu qabulni yakunlaysizmi?',
      cancelLabel: 'Yo‘q',
      confirmLabel: 'Ha',
    );
    if (confirmed != true) {
      return;
    }

    setState(() => submitting = true);
    try {
      final accepted = await MobileApi.instance.confirmReceipt(
        receiptID: widget.record.id,
        acceptedQty: acceptedQty,
        returnedQty: fullReturnMode ? widget.record.sentQty : returnedQty,
        returnReason: returnReason ?? '',
        returnComment: returnComment,
      );
      WerkaRuntimeStore.instance.recordTransition(
        before: widget.record,
        after: accepted,
      );
      RefreshHub.instance.emit('werka');
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .pushNamed(AppRoutes.werkaSuccess, arguments: accepted);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Qabul qilish bo‘lmadi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 168.0;
    final detailRows = <({String label, String value})>[
      (label: 'Supplier', value: widget.record.supplierName),
      (
        label: 'Mahsulot',
        value: widget.record.itemName,
      ),
      (
        label: 'Jo‘natilgan',
        value:
            '${widget.record.sentQty.toStringAsFixed(2)} ${widget.record.uom}',
      ),
    ];
    return AppShell(
      title: 'Qabul qilish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const WerkaDock(activeTab: WerkaDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 18, 24, bottomPadding),
        children: [
          Text(
            widget.record.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              height: 1.08,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 26),
          for (int index = 0; index < detailRows.length; index++) ...[
            _WerkaDetailInfoRow(
              label: detailRows[index].label,
              value: detailRows[index].value,
            ),
            if (index != detailRows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
          const SizedBox(height: 34),
          Text(
            'Qabul qilingan',
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _QuantityFieldRow(
            controller: controller,
            readOnly: fullReturnMode,
            unit: widget.record.uom,
            textTheme: textTheme,
            scheme: scheme,
            hintText: '',
          ),
          const SizedBox(height: 24),
          if (fullReturnMode) ...[
            Text(
              'Sabab',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ..._returnReasons.map(
              (reason) => InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => returnReason = reason);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        returnReason == reason
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: returnCommentController,
              minLines: 3,
              maxLines: 5,
              decoration: _detailInputDecoration(
                scheme: scheme,
                labelText: 'Izoh',
                hintText: 'Ixtiyoriy izoh',
              ),
            ),
          ] else if (showReturnFields) ...[
            const SizedBox(height: 28),
            _QuantityFieldRow(
              controller: returnedController,
              readOnly: false,
              unit: widget.record.uom,
              textTheme: textTheme,
              scheme: scheme,
              hintText: '',
              labelText: 'Qaytarilayotgan',
            ),
            const SizedBox(height: 18),
            Text(
              'Sabab',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ..._returnReasons.map(
              (reason) => InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => returnReason = reason);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        returnReason == reason
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: fullReturnMode || showReturnFields ? 28 : 0),
          _ReceiptActionGroup(
            fullReturnMode: fullReturnMode,
            submitting: submitting,
            scheme: scheme,
            textTheme: textTheme,
            onReturnPressed: _toggleFullReturnMode,
            onSubmitPressed: _submit,
          ),
        ],
      ),
    );
  }

  InputDecoration _detailInputDecoration({
    required ColorScheme scheme,
    String? labelText,
    required String hintText,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.fromLTRB(18, 14, 18, 14),
  }) {
    final borderRadius = BorderRadius.circular(14);
    final enabledBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      contentPadding: contentPadding,
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    );
  }
}

class _ReceiptActionGroup extends StatelessWidget {
  const _ReceiptActionGroup({
    required this.fullReturnMode,
    required this.submitting,
    required this.scheme,
    required this.textTheme,
    required this.onReturnPressed,
    required this.onSubmitPressed,
  });

  final bool fullReturnMode;
  final bool submitting;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onReturnPressed;
  final VoidCallback onSubmitPressed;

  @override
  Widget build(BuildContext context) {
    final labelStyle = textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: _ReceiptActionSegment(
              label: fullReturnMode
                  ? 'Qaytarish tanlangan'
                  : 'Hammasini qaytarish',
              backgroundColor: fullReturnMode
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHigh,
              foregroundColor: fullReturnMode
                  ? scheme.onSecondaryContainer
                  : scheme.onSurface,
              borderColor: scheme.outlineVariant,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
                right: Radius.circular(6),
              ),
              textStyle: labelStyle,
              onTap: submitting ? null : onReturnPressed,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 5,
            child: _ReceiptActionSegment(
              label: submitting ? 'Saqlanmoqda...' : 'Yakunlash',
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              borderColor: scheme.primary,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(6),
                right: Radius.circular(18),
              ),
              textStyle: labelStyle,
              onTap: submitting ? null : onSubmitPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptActionSegment extends StatelessWidget {
  const _ReceiptActionSegment({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.borderRadius,
    required this.onTap,
    this.textStyle,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: onTap == null
                ? backgroundColor.withValues(alpha: 0.56)
                : backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textStyle?.copyWith(color: foregroundColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityFieldRow extends StatelessWidget {
  const _QuantityFieldRow({
    required this.controller,
    required this.unit,
    required this.textTheme,
    required this.scheme,
    required this.hintText,
    this.readOnly = false,
    this.labelText,
  });

  final TextEditingController controller;
  final String unit;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final String hintText;
  final bool readOnly;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    final fieldBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 176,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const _MaxNumericValueFormatter(100000),
            ],
            textAlign: TextAlign.right,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
            readOnly: readOnly,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              border: fieldBorder,
              enabledBorder: fieldBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(color: scheme.primary, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            unit,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 18,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MaxNumericValueFormatter extends TextInputFormatter {
  const _MaxNumericValueFormatter(this.maxValue);

  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final value = int.tryParse(text);
    if (value == null || value > maxValue) {
      return oldValue;
    }
    return newValue;
  }
}

class _WerkaDetailInfoRow extends StatelessWidget {
  const _WerkaDetailInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
