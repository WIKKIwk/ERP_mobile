import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_item_group_selected_items.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class AdminItemCreateScreen extends StatefulWidget {
  const AdminItemCreateScreen({super.key});

  @override
  State<AdminItemCreateScreen> createState() => _AdminItemCreateScreenState();
}

class _AdminItemCreateScreenState extends State<AdminItemCreateScreen> {
  final TextEditingController code = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController itemGroup = TextEditingController();
  final TextEditingController uom = TextEditingController(text: 'Kg');
  late final Future<List<String>> itemGroupsFuture;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    itemGroupsFuture = _loadItemGroups();
    _hydrateDefaultUom();
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    itemGroup.dispose();
    uom.dispose();
    super.dispose();
  }

  Future<void> _hydrateDefaultUom() async {
    try {
      final settings = await MobileApi.instance.adminSettings();
      if (!mounted) {
        return;
      }
      final currentValue = uom.text.trim();
      if (currentValue.isEmpty || currentValue == 'Kg') {
        final defaultUom = settings.defaultUom.trim();
        uom.text = defaultUom.isEmpty ? 'Kg' : defaultUom;
      }
    } catch (_) {}
  }

  Future<List<String>> _loadItemGroups() async {
    try {
      final tree = await MobileApi.instance.adminItemGroupTree();
      final ordered = orderAdminItemGroupsByParent(tree);
      if (ordered.isNotEmpty) {
        return ordered;
      }
    } catch (_) {}
    return MobileApi.instance.adminItemGroups();
  }

  void _syncItemGroupSelection(List<String> groups) {
    final current = itemGroup.text.trim();
    if (current.isNotEmpty && groups.contains(current)) {
      return;
    }
    final fallback = groups.contains('All Item Groups')
        ? 'All Item Groups'
        : (groups.isNotEmpty ? groups.first : '');
    if (fallback.isNotEmpty) {
      itemGroup.text = fallback;
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      if (await _itemAlreadyExists()) {
        if (mounted) {
          showAdminTopNotice(context, 'Item allaqachon yaratilgan');
        }
        return;
      }
      final item = await MobileApi.instance.adminCreateItem(
        code: code.text.trim(),
        name: name.text.trim(),
        uom: uom.text.trim(),
        itemGroup: itemGroup.text.trim(),
      );
      if (!mounted) {
        return;
      }
      code.clear();
      name.clear();
      if (!mounted) {
        return;
      }
      showAdminTopNotice(context, 'Item yaratildi: ${item.code}');
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(context, 'Item yaratilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<bool> _itemAlreadyExists() async {
    final itemCode = code.text.trim();
    final itemName = name.text.trim();
    final query = itemCode.isNotEmpty ? itemCode : itemName;
    if (query.isEmpty) {
      return false;
    }
    final items = await MobileApi.instance.adminItemsPage(
      query: query,
      limit: 5,
    );
    final normalizedCode = itemCode.toLowerCase();
    final normalizedName = itemName.toLowerCase();
    return items.any((item) {
      final codeMatches = normalizedCode.isNotEmpty &&
          item.code.trim().toLowerCase() == normalizedCode;
      final nameMatches = normalizedName.isNotEmpty &&
          item.name.trim().toLowerCase() == normalizedName;
      return codeMatches || nameMatches;
    });
  }

  Future<void> _openItemGroupPicker(List<String> groups) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<String>(
          title: 'Item group tanlang',
          hintText: 'Item group qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? groups
                : groups.where((group) {
                    return group.toLowerCase().contains(normalizedQuery);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (group) => group,
          itemSubtitle: (_) => '',
          onSelected: (group) => Navigator.of(context).pop(group),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      itemGroup.text = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Item qo‘shish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Item yaratish'),
                Tab(text: 'Itemlar'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CreateItemTab(
                    code: code,
                    name: name,
                    itemGroup: itemGroup,
                    uom: uom,
                    itemGroupsFuture: itemGroupsFuture,
                    saving: saving,
                    onSyncItemGroup: _syncItemGroupSelection,
                    onOpenItemGroupPicker: _openItemGroupPicker,
                    onSave: saving ? null : _save,
                  ),
                  AdminItemsListTab(
                    loadItemsPage: ({
                      required query,
                      required limit,
                      required offset,
                    }) =>
                        MobileApi.instance.adminItemsPage(
                      query: query,
                      limit: limit,
                      offset: offset,
                    ),
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

class _CreateItemTab extends StatelessWidget {
  const _CreateItemTab({
    required this.code,
    required this.name,
    required this.itemGroup,
    required this.uom,
    required this.itemGroupsFuture,
    required this.saving,
    required this.onSyncItemGroup,
    required this.onOpenItemGroupPicker,
    required this.onSave,
  });

  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController itemGroup;
  final TextEditingController uom;
  final Future<List<String>> itemGroupsFuture;
  final bool saving;
  final ValueChanged<List<String>> onSyncItemGroup;
  final ValueChanged<List<String>> onOpenItemGroupPicker;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      children: [
        TextField(
          controller: code,
          decoration: const InputDecoration(labelText: 'Item code'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Item name'),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: itemGroupsFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <String>[];
            if (snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError) {
              onSyncItemGroup(groups);
            }
            final selectedGroup =
                itemGroup.text.trim().isEmpty ? null : itemGroup.text.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Item group',
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
                      ? () => onOpenItemGroupPicker(groups)
                      : null,
                  borderRadius: 14,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedGroup ?? 'Group tanlang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: selectedGroup == null
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
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
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        TextField(
          controller: uom,
          decoration: const InputDecoration(labelText: 'UOM'),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSave,
            child: Text(saving ? 'Yaratilmoqda...' : 'Item yaratish'),
          ),
        ),
      ],
    );
  }
}

typedef AdminItemsPageLoader = Future<List<SupplierItem>> Function({
  required String query,
  required int limit,
  required int offset,
});

class AdminItemsListTab extends StatefulWidget {
  const AdminItemsListTab({
    super.key,
    required this.loadItemsPage,
  });

  final AdminItemsPageLoader loadItemsPage;

  @override
  State<AdminItemsListTab> createState() => _AdminItemsListTabState();
}

class _AdminItemsListTabState extends State<AdminItemsListTab> {
  static const int _pageSize = 80;
  static const double _loadMoreExtent = 420;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<SupplierItem> _items = const <SupplierItem>[];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _query = value.trim();
      _loadFirstPage();
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _initialLoading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter <= _loadMoreExtent) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _items = const <SupplierItem>[];
      _initialLoading = true;
      _loadingMore = false;
      _hasMore = false;
      _error = null;
    });
    await _fetchPage(offset: 0, replace: true);
  }

  Future<void> _loadNextPage() async {
    if (_initialLoading || _loadingMore || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    await _fetchPage(offset: _items.length, replace: false);
  }

  Future<void> _fetchPage({
    required int offset,
    required bool replace,
  }) async {
    final query = _query;
    try {
      final page = await widget.loadItemsPage(
        query: query,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _items = replace ? page : <SupplierItem>[..._items, ...page];
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = page.length == _pageSize;
        _error = null;
      });
    } catch (error) {
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SearchBar(
            controller: _searchController,
            hintText: 'Mahsulot qidirish',
            leading: const Icon(Icons.search_rounded),
            onChanged: _handleSearchChanged,
          ),
          const SizedBox(height: 12),
          _AdminItemsListBody(
            items: _items,
            initialLoading: _initialLoading,
            loadingMore: _loadingMore,
            hasMore: _hasMore,
            error: _error,
            onRetry: _loadFirstPage,
          ),
        ],
      ),
    );
  }
}

