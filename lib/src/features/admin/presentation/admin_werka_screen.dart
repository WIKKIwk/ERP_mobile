import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminWerkaScreen extends StatefulWidget {
  const AdminWerkaScreen({super.key});

  @override
  State<AdminWerkaScreen> createState() => _AdminWerkaScreenState();
}

class _AdminWerkaScreenState extends State<AdminWerkaScreen> {
  late Future<AdminSettings> _future;
  final phone = TextEditingController();
  final name = TextEditingController();
  String werkaCode = '';
  bool saving = false;
  bool regenerating = false;
  bool hydrated = false;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.adminSettings();
  }

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    super.dispose();
  }

  void _fill(AdminSettings settings) {
    if (hydrated) {
      return;
    }
    phone.text = settings.werkaPhone;
    name.text = settings.werkaName;
    werkaCode = settings.werkaCode;
    hydrated = true;
  }

  Future<void> _save(AdminSettings current) async {
    setState(() => saving = true);
    try {
      final updated = await MobileApi.instance.updateAdminSettings(
        AdminSettings(
          erpUrl: current.erpUrl,
          erpApiKey: current.erpApiKey,
          erpApiSecret: current.erpApiSecret,
          defaultTargetWarehouse: current.defaultTargetWarehouse,
          defaultUom: current.defaultUom,
          werkaPhone: phone.text.trim(),
          werkaName: name.text.trim(),
          werkaCode: werkaCode,
          adminPhone: current.adminPhone,
          adminName: current.adminName,
        ),
      );
      setState(() {
        werkaCode = updated.werkaCode;
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() => regenerating = true);
    try {
      final updated = await MobileApi.instance.adminRegenerateWerkaCode();
      setState(() {
        werkaCode = updated.werkaCode;
      });
    } finally {
      if (mounted) {
        setState(() => regenerating = false);
      }
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: werkaCode));
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
      title: 'Werka',
      subtitle: 'Omborchi sozlamalari.',
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      child: FutureBuilder<AdminSettings>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: SoftCard(
                child: Text('Werka yuklanmadi: ${snapshot.error}'),
              ),
            );
          }
          final current = snapshot.data!;
          _fill(current);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.text.trim().isEmpty ? 'Werka' : name.text.trim(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(phone.text.trim(),
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 14),
                    Text('Code', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            werkaCode,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              werkaCode.trim().isEmpty ? null : _copyCode,
                          icon: const Icon(Icons.content_copy_outlined),
                        ),
                        IconButton(
                          onPressed: regenerating ? null : _regenerate,
                          icon: regenerating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Werka name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Werka phone'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : () => _save(current),
                  child: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
