import '../../models/admin_item_group_tree_entry.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreePanel extends StatelessWidget {
  const AdminItemGroupTreePanel({
    super.key,
    required this.entries,
  });

  final List<AdminItemGroupTreeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final nodes = _buildNodes(entries);
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
          _TreeNodeCard(node: nodes[index], depth: 0),
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

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.node,
    required this.depth,
  });

  final _TreeNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: hasChildren
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasChildren
                        ? Icons.account_tree_rounded
                        : Icons.label_outline_rounded,
                    size: 20,
                    color: hasChildren
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
                _TreeBadge(
                  label: hasChildren ? '${node.children.length} child' : 'leaf',
                  filled: hasChildren,
                ),
              ],
            ),
            if (hasChildren) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 2,
                    height: (node.children.length * 58).toDouble(),
                    constraints: const BoxConstraints(minHeight: 34),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        for (int index = 0;
                            index < node.children.length;
                            index++) ...[
                          _TreeNodeCard(
                            node: node.children[index],
                            depth: depth + 1,
                          ),
                          if (index != node.children.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
