import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../shared/models/app_models.dart';
import 'werka_unannounced_qty_screen.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaUnannouncedItemScreen extends StatefulWidget {
  const WerkaUnannouncedItemScreen({
    super.key,
    required this.supplier,
  });

  final SupplierDirectoryEntry supplier;

  @override
  State<WerkaUnannouncedItemScreen> createState() =>
      _WerkaUnannouncedItemScreenState();
}

class _WerkaUnannouncedItemScreenState extends State<WerkaUnannouncedItemScreen> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<SupplierItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.werkaSupplierItems(
      supplierRef: widget.supplier.ref,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Mol tanlang',
      subtitle: widget.supplier.name,
      leading: AppShellIconAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Mahsulot qidiring',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<SupplierItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: SoftCard(child: Text('${snapshot.error}')));
                }
                final query = _controller.text.trim().toLowerCase();
                final items = snapshot.data ?? const <SupplierItem>[];
                final filtered = items
                    .where((item) {
                      if (query.isEmpty) return true;
                      return item.name.toLowerCase().contains(query) ||
                          item.code.toLowerCase().contains(query);
                    })
                    .toList()
                  ..sort((a, b) {
                    int rank(SupplierItem item) {
                      final name = item.name.toLowerCase();
                      final code = item.code.toLowerCase();
                      if (name == query || code == query) return 0;
                      if (name.startsWith(query) || code.startsWith(query)) {
                        return 1;
                      }
                      return 2;
                    }

                    final rankCompare = rank(a).compareTo(rank(b));
                    if (rankCompare != 0) {
                      return rankCompare;
                    }
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                if (filtered.isEmpty) {
                  return const Center(
                    child: SoftCard(
                      child: Text('Mahsulot topilmadi.'),
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SoftCard(
                      padding: EdgeInsets.zero,
                      borderWidth: 1.45,
                      borderRadius: 20,
                      child: Column(
                        children: [
                          for (int index = 0; index < filtered.length; index++) ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.werkaUnannouncedQty,
                                arguments: WerkaUnannouncedQtyArgs(
                                  supplier: widget.supplier,
                                  item: filtered[index],
                                ),
                              ),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: index != filtered.length - 1
                                      ? Border(
                                          bottom: BorderSide(
                                            color: AppTheme.cardBorder(context),
                                            width: 1,
                                          ),
                                        )
                                      : null,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                child: Text(
                                  filtered[index].name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
