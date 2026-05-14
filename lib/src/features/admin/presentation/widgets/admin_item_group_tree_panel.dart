import '../../models/admin_item_group_tree_entry.dart';
import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreePanel extends StatefulWidget {
  const AdminItemGroupTreePanel({
    super.key,
    required this.entries,
    required this.items,
  });

  final List<AdminItemGroupTreeEntry> entries;
  final List<SupplierItem> items;

  @override
  State<AdminItemGroupTreePanel> createState() =>
      _AdminItemGroupTreePanelState();
}

class _AdminItemGroupTreePanelState extends State<AdminItemGroupTreePanel> {
  final Set<String> _expandedNames = {};

  void _toggle(String name) {
    setState(() {
      if (!_expandedNames.add(name)) {
        _expandedNames.remove(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _buildNodes(widget.entries);
    final itemsByGroup = _groupItems(widget.items);
    if (nodes.isEmpty) {
      return const _EmptyTree();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Item Group tree',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Parent va child guruhlarni ERPNext tree tartibida ko‘rsatadi.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        for (int index = 0; index < nodes.length; index++) ...[
          _TreeNodeCard(
            node: nodes[index],
            depth: 0,
            itemsByGroup: itemsByGroup,
            expandedNames: _expandedNames,
            onToggle: _toggle,
          ),
          if (index != nodes.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TreeNode {
  _TreeNode(this.entry);

  final AdminItemGroupTreeEntry entry;
  final List<_TreeNode> children = [];
}

List<_TreeNode> _buildNodes(List<AdminItemGroupTreeEntry> entries) {
  final byName = <String, _TreeNode>{};
  for (final entry in entries) {
    final name = entry.name.trim();
    if (name.isEmpty || byName.containsKey(name)) {
      continue;
    }
    byName[name] = _TreeNode(entry);
  }

  final roots = <_TreeNode>[];
  for (final node in byName.values) {
    final parent = node.entry.parentItemGroup.trim();
    final parentNode = byName[parent];
    if (parent.isEmpty || parent == node.entry.name || parentNode == null) {
      roots.add(node);
    } else {
      parentNode.children.add(node);
    }
  }
  return roots;
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

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.node,
    required this.depth,
    required this.itemsByGroup,
    required this.expandedNames,
    required this.onToggle,
  });

  final _TreeNode node;
  final int depth;
  final Map<String, List<SupplierItem>> itemsByGroup;
  final Set<String> expandedNames;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
    final items = _itemsForNode(node, itemsByGroup);
    final hasItems = items.isNotEmpty;
    final hasContent = hasChildren || hasItems;
    final isExpanded = expandedNames.contains(node.entry.name);
    final title = node.entry.itemGroupName.isEmpty
        ? node.entry.name
        : node.entry.itemGroupName;

    return Container(
      decoration: BoxDecoration(
        color: depth == 0
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: depth == 0
              ? colorScheme.outlineVariant
              : colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasContent ? () => onToggle(node.entry.name) : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hasContent
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasChildren
                            ? Icons.folder_rounded
                            : hasItems
                                ? Icons.inventory_2_rounded
                                : Icons.label_outline_rounded,
                        size: 20,
                        color: hasContent
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (hasChildren)
                      _TreeBadge(
                        label: '${node.children.length} child',
                        filled: true,
                      ),
                    if (hasChildren && hasItems) const SizedBox(width: 6),
                    if (hasItems)
                      _TreeBadge(
                        label: '${items.length} item',
                        filled: true,
                      ),
                    if (!hasContent)
                      const _TreeBadge(label: 'leaf', filled: false),
                    if (hasContent) ...[
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 180),
                        turns: isExpanded ? 0.25 : 0,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: hasContent && isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, left: 17),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.42,
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(
                            children: [
                              if (hasChildren)
                                for (int index = 0;
                                    index < node.children.length;
                                    index++) ...[
                                  _TreeNodeCard(
                                    node: node.children[index],
                                    depth: depth + 1,
                                    itemsByGroup: itemsByGroup,
                                    expandedNames: expandedNames,
                                    onToggle: onToggle,
                                  ),
                                  if (index != node.children.length - 1)
                                    const SizedBox(height: 8),
                                ],
                              if (hasChildren && hasItems)
                                const SizedBox(height: 8),
                              if (hasItems) _GroupItemsList(items: items),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<SupplierItem> _itemsForNode(
  _TreeNode node,
  Map<String, List<SupplierItem>> itemsByGroup,
) {
  final seenCodes = <String>{};
  final result = <SupplierItem>[];
  for (final key in [node.entry.name, node.entry.itemGroupName]) {
    final group = key.trim();
    if (group.isEmpty) {
      continue;
    }
    final items = itemsByGroup[group];
    if (items == null) {
      continue;
    }
    for (final item in items) {
      if (seenCodes.add(item.code)) {
        result.add(item);
      }
    }
  }
  return result;
}

class _GroupItemsList extends StatelessWidget {
  const _GroupItemsList({required this.items});

  final List<SupplierItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Items',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _TreeBadge(label: '${items.length}', filled: false),
              ],
            ),
          ),
          for (int index = 0; index < items.length; index++) ...[
            _GroupItemTile(item: items[index]),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 10,
                endIndent: 10,
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupItemTile extends StatelessWidget {
  const _GroupItemTile({required this.item});

  final SupplierItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if (item.uom.trim().isNotEmpty) item.uom.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.category_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.trim().isEmpty ? item.code : item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _TreeBadge extends StatelessWidget {
  const _TreeBadge({
    required this.label,
    required this.filled,
  });

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: filled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Tree bo‘sh',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
