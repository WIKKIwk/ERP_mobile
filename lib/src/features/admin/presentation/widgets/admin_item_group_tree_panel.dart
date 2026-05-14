import '../../models/admin_item_group_tree_entry.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreePanel extends StatefulWidget {
  const AdminItemGroupTreePanel({
    super.key,
    required this.entries,
    required this.onShowItems,
  });

  final List<AdminItemGroupTreeEntry> entries;
  final ValueChanged<String> onShowItems;

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
            expandedNames: _expandedNames,
            onToggle: _toggle,
            onShowItems: widget.onShowItems,
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

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.node,
    required this.depth,
    required this.expandedNames,
    required this.onToggle,
    required this.onShowItems,
  });

  final _TreeNode node;
  final int depth;
  final Set<String> expandedNames;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onShowItems;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
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
              onTap: hasChildren ? () => onToggle(node.entry.name) : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
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
                            ? Icons.folder_rounded
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
                    TextButton(
                      onPressed: () => onShowItems(node.entry.name),
                      child: const Text('Show'),
                    ),
                    if (hasChildren)
                      _TreeBadge(
                        label: '${node.children.length} child',
                        filled: true,
                      ),
                    if (!hasChildren)
                      const _TreeBadge(label: 'leaf', filled: false),
                    if (hasChildren) ...[
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
                child: hasChildren && isExpanded
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
                              for (int index = 0;
                                  index < node.children.length;
                                  index++) ...[
                                _TreeNodeCard(
                                  node: node.children[index],
                                  depth: depth + 1,
                                  expandedNames: expandedNames,
                                  onToggle: onToggle,
                                  onShowItems: onShowItems,
                                ),
                                if (index != node.children.length - 1)
                                  const SizedBox(height: 8),
                              ],
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
