import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late Future<AdminSettings> _future;
  final erpUrl = TextEditingController();
  final apiKey = TextEditingController();
  final apiSecret = TextEditingController();
  final warehouse = TextEditingController();
  final uom = TextEditingController();
  final werkaPhone = TextEditingController();
  final werkaName = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.adminSettings();
  }

  @override
  void dispose() {
    erpUrl.dispose();
    apiKey.dispose();
    apiSecret.dispose();
    warehouse.dispose();
    uom.dispose();
    werkaPhone.dispose();
    werkaName.dispose();
    super.dispose();
  }

  void _fill(AdminSettings settings) {
    erpUrl.text = settings.erpUrl;
    apiKey.text = settings.erpApiKey;
    apiSecret.text = settings.erpApiSecret;
    warehouse.text = settings.defaultTargetWarehouse;
    uom.text = settings.defaultUom;
    werkaPhone.text = settings.werkaPhone;
    werkaName.text = settings.werkaName;
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final current = await MobileApi.instance.adminSettings();
      final updated = await MobileApi.instance.updateAdminSettings(
        AdminSettings(
          erpUrl: erpUrl.text.trim(),
          erpApiKey: apiKey.text.trim(),
          erpApiSecret: apiSecret.text.trim(),
          defaultTargetWarehouse: warehouse.text.trim(),
          defaultUom: uom.text.trim(),
          werkaPhone: werkaPhone.text.trim(),
          werkaName: werkaName.text.trim(),
          werkaCode: current.werkaCode,
          adminPhone: current.adminPhone,
          adminName: current.adminName,
        ),
      );
      _fill(updated);
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      leading: AppShellIconAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      title: 'Admin Settings',
      subtitle: 'Minimal sozlamalar.',
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
                child: Text('Settings yuklanmadi: ${snapshot.error}'),
              ),
            );
          }

          final settings = snapshot.data!;
          _fill(settings);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              TextField(
                  controller: erpUrl,
                  decoration: const InputDecoration(labelText: 'ERP URL')),
              const SizedBox(height: 12),
              TextField(
                  controller: apiKey,
                  decoration: const InputDecoration(labelText: 'API Key')),
              const SizedBox(height: 12),
              TextField(
                  controller: apiSecret,
                  decoration: const InputDecoration(labelText: 'API Secret')),
              const SizedBox(height: 12),
              TextField(
                  controller: warehouse,
                  decoration:
                      const InputDecoration(labelText: 'Default Warehouse')),
              const SizedBox(height: 12),
              TextField(
                  controller: uom,
                  decoration: const InputDecoration(labelText: 'Default UOM')),
              const SizedBox(height: 12),
              TextField(
                  controller: werkaPhone,
                  decoration: const InputDecoration(labelText: 'Werka Phone')),
              const SizedBox(height: 12),
              TextField(
                  controller: werkaName,
                  decoration: const InputDecoration(labelText: 'Werka Name')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : _save,
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
