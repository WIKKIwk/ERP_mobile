import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class AdminItemGroupItemsTab extends StatelessWidget {
  const AdminItemGroupItemsTab({
    super.key,
    required this.itemsFuture,
    required this.selectedGroup,
    required this.onSelectGroup,
  });

  final Future<List<SupplierItem>> itemsFuture;
  final String? selectedGroup;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupplierItem>>(
      future: itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Group itemlari yuklanmadi',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final grouped = _groupItems(snapshot.data ?? const []);
        final groups = grouped.keys.toList()
          ..sort((left, right) => left.toLowerCase().compareTo(
                right.toLowerCase(),
              ));
        final selected = _activeGroup(groups, selectedGroup);
        final items =
            selected == null ? const <SupplierItem>[] : grouped[selected]!;
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;

        return ListView(
          padding: EdgeInsets.fromLTRB(12, 16, 12, bottomPadding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Group itemlari',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Groupni tanlang, ichidagi mahsulotlar alohida ko‘rinadi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (groups.isEmpty)
              const _EmptyItems()
            else ...[
              _GroupSelector(
                groups: groups,
                grouped: grouped,
                selectedGroup: selected,
                onSelectGroup: onSelectGroup,
              ),
              const SizedBox(height: 14),
              _SelectedGroupItems(
                group: selected!,
                items: items,
              ),
            ],
          ],
        );
      },
    );
  }
}

Map<String, List<SupplierItem>> _groupItems(List<SupplierItem> items) {
  final grouped = <String, List<SupplierItem>>{};
  for (final item in items) {
    final group = item.itemGroup.trim();
    if (group.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(group, () => <SupplierItem>[]).add(item);
  }
  for (final entry in grouped.entries) {
    entry.value.sort((left, right) {
      final nameOrder = left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          );
      if (nameOrder != 0) {
        return nameOrder;
      }
      return left.code.toLowerCase().compareTo(right.code.toLowerCase());
    });
  }
  return grouped;
}

String? _activeGroup(List<String> groups, String? selectedGroup) {
  final selected = selectedGroup?.trim();
  if (selected != null && selected.isNotEmpty && groups.contains(selected)) {
    return selected;
  }
  if (groups.isEmpty) {
    return null;
  }
  return groups.first;
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.grouped,
    required this.selectedGroup,
    required this.onSelectGroup,
  });

  final List<String> groups;
  final Map<String, List<SupplierItem>> grouped;
  final String? selectedGroup;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final group in groups)
          ChoiceChip(
            label: Text('$group (${grouped[group]?.length ?? 0})'),
            selected: group == selectedGroup,
            onSelected: (_) => onSelectGroup(group),
          ),
      ],
    );
  }
}

class _SelectedGroupItems extends StatelessWidget {
  const _SelectedGroupItems({
    required this.group,
    required this.items,
  });

  final String group;
  final List<SupplierItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _CountBadge(count: items.length),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Bu groupda mahsulot yo‘q',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (int index = 0; index < items.length; index++) ...[
              _ItemTile(item: items[index]),
              if (index != items.length - 1)
                Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
            ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final SupplierItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = item.name.trim().isEmpty ? item.code : item.name;
    final subtitleParts = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if (item.uom.trim().isNotEmpty) item.uom.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.category_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count item',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Item topilmadi',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
