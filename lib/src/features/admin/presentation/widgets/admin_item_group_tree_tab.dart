import '../../models/admin_item_group_tree_entry.dart';
import '../../../shared/models/app_models.dart';
import 'admin_item_group_tree_panel.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreeTab extends StatelessWidget {
  const AdminItemGroupTreeTab({
    super.key,
    required this.itemGroupTreeFuture,
    required this.itemGroupItemsFuture,
  });

  final Future<List<AdminItemGroupTreeEntry>> itemGroupTreeFuture;
  final Future<List<SupplierItem>> itemGroupItemsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ItemGroupTreePayload>(
      future: Future.wait<Object>([
        itemGroupTreeFuture,
        itemGroupItemsFuture,
      ]).then(
        (values) => _ItemGroupTreePayload(
          groups: values[0] as List<AdminItemGroupTreeEntry>,
          items: values[1] as List<SupplierItem>,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Item group tree yuklanmadi',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data ??
            const _ItemGroupTreePayload(
              groups: <AdminItemGroupTreeEntry>[],
              items: <SupplierItem>[],
            );
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
        return ListView(
          padding: EdgeInsets.fromLTRB(12, 16, 12, bottomPadding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AdminItemGroupTreePanel(
              entries: data.groups,
              items: data.items,
            ),
          ],
        );
      },
    );
  }
}

class _ItemGroupTreePayload {
  const _ItemGroupTreePayload({
    required this.groups,
    required this.items,
  });

  final List<AdminItemGroupTreeEntry> groups;
  final List<SupplierItem> items;
}
