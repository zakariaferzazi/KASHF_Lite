import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/entity_type.dart';
import '../../models/saved_investigation.dart';
import '../../services/investigation_archive_service.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../investigation/investigation_results_screen.dart';

/// "Latest Investigations" (آخر التحقيقات) screen — shows the
/// user's investigation archive backed by
/// [LatestInvestigationsController], which streams the user's
/// documents directly from Firestore.
///
/// Layout (top → bottom):
///   1. Top bar (back · title · search · filter · more)
///   2. Subtitle line
///   3. Category chips row (All · Companies · Brands · Products · Influencers · Markets)
///   4. Sort row (Newest first dropdown · Apply N pill)
///   5. List of investigation cards driven by Firestore
///   6. Bottom safe-area padding
///
/// The reference is an Arabic-language RTL screen whose *visual*
/// layout is LTR (back arrow on the left, card images on the left,
/// status pill on the right). To preserve that 1:1 visual mapping, the
/// screen is rendered as `TextDirection.ltr` for the layout while the
/// text content itself flows RTL.
class LatestInvestigationsScreen extends StatefulWidget {
  const LatestInvestigationsScreen({super.key});

  @override
  State<LatestInvestigationsScreen> createState() =>
      _LatestInvestigationsScreenState();
}

class _LatestInvestigationsScreenState
    extends State<LatestInvestigationsScreen> {
  /// Index into [_categoryEntries] — `0` means "All" (no filter).
  int _selectedTab = 0;

  /// Current search query applied to the title / subtitle. Empty
  /// string means no search filter.
  String _query = '';

  /// Active sort mode. `newest` puts the most recently created
  /// investigation first (matches the Firestore snapshot order);
  /// `oldest` reverses it.
  _SortMode _sortMode = _SortMode.newest;

  late final LatestInvestigationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LatestInvestigationsController();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Loads the full report for the tapped investigation and pushes
  /// the detail screen. Mirrors `_HomeScreenState._openSavedReport`
  /// so the home screen and this screen share one tap behaviour.
  Future<void> _openSavedReport(SavedInvestigation item) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await InvestigationArchiveService.instance
          .loadResult(item.id);
      if (!mounted) return;
      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This saved report cannot be opened — only its '
              'summary is available. Re-run the investigation '
              'to refresh.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => InvestigationResultsScreen(result: result),
        ),
      );
    } catch (e, st) {
      debugPrint('[LatestInvestigationsScreen] openSavedReport failed: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this report.')),
      );
    }
  }

  /// Applies the search query, category filter, and sort order to
  /// the controller's snapshot. The category chip index maps to
  /// [_categoryEntries] — index 0 means "no filter".
  List<SavedInvestigation> _filteredItems(AppLocalizations l) {
    final source = _controller.items;
    final entry = _categoryEntries[_selectedTab];

    Iterable<SavedInvestigation> view = source;
    if (entry.entityType != null) {
      view = view.where((it) => it.entityType == entry.entityType);
    }

    if (_query.trim().isNotEmpty) {
      final needle = _query.trim().toLowerCase();
      view = view.where((it) {
        return it.title.toLowerCase().contains(needle) ||
            it.subtitle.toLowerCase().contains(needle) ||
            it.tags.any((t) => t.toLowerCase().contains(needle));
      });
    }

    final list = view.toList();
    switch (_sortMode) {
      case _SortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortMode.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortMode.confidence:
        list.sort((a, b) => b.confidencePercent.compareTo(a.confidencePercent));
    }
    return list;
  }

  /// Pops up the search bar inline. The bar appears as a row
  /// under the top bar when the search icon is tapped and
  /// dismisses when the user submits an empty query or taps the
  /// close icon.
  Future<void> _openSearch() async {
    final l = AppLocalizations.of(context);
    final query = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KashfPalette.active.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final controller = TextEditingController(text: _query);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.search,
                    color: KashfPalette.active.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.t('li_search_title'),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => Navigator.of(sheetCtx).pop(value),
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: l.t('li_search_hint'),
                  hintStyle: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: KashfPalette.active.textSecondary,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: KashfPalette.active.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: KashfPalette.active.cardBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: KashfPalette.active.cardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: KashfColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(''),
                      style: TextButton.styleFrom(
                        foregroundColor: KashfPalette.active.textSecondary,
                      ),
                      child: Text(l.t('li_search_clear')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetCtx)
                          .pop(controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KashfColors.gold,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(l.t('li_search_apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (query != null) {
      setState(() => _query = query);
    }
  }

  /// Pops up a filter sheet that mirrors the chip row, so the
  /// user can pick an entity type from the bottom sheet as well
  /// as the chip row above the list.
  Future<void> _openFilter() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: KashfPalette.active.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.t('li_filter_title'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _categoryEntries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CategoryChip(
                      label: l.t(_categoryEntries[i].labelKey),
                      icon: _categoryEntries[i].icon,
                      selected: i == _selectedTab,
                      onTap: () => Navigator.of(sheetCtx).pop(i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedTab = picked);
  }

  /// Opens an options sheet with refresh + clear-filters entries
  /// (the more-vert icon on the top bar).
  Future<void> _openMore() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KashfPalette.active.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetTile(
                  icon: Icons.refresh,
                  label: l.t('li_more_refresh'),
                  onTap: () => Navigator.of(sheetCtx).pop('refresh'),
                ),
                _SheetTile(
                  icon: Icons.filter_alt_off_outlined,
                  label: l.t('li_more_clear'),
                  onTap: () => Navigator.of(sheetCtx).pop('clear'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    switch (picked) {
      case 'refresh':
        await _controller.refresh();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l.t('li_more_refreshed'))),
        );
      case 'clear':
        setState(() {
          _query = '';
          _selectedTab = 0;
          _sortMode = _SortMode.newest;
        });
    }
  }

  /// Pops a real menu off the "Newest first ▾" sort dropdown.
  Future<void> _openSortMenu() async {
    final picked = await showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: KashfPalette.active.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetTile(
                  icon: Icons.schedule,
                  label: l.t('li_sort_newest'),
                  trailing: _sortMode == _SortMode.newest
                      ? Icon(
                          Icons.check,
                          color: KashfColors.gold,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetCtx).pop(_SortMode.newest),
                ),
                _SheetTile(
                  icon: Icons.history,
                  label: l.t('li_sort_oldest'),
                  trailing: _sortMode == _SortMode.oldest
                      ? Icon(
                          Icons.check,
                          color: KashfColors.gold,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetCtx).pop(_SortMode.oldest),
                ),
                _SheetTile(
                  icon: Icons.bolt,
                  label: l.t('li_sort_confidence'),
                  trailing: _sortMode == _SortMode.confidence
                      ? Icon(
                          Icons.check,
                          color: KashfColors.gold,
                          size: 18,
                        )
                      : null,
                  onTap: () =>
                      Navigator.of(sheetCtx).pop(_SortMode.confidence),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null) setState(() => _sortMode = picked);
  }

  /// "Apply N" pill — re-runs the filter against the current
  /// snapshot and shows a SnackBar summarising what changed.
  /// Kept as a real action so the pill is never decorative.
  void _onApplyPressed(AppLocalizations l) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {});
    final filtered = _filteredItems(l);
    final total = _controller.items.length;
    final shown = filtered.length;
    if (shown == total) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.tp('li_apply_count', {'n': shown.toString()}),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.tp('li_apply_filtered', {
              'shown': shown.toString(),
              'total': total.toString(),
            }),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _filteredItems(l);
    final hasActiveFilter =
        _selectedTab != 0 || _query.trim().isNotEmpty || _sortMode != _SortMode.newest;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _TopBar(
                l: l,
                onSearch: _openSearch,
                onFilter: _openFilter,
                onMore: _openMore,
                hasActiveFilter: hasActiveFilter,
                query: _query,
              ),
              const SizedBox(height: 8),
              _Subtitle(l: l),
              const SizedBox(height: 14),
              _CategoryChips(
                l: l,
                selected: _selectedTab,
                onSelect: (i) => setState(() => _selectedTab = i),
              ),
              const SizedBox(height: 12),
              _SortRow(
                l: l,
                count: items.length,
                sortMode: _sortMode,
                onTapDropdown: _openSortMenu,
                onTapApply: () => _onApplyPressed(l),
              ),
              const SizedBox(height: 12),
              if (_controller.isLoading && _controller.items.isEmpty)
                _LatestInvestigationsSkeleton(count: 3)
              else if (items.isEmpty)
                _EmptyState(
                   l: l,
                   isFilterResult: _controller.items.isNotEmpty,
                   onClear: hasActiveFilter
                       ? () => setState(() {
                             _query = '';
                             _selectedTab = 0;
                             _sortMode = _SortMode.newest;
                           })
                       : null,
                 )
              else
                for (var i = 0; i < items.length; i++) ...[
                  _InvestigationCard(
                    l: l,
                    saved: items[i],
                    onTap: () => _openSavedReport(items[i]),
                  ),
                  if (i != items.length - 1) const SizedBox(height: 8),
                ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Sort mode + category table
// ============================================================================

/// Three sort orders the user can pick from the dropdown.
enum _SortMode { newest, oldest, confidence }

/// One chip in the category row. `entityType == null` means
/// "All" — no filter applied.
class _CategoryEntry {
  const _CategoryEntry({
    required this.labelKey,
    required this.icon,
    this.entityType,
  });
  final String labelKey;
  final IconData icon;
  final EntityType? entityType;
}

/// Single source of truth for the chip row and the filter sheet
/// — both share this list so the order is consistent.
const List<_CategoryEntry> _categoryEntries = <_CategoryEntry>[
  _CategoryEntry(
    labelKey: 'li_tab_all',
    icon: Icons.layers_outlined,
  ),
  _CategoryEntry(
    labelKey: 'li_tab_companies',
    icon: Icons.apartment_outlined,
    entityType: EntityType.company,
  ),
  _CategoryEntry(
    labelKey: 'li_tab_brands',
    icon: Icons.local_offer_outlined,
    entityType: EntityType.brand,
  ),
  _CategoryEntry(
    labelKey: 'li_tab_products',
    icon: Icons.inventory_2_outlined,
    entityType: EntityType.product,
  ),
  _CategoryEntry(
    labelKey: 'li_tab_influencers',
    icon: Icons.person_outline,
    entityType: EntityType.influencer,
  ),
  _CategoryEntry(
    labelKey: 'li_tab_markets',
    icon: Icons.public,
    entityType: EntityType.market,
  ),
];

/// One row inside a bottom-sheet menu.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: KashfPalette.active.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Empty + loading states
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.l,
    required this.isFilterResult,
    this.onClear,
  });
  final AppLocalizations l;

  /// `true` when the user has filtered the list down to zero
  /// results (so the message and the clear-filters action make
  /// sense). `false` when the user's archive is genuinely empty.
  final bool isFilterResult;

  /// When supplied, renders a "Clear filters" pill that resets
  /// the search / category / sort state.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KashfColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFilterResult
                      ? Icons.filter_alt_off_outlined
                      : Icons.search,
                  color: KashfColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFilterResult
                          ? l.t('li_no_filter_results_title')
                          : l.t('home_latest_empty_title'),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFilterResult
                          ? l.t('li_no_filter_results_sub')
                          : l.t('home_latest_empty_sub'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isFilterResult && onClear != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: Text(l.t('li_more_clear')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KashfColors.gold,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _LatestInvestigationsSkeleton extends StatefulWidget {
  const _LatestInvestigationsSkeleton({this.count = 2});
  final int count;

  @override
  State<_LatestInvestigationsSkeleton> createState() =>
      _LatestInvestigationsSkeletonState();
}

class _LatestInvestigationsSkeletonState
    extends State<_LatestInvestigationsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final alpha = 0.25 + 0.25 * _ctrl.value;
        return Column(
          children: [
            for (var i = 0; i < widget.count; i++) ...[
              if (i != 0) const SizedBox(height: 8),
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: KashfPalette.active.surface
                      .withValues(alpha: alpha),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
// Mapping helpers — translate SavedInvestigation → card fields
// ============================================================================

/// Maps an [EntityType] to its `(labelKey, color)` tuple for the
/// chip rendered on the investigation card. Kept tiny on purpose
/// so the screen stays self-contained.
({String labelKey, Color color}) _entityBadge(EntityType type) {
  switch (type) {
    case EntityType.company:
      return (labelKey: 'li_badge_company', color: const Color(0xFFF4C542));
    case EntityType.brand:
      return (labelKey: 'li_badge_brand', color: const Color(0xFFF4C542));
    case EntityType.product:
      return (labelKey: 'li_badge_product', color: const Color(0xFF60A5FA));
    case EntityType.influencer:
      return (labelKey: 'li_badge_influencer', color: const Color(0xFFEC4899));
    case EntityType.market:
      // No dedicated `li_badge_market` key — fall back to the
      // company styling so the badge still renders cleanly.
      return (labelKey: 'li_badge_company', color: const Color(0xFF8B5CF6));
  }
}

/// Maps a confidence band ('high' / 'medium' / 'low') to the
/// `(labelKey, color)` tuple used on the right-side confidence
/// column of the card.
({String labelKey, Color color}) _bandStyle(String band) {
  switch (band) {
    case 'high':
      return (
        labelKey: 'li_confidence_high',
        color: const Color(0xFF22C55E),
      );
    case 'low':
      return (
        labelKey: 'li_confidence_medium',
        color: const Color(0xFFEF4444),
      );
    default:
      return (
        labelKey: 'li_confidence_medium',
        color: const Color(0xFFF4C542),
      );
  }
}

/// Formats [dt] as a 24-hour HH:mm string for the metric row.
String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Formats [dt] as a short date string for the metric row.
/// Locale-neutral on purpose — the surrounding UI already uses
/// RTL-aware `Directionality` wrappers for content text.
String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Human-friendly "x ago" label. Falls back to the localized
/// "just now" string for fresh investigations.
String _sinceLabel(AppLocalizations l, DateTime then) {
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) return l.t('home_latest_since_just_now');
  if (diff.inMinutes < 60) {
    return l
        .t('home_latest_since_minutes')
        .replaceAll('%{n}', diff.inMinutes.toString());
  }
  if (diff.inHours < 24) {
    return l
        .t('home_latest_since_hours')
        .replaceAll('%{n}', diff.inHours.toString());
  }
  return l
      .t('home_latest_since_days')
      .replaceAll('%{n}', diff.inDays.toString());
}

// ============================ Top Bar ============================
//
// Visual order (left → right):
//   [back]  [title]  [search]  [filter w/ badge]  [more]
//
// All three action icons are wired to real handlers supplied by
/// the screen state. The filter icon also shows a badge when
/// any filter (search / category / sort) is active so the user
/// knows the list isn't showing everything.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.l,
    required this.onSearch,
    required this.onFilter,
    required this.onMore,
    required this.hasActiveFilter,
    required this.query,
  });

  final AppLocalizations l;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onMore;
  final bool hasActiveFilter;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _BackIcon(onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  l.t('li_title'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _SearchIcon(onTap: onSearch, active: query.isNotEmpty),
            const SizedBox(width: 8),
            _FilterIconWithBadge(
              onTap: onFilter,
              active: hasActiveFilter,
            ),
            const SizedBox(width: 8),
            _MoreIcon(onTap: onMore),
          ],
        ),
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 42),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: KashfPalette.active.textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: KashfPalette.active.textPrimary,
          size: 24,
        ),
      ),
    );
  }
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon({required this.onTap, this.active = false});
  final VoidCallback onTap;

  /// When true, paints the icon gold so the user can tell the
  /// search query is currently filtering the list.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.search,
          color: active
              ? KashfColors.gold
              : KashfPalette.active.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

