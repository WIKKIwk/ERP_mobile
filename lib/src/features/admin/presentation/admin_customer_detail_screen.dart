import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.adminCustomerDetail(widget.customerRef);
  }

  Future<void> _reload() async {
    final future = MobileApi.instance.adminCustomerDetail(widget.customerRef);
    setState(() => _future = future);
    await future;
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
                    Text(detail.ref, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Telefon', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      detail.phone.trim().isEmpty ? 'Kiritilmagan' : detail.phone,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
