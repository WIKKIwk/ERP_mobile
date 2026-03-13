import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({
    super.key,
    required this.customerRef,
  });

  final String customerRef;

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  late Future<AdminCustomerDetail> _future;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  int _retryAfterSec = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<AdminCustomerDetail> _loadDetail() async {
    final detail =
        await MobileApi.instance.adminCustomerDetail(widget.customerRef);
    _setRetryAfter(detail.codeRetryAfterSec);
    return detail;
  }

  void _setRetryAfter(int seconds) {
    _retryTimer?.cancel();
    _retryAfterSec = seconds > 0 ? seconds : 0;
    if (_retryAfterSec <= 0) {
      return;
    }
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _retryAfterSec <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _retryAfterSec = 0);
        }
        return;
      }
      setState(() => _retryAfterSec -= 1);
    });
  }

  Future<void> _reload() async {
    final future = _loadDetail();
    setState(() => _future = future);
    await future;
  }

  Future<void> _addPhone(AdminCustomerDetail detail) async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Telefon raqam qo‘shish'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '+998901234567',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Saqlash'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (phone == null || phone.trim().isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updated = await MobileApi.instance.adminUpdateCustomerPhone(
        ref: detail.ref,
        phone: phone,
      );
      setState(() {
        _future = Future<AdminCustomerDetail>.value(updated);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Telefon saqlanmadi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingPhone = false);
      }
    }
  }

  Future<void> _regenerateCode() async {
    setState(() => _regeneratingCode = true);
    try {
      final updated = await MobileApi.instance
          .adminRegenerateCustomerCode(widget.customerRef);
      _setRetryAfter(updated.codeRetryAfterSec);
      setState(() {
        _future = Future<AdminCustomerDetail>.value(updated);
      });
    } finally {
      if (mounted) {
        setState(() => _regeneratingCode = false);
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code nusxalandi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      leading: AppShellIconAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      title: 'Customer',
      subtitle: '',
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      child: FutureBuilder<AdminCustomerDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: SoftCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Customer detail yuklanmadi: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final hasPhone = detail.phone.trim().isNotEmpty;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    Text('Ref', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      detail.ref,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Telefon',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _savingPhone ? null : () => _addPhone(detail),
                          child: Text(hasPhone ? 'Yangilash' : 'Qo‘shish'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPhone ? detail.phone : 'Kiritilmagan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Code', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.actionSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              detail.code.trim().isEmpty
                                  ? 'Hali generatsiya qilinmagan'
                                  : detail.code,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (detail.code.trim().isNotEmpty)
                            IconButton(
                              onPressed: () => _copyCode(detail.code),
                              icon: const Icon(Icons.copy_rounded),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _regeneratingCode || _retryAfterSec > 0
                            ? null
                            : _regenerateCode,
                        child: Text(
                          _regeneratingCode
                              ? 'Generatsiya qilinmoqda...'
                              : 'Code generatsiya qilish',
                        ),
                      ),
                    ),
                    if (_retryAfterSec > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Keyingi code uchun $_retryAfterSec soniyadan keyin qayta urining.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
