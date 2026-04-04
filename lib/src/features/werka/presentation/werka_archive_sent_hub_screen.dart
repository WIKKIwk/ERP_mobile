import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_retry_state.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'werka_archive_list_screen.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaArchiveSentHubScreen extends StatefulWidget {
  const WerkaArchiveSentHubScreen({
    super.key,
    this.archiveLoader,
  });

  final Future<WerkaArchiveResponse> Function({
    required WerkaArchiveKind kind,
    required WerkaArchivePeriod period,
    DateTime? from,
    DateTime? to,
  })? archiveLoader;

  @override
  State<WerkaArchiveSentHubScreen> createState() =>
      _WerkaArchiveSentHubScreenState();
}

class _WerkaArchiveSentHubScreenState extends State<WerkaArchiveSentHubScreen> {
  WerkaArchivePeriod _period = WerkaArchivePeriod.daily;
  late DateTime _displayMonth;
  late DateTime _selectedDate;
  late int _displayYear;
  late int _startYear;

  bool _loading = true;
  Object? _error;
  Set<int> _activeDays = <int>{};
  Set<int> _activeMonths = <int>{};
  Set<int> _activeYears = <int>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateUtils.dateOnly(now);
    _displayYear = now.year;
    _startYear = now.year - 5;
    _loadCurrent();
  }

  Future<WerkaArchiveResponse> _archive({
    required WerkaArchivePeriod period,
    DateTime? from,
    DateTime? to,
  }) {
    final loader = widget.archiveLoader;
    if (loader != null) {
      return loader(
        kind: WerkaArchiveKind.sent,
        period: period,
        from: from,
        to: to,
      );
    }
    return MobileApi.instance.werkaArchive(
      kind: WerkaArchiveKind.sent,
      period: period,
      from: from,
      to: to,
    );
  }

  Future<void> _loadCurrent() async {
    switch (_period) {
      case WerkaArchivePeriod.daily:
        await _loadDaily();
        return;
      case WerkaArchivePeriod.monthly:
        await _loadMonthly();
        return;
      case WerkaArchivePeriod.yearly:
        await _loadYearly();
        return;
      case WerkaArchivePeriod.custom:
        return;
    }
  }

  Future<void> _loadDaily() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _archive(
        period: WerkaArchivePeriod.monthly,
        from: DateTime(_displayMonth.year, _displayMonth.month, 1),
        to: DateTime(_displayMonth.year, _displayMonth.month + 1, 0),
      );
      if (!mounted) {
        return;
      }
      final days = <int>{};
      for (final item in result.items) {
        final created = parseCreatedLabelTimestamp(item.createdLabel);
        if (created != null &&
            created.year == _displayMonth.year &&
            created.month == _displayMonth.month) {
          days.add(created.day);
        }
      }
      setState(() {
        _activeDays = days;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMonthly() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _archive(
        period: WerkaArchivePeriod.yearly,
        from: DateTime(_displayYear, 1, 1),
        to: DateTime(_displayYear, 12, 31),
      );
      if (!mounted) {
        return;
      }
      final months = <int>{};
      for (final item in result.items) {
        final created = parseCreatedLabelTimestamp(item.createdLabel);
        if (created != null && created.year == _displayYear) {
          months.add(created.month);
        }
      }
      setState(() {
        _activeMonths = months;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadYearly() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _archive(
        period: WerkaArchivePeriod.yearly,
        from: DateTime(_startYear, 1, 1),
        to: DateTime(_startYear + 11, 12, 31),
      );
      if (!mounted) {
        return;
      }
      final years = <int>{};
      for (final item in result.items) {
        final created = parseCreatedLabelTimestamp(item.createdLabel);
        if (created != null &&
            created.year >= _startYear &&
            created.year <= _startYear + 11) {
          years.add(created.year);
        }
      }
      setState(() {
        _activeYears = years;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openList({
    required WerkaArchivePeriod period,
    required DateTime from,
    required DateTime to,
  }) {
    Navigator.of(context).pushNamed(
      AppRoutes.werkaArchiveList,
      arguments: WerkaArchiveListArgs(
        kind: WerkaArchiveKind.sent,
        period: period,
        from: from,
        to: to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    useNativeNavigationTitle(context, l10n.archiveSentTitle);
    return AppShell(
      title: l10n.archiveSentTitle,
      subtitle: l10n.archiveChoosePeriod,
      leading: NativeBackButtonSlot(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading &&
        _activeDays.isEmpty &&
        _activeMonths.isEmpty &&
        _activeYears.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null &&
        _activeDays.isEmpty &&
        _activeMonths.isEmpty &&
        _activeYears.isEmpty) {
      return AppRetryState(onRetry: _loadCurrent);
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _loadCurrent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 110),
        children: [
          Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in [
                    (WerkaArchivePeriod.daily, l10n.archiveDailyTitle),
                    (WerkaArchivePeriod.monthly, l10n.archiveMonthlyTitle),
                    (WerkaArchivePeriod.yearly, l10n.archiveYearlyTitle),
                  ])
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: _period == item.$1,
                      onSelected: (_) async {
                        setState(() => _period = item.$1);
                        await _loadCurrent();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildPanel(context),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    switch (_period) {
      case WerkaArchivePeriod.daily:
        return _buildDailyPanel(context);
      case WerkaArchivePeriod.monthly:
        return _buildMonthlyPanel(context);
      case WerkaArchivePeriod.yearly:
        return _buildYearlyPanel(context);
      case WerkaArchivePeriod.custom:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDailyPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
          currentDate: DateTime.now(),
          onDisplayedMonthChanged: (value) {
            final nextMonth = DateTime(value.year, value.month, 1);
            if (nextMonth == _displayMonth) return;
            setState(() => _displayMonth = nextMonth);
            _loadDaily();
          },
          onDateChanged: (value) {
            final date = DateUtils.dateOnly(value);
            setState(() => _selectedDate = date);
            _openList(period: WerkaArchivePeriod.daily, from: date, to: date);
          },
        ),
      ),
    );
  }

  Widget _buildMonthlyPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    setState(() => _displayYear--);
                    await _loadMonthly();
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '$_displayYear',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => _displayYear++);
                    await _loadMonthly();
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int month = 1; month <= 12; month++)
                  _SentHubMonthCell(
                    label: localizations
                        .formatMonthYear(DateTime(_displayYear, month, 1))
                        .split(' ')
                        .first,
                    active: _activeMonths.contains(month),
                    onTap: () {
                      final from = DateTime(_displayYear, month, 1);
                      final to = DateTime(_displayYear, month + 1, 0);
                      _openList(
                        period: WerkaArchivePeriod.monthly,
                        from: from,
                        to: to,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final years = [for (int year = _startYear; year <= _startYear + 11; year++) year];
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    setState(() => _startYear -= 12);
                    await _loadYearly();
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${years.first} - ${years.last}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => _startYear += 12);
                    await _loadYearly();
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final year in years)
                  _SentHubYearCell(
                    year: year,
                    active: _activeYears.contains(year),
                    onTap: () {
                      _openList(
                        period: WerkaArchivePeriod.yearly,
                        from: DateTime(year, 1, 1),
                        to: DateTime(year, 12, 31),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentHubMonthCell extends StatelessWidget {
  const _SentHubMonthCell({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Material(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: active
                  ? Border.all(color: scheme.primary, width: 1.2)
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentHubYearCell extends StatelessWidget {
  const _SentHubYearCell({
    required this.year,
    required this.active,
    required this.onTap,
  });

  final int year;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Material(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: active
                  ? Border.all(color: scheme.primary, width: 1.2)
                  : null,
            ),
            child: Text(
              '$year',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
