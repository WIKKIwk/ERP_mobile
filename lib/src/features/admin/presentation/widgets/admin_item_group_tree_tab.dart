import '../../models/admin_item_group_tree_entry.dart';
import 'admin_item_group_tree_panel.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreeTab extends StatelessWidget {
  const AdminItemGroupTreeTab({
    super.key,
    required this.itemGroupTreeFuture,
    required this.onShowItems,
  });

  final Future<List<AdminItemGroupTreeEntry>> itemGroupTreeFuture;
  final ValueChanged<String> onShowItems;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminItemGroupTreeEntry>>(
      future: itemGroupTreeFuture,
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
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
        return ListView(
          padding: EdgeInsets.fromLTRB(12, 16, 12, bottomPadding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AdminItemGroupTreePanel(
              entries: snapshot.data ?? const [],
              onShowItems: (group) {
                onShowItems(group);
                DefaultTabController.of(context).animateTo(3);
              },
            ),
          ],
        );
      },
    );
  }
}
