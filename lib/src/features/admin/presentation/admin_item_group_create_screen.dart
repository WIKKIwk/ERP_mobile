import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_item_group_parent_move_panel.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _itemGroupCornerRadius = 8;

class AdminItemGroupCreateScreen extends StatefulWidget {
  const AdminItemGroupCreateScreen({super.key});

  @override
  State<AdminItemGroupCreateScreen> createState() =>
      _AdminItemGroupCreateScreenState();
}

class _AdminItemGroupCreateScreenState
    extends State<AdminItemGroupCreateScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController parent = TextEditingController();
  late Future<List<String>> itemGroupsFuture;
  final List<String> optimisticParentGroups = [];
  bool saving = false;
  bool isGroup = true;
  bool parentMenuOpen = false;

  @override
  void initState() {
    super.initState();
    itemGroupsFuture = _loadParentGroups();
  }

  @override
  void dispose() {
    name.dispose();
    parent.dispose();
    super.dispose();
  }

  Future<List<String>> _loadParentGroups() async {
    final groups = await MobileApi.instance.adminItemGroups();
    return _mergeParentGroups(groups);
  }

  List<String> _mergeParentGroups(List<String> groups) {
    final seen = <String>{};
    final merged = <String>[];
    for (final group in [...groups, ...optimisticParentGroups]) {
      final trimmed = group.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      merged.add(trimmed);
    }
    return merged;
  }

  void _refreshParentGroups() {
    itemGroupsFuture = _loadParentGroups();
  }

  void _addOptimisticParentGroup(AdminItemGroup group) {
    if (!group.isGroup) {
      return;
    }
    optimisticParentGroups.add(group.name);
    if (group.itemGroupName != group.name) {
      optimisticParentGroups.add(group.itemGroupName);
    }
  }

  void _handleMoved(AdminItemGroup group) {
    setState(() {
      _addOptimisticParentGroup(group);
      _refreshParentGroups();
    });
  }

  void _toggleParentMenu(bool open) {
    if (parentMenuOpen == open) {
      return;
    }
    setState(() => parentMenuOpen = open);
  }

  void _selectParent(String group) {
    setState(() {
      parent.text = group;
      parentMenuOpen = false;
    });
  }

  void _syncParentSelection(List<String> groups) {
    final current = parent.text.trim();
    if (current.isNotEmpty && groups.contains(current)) {
      return;
    }
    final fallback = groups.contains('All Item Groups')
        ? 'All Item Groups'
        : (groups.isNotEmpty ? groups.first : '');
    if (fallback.isNotEmpty) {
      parent.text = fallback;
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final group = await MobileApi.instance.adminCreateItemGroup(
        name: name.text.trim(),
        parent: parent.text.trim(),
        isGroup: isGroup,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _addOptimisticParentGroup(group);
        _refreshParentGroups();
      });
      name.clear();
      showAdminTopNotice(context, 'Item Group yaratildi: ${group.name}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item Group yaratilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Item Group yaratish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Group yaratish'),
                Tab(text: 'Parent ko‘chirish'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CreateGroupTab(
                    name: name,
                    parent: parent,
                    itemGroupsFuture: itemGroupsFuture,
                    saving: saving,
                    isGroup: isGroup,
                    parentMenuOpen: parentMenuOpen,
                    onSyncParent: _syncParentSelection,
                    onToggleParentMenu: _toggleParentMenu,
                    onSelectParent: _selectParent,
                    onIsGroupChanged: saving
                        ? null
                        : (value) => setState(() => isGroup = value),
                    onSave: saving ? null : _save,
                  ),
                  _MoveParentTab(
                    itemGroupsFuture: itemGroupsFuture,
                    onMoved: _handleMoved,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupTab extends StatelessWidget {
  const _CreateGroupTab({
    required this.name,
    required this.parent,
    required this.itemGroupsFuture,
    required this.saving,
    required this.isGroup,
    required this.parentMenuOpen,
    required this.onSyncParent,
    required this.onToggleParentMenu,
    required this.onSelectParent,
    required this.onIsGroupChanged,
    required this.onSave,
  });

  final TextEditingController name;
  final TextEditingController parent;
  final Future<List<String>> itemGroupsFuture;
  final bool saving;
  final bool isGroup;
  final bool parentMenuOpen;
  final ValueChanged<List<String>> onSyncParent;
  final ValueChanged<bool> onToggleParentMenu;
  final ValueChanged<String> onSelectParent;
  final ValueChanged<bool>? onIsGroupChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      children: [
        TextField(
          controller: name,
          decoration: _itemGroupInputDecoration('Group nomi'),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: itemGroupsFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <String>[];
            if (snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError) {
              onSyncParent(groups);
            }
            final selectedParent =
                parent.text.trim().isEmpty ? null : parent.text.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Parent group',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                _TapBox(
                  onTap: snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError &&
                          !saving
                      ? () => onToggleParentMenu(!parentMenuOpen)
                      : null,
                  borderRadius: _itemGroupCornerRadius,
                  child: _SelectionBox(
                    label: selectedParent ?? 'Parent tanlang',
                    selected: selectedParent != null,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: parentMenuOpen
                      ? _ParentMenu(
                          groups: groups,
                          selectedParent: selectedParent,
                          saving: saving,
                          onSelect: onSelectParent,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isGroup,
          onChanged: onIsGroupChanged,
          title: const Text('Ichida yana guruh bo‘ladi'),
          subtitle: const Text(
            'Parent sifatida ishlatiladigan group uchun yoqing. '
            'Oxirgi/leaf group bo‘lsa o‘chiring.',
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSave,
            child: Text(saving ? 'Yaratilmoqda...' : 'Item Group yaratish'),
          ),
        ),
      ],
    );
  }
}

class _MoveParentTab extends StatelessWidget {
  const _MoveParentTab({
    required this.itemGroupsFuture,
    required this.onMoved,
  });

  final Future<List<String>> itemGroupsFuture;
  final ValueChanged<AdminItemGroup> onMoved;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: itemGroupsFuture,
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <String>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Item grouplar yuklanmadi',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          children: [
            AdminItemGroupParentMovePanel(
              groups: groups,
              onMoved: onMoved,
            ),
          ],
        );
      },
    );
  }
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(_itemGroupCornerRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.expand_more_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

InputDecoration _itemGroupInputDecoration(String label) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(_itemGroupCornerRadius)),
  );
  return const InputDecoration(
    labelText: '',
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  ).copyWith(labelText: label);
}

class _ParentMenu extends StatelessWidget {
  const _ParentMenu({
    required this.groups,
    required this.selectedParent,
    required this.saving,
    required this.onSelect,
  });

  final List<String> groups;
  final String? selectedParent;
  final bool saving;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < groups.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.6),
              ),
            Material(
              color: groups[index] == selectedParent
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.55)
                  : Colors.transparent,
              child: InkWell(
                onTap: saving ? null : () => onSelect(groups[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          groups[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                      if (groups[index] == selectedParent)
                        const Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TapBox extends StatelessWidget {
  const _TapBox({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