/// Filter icon with a small numeric badge in the top-right corner.
/// The badge appears whenever a filter is active so the user has
/// a visible cue that the list is filtered.
class _FilterIconWithBadge extends StatelessWidget {
  const _FilterIconWithBadge({required this.onTap, this.active = false});
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.tune,
                color: active
                    ? KashfColors.gold
                    : KashfPalette.active.textPrimary,
                size: 20,
              ),
            ),
            if (active)
              const Positioned(
                right: 0,
                top: 2,
                child: _DotBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotBadge extends StatelessWidget {
  const _DotBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: KashfColors.gold,
        shape: BoxShape.circle,
        border: Border.all(
          color: KashfPalette.active.background,
          width: 1.5,
        ),
      ),
    );
  }
}

class _MoreIcon extends StatelessWidget {
  const _MoreIcon({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.more_vert,
          color: KashfPalette.active.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

// ============================ Subtitle ============================
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        l.t('li_subtitle'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: KashfPalette.active.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

// ============================ Category Chips ============================
//
// Visual order (left → right) — Arabic is rendered RTL inside each chip:
//   [All (gold/selected)] [Companies] [Brands] [Products] [Influencers] [Markets]
//
// The list scrolls horizontally so the chips on the right (Markets)
// are partially clipped at the screen edge.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.l,
    required this.selected,
    required this.onSelect,
  });

  final AppLocalizations l;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Reads from the shared `_categoryEntries` table so the chip
    // row and the filter sheet stay in lock-step.
    final children = <Widget>[];
    for (int i = 0; i < _categoryEntries.length; i++) {
      children.add(_CategoryChip(
        label: l.t(_categoryEntries[i].labelKey),
        icon: _categoryEntries[i].icon,
        selected: i == selected,
        onTap: () => onSelect(i),
      ));
      if (i != _categoryEntries.length - 1) {
        children.add(const SizedBox(width: 8));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? KashfColors.gold
        : KashfPalette.active.surface;
    final fg = selected ? Colors.black : KashfPalette.active.textPrimary;
    final borderColor = selected
        ? KashfColors.gold
        : KashfPalette.active.cardBorder;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 6),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ Sort Row ============================
//
// Visual order (left → right):
//   [Sort label ▾]                                    [Apply N]
//
// The left chip is a real dropdown — tapping it opens a bottom
/// sheet with three sort options. The right pill shows the live
/// filtered count and is tappable, firing [onTapApply] (typically
/// re-runs the filter and shows a SnackBar summary).
class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.l,
    required this.count,
    required this.sortMode,
    required this.onTapDropdown,
    required this.onTapApply,
  });

