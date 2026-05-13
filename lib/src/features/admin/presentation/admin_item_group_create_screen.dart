import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/common_widgets.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';

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
  final Future<List<String>> itemGroupsFuture =
      MobileApi.instance.adminItemGroups();
  bool saving = false;
  bool isGroup = true;
  bool parentMenuOpen = false;
  AdminItemGroup? createdGroup;

  @override
  void dispose() {
    name.dispose();
    parent.dispose();
    super.dispose();
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
        createdGroup = group;
      });
      name.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item Group yaratildi: ${group.name}')),
      );
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        children: [
          if (createdGroup != null) ...[
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yaratildi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${createdGroup!.itemGroupName} • parent: '
                    '${createdGroup!.parentItemGroup}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Group nomi'),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: itemGroupsFuture,
            builder: (context, snapshot) {
              final groups = snapshot.data ?? const <String>[];
              if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError) {
                _syncParentSelection(groups);
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
                        ? () => _toggleParentMenu(!parentMenuOpen)
                        : null,
                    borderRadius: 14,
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
                            onSelect: _selectParent,
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
            onChanged:
                saving ? null : (value) => setState(() => isGroup = value),
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
              onPressed: saving ? null : _save,
              child: Text(
                saving ? 'Yaratilmoqda...' : 'Item Group yaratish',
              ),
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(14),
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