class _AdminItemsListBody extends StatelessWidget {
  const _AdminItemsListBody({
    required this.items,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final List<SupplierItem> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (initialLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null && items.isEmpty) {
      return _ItemListNotice(
        text: 'Itemlar yuklanmadi',
        actionText: 'Qayta urinish',
        onAction: onRetry,
      );
    }
    return AdminItemGroupSelectedItems(
      group: 'Hamma itemlar',
      items: items,
      loadingMore: loadingMore,
      hasMore: hasMore,
      pageError: error,
      onRetry: onRetry,
    );
  }
}

class _ItemListNotice extends StatelessWidget {
  const _ItemListNotice({
    required this.text,
    this.actionText,
    this.onAction,
  });

  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> orderAdminItemGroupsByParent(
  List<AdminItemGroupTreeEntry> entries,
) {
  final names = <String>{};
  final parentByName = <String, String>{};
  final indexByName = <String, int>{};
  final childrenByParent = <String, List<String>>{};

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final name = (entry.itemGroupName.trim().isNotEmpty
            ? entry.itemGroupName
            : entry.name)
        .trim();
    if (name.isEmpty || !names.add(name)) {
      continue;
    }
    indexByName[name] = index;
    final parent = entry.parentItemGroup.trim();
    parentByName[name] = parent;
    if (parent.isNotEmpty && parent != name) {
      childrenByParent.putIfAbsent(parent, () => <String>[]).add(name);
    }
  }

  for (final children in childrenByParent.values) {
    children.sort((left, right) {
      return (indexByName[left] ?? 1 << 20)
          .compareTo(indexByName[right] ?? 1 << 20);
    });
  }

  final ordered = <String>[];
  final visited = <String>{};
  final queue = <String>[];

  void enqueue(String name) {
    if (!names.contains(name) || !visited.add(name)) {
      return;
    }
    queue.add(name);
  }

  if (names.contains('All Item Groups')) {
    enqueue('All Item Groups');
  }

  final roots = names.where((name) {
    final parent = parentByName[name] ?? '';
    return parent.isEmpty || parent == name || !names.contains(parent);
  }).toList()
    ..sort((left, right) {
      return (indexByName[left] ?? 1 << 20)
          .compareTo(indexByName[right] ?? 1 << 20);
    });

  for (final root in roots) {
    enqueue(root);
  }

  for (var index = 0; index < queue.length; index++) {
    final name = queue[index];
    ordered.add(name);
    for (final child in childrenByParent[name] ?? const <String>[]) {
      enqueue(child);
    }
  }

  for (final name in names) {
    enqueue(name);
  }
  for (var index = ordered.length; index < queue.length; index++) {
    ordered.add(queue[index]);
  }
  return ordered;
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