  final AppLocalizations l;

  /// Number of investigations currently displayed after the
  /// search + category filters run.
  final int count;

  /// Current sort mode — drives the dropdown's label.
  final _SortMode sortMode;

  /// Tap handler for the dropdown on the left.
  final VoidCallback onTapDropdown;

  /// Tap handler for the "Apply N" pill on the right.
  final VoidCallback onTapApply;

  String _sortLabel() {
    switch (sortMode) {
      case _SortMode.newest:
        return 'li_sort_newest';
      case _SortMode.oldest:
        return 'li_sort_oldest';
      case _SortMode.confidence:
        return 'li_sort_confidence';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTapDropdown,
            child: Container(
              height: 40,
              padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
              decoration: BoxDecoration(
                color: KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KashfPalette.active.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.expand_more,
                    color: KashfPalette.active.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        l.t(_sortLabel()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTapApply,
          child: Container(
            height: 40,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            decoration: BoxDecoration(
              color: KashfPalette.active.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            alignment: Alignment.center,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                l.tp('li_apply_count', {'n': count.toString()}),
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================ Investigation Card ============================
//
// Visual order (left → right):
//   [thumbnail]  [title row · badge · status · metrics · tags]   [more-vert]
//                                       [confidence label + %]
//
// Hydrated from a [SavedInvestigation] sourced directly from
// Firestore. Tap → [onTap] opens the full report on the
// InvestigationResultsScreen.
class _InvestigationCard extends StatelessWidget {
  const _InvestigationCard({
    required this.l,
    required this.saved,
    required this.onTap,
  });

  final AppLocalizations l;
  final SavedInvestigation saved;
  final VoidCallback onTap;

  /// Thumbnail source — the saved record's own URL when one is
  /// available, otherwise the bundled `report.jpg` so every row
  /// still has a recognisable image.
  String get _thumbnailAsset => 'assets/images/report.jpg';

  @override
  Widget build(BuildContext context) {
    final badge = _entityBadge(saved.entityType);
    final band = _bandStyle(saved.confidenceBand);
    final tags = saved.tags;

    final card = Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _Thumbnail(imageAsset: _thumbnailAsset),
            const SizedBox(width: 8),
            // Middle content column — wide.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top header row: badge (right) · 3-dot (far right).
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _BadgeChip(
                          label: l.t(badge.labelKey),
                          color: badge.color,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Icon(
                          Icons.more_vert,
                          color: KashfPalette.active.textSecondary,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Title (RTL, right-aligned).
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      saved.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Metrics, right-aligned (RTL).
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        _InlineMetric(
                          icon: Icons.access_time,
                          value: _formatTime(saved.createdAt),
                        ),
                        _InlineMetric(
                          icon: Icons.event_outlined,
                          value: _formatDate(saved.createdAt),
                        ),
                        _InlineMetric(
                          icon: Icons.folder_outlined,
                          value: _sinceLabel(l, saved.createdAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Tag chips (right-aligned, RTL flow).
                  if (tags.isNotEmpty)
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.end,
                        children: [
                          for (final t in tags) _TagChip(label: t),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Thin vertical divider between content and confidence column.
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: KashfPalette.active.cardBorder,
            ),
            const SizedBox(width: 8),
            // Right column: status pill on top, big % centered, label centered.
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _StatusPill(
                    label: l.t('li_status_complete'),
                    color: band.color,
                  ),
                  const Spacer(),
                  Text(
                    '${saved.confidencePercent}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: band.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      l.t(band.labelKey),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );

    // Tappable wrapper so the whole row opens the saved report
    // when tapped. Same pattern used by the home screen's
    // recent updates card.
    return Material(
      color: KashfPalette.active.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

/// One small inline metric used inside the metric row (icon + text).
class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: KashfPalette.active.textSecondary,
          size: 10,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Small status pill (e.g. "قيد التحليل", "مكتمل").
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageAsset});
  final String imageAsset;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        imageAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: KashfPalette.active.fieldFill,
          child: Icon(
            Icons.image_outlined,
            color: KashfPalette.active.textSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}