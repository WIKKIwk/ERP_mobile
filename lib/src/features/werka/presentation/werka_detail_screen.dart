import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

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

  static const List<String> _returnReasons = <String>[
    'Yaroqsiz',
    'Ko‘p berilgan',
    'Hujjatdagi mahsulot emas',
  ];

  @override
  void initState() {
    super.initState();
    controller =
        TextEditingController(text: widget.record.sentQty.toStringAsFixed(0));
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

  Future<void> _submit() async {
    final double acceptedQty = fullReturnMode
        ? 0.0
        : (double.tryParse(controller.text.trim()) ?? 0.0);
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
      if (returnedQty-difference > 0.0001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Qaytarilayotgan miqdor farqdan oshmasin.'),
          ),
        );
        return;
      }
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
    final textTheme = Theme.of(context).textTheme;
    return AppShell(
      title: 'Qabul qilish',
      subtitle: '',
      bottom: const WerkaDock(activeTab: null),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'Supplier: '),
                TextSpan(
                  text: widget.record.supplierName,
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'Mahsulot: '),
                TextSpan(
                  text: widget.record.itemCode,
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'Jo‘natilgan: '),
                TextSpan(
                  text:
                      '${widget.record.sentQty.toStringAsFixed(2)} ${widget.record.uom}',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: textTheme.displaySmall,
            readOnly: fullReturnMode,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: widget.record.uom,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  fullReturnMode = !fullReturnMode;
                  if (fullReturnMode) {
                    controller.text = '0';
                    showReturnFields = true;
                    returnedController.clear();
                  } else {
                    controller.text =
                        widget.record.sentQty.toStringAsFixed(0);
                    returnCommentController.clear();
                  }
                });
              },
              child: Text(
                fullReturnMode
                    ? 'Hammasini qaytarish tanlangan'
                    : 'Hammasini qaytarish',
              ),
            ),
          ),
          if (fullReturnMode) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sabab',
                style: textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            TextField(
              controller: returnCommentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                hintText: 'Ixtiyoriy izoh',
              ),
            ),
          ] else if (showReturnFields) ...[
            const SizedBox(height: 18),
            TextField(
              controller: returnedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: textTheme.displaySmall,
              decoration: InputDecoration(
                labelText: 'Qaytarilayotgan',
                hintText: '0',
                suffixText: widget.record.uom,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sabab',
                style: textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : _submit,
              child: Text(
                submitting ? 'Saqlanmoqda...' : 'Yakunlash',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
