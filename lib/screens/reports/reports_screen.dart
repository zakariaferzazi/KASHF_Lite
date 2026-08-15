import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/theme_scope.dart';
import '../../models/entity_type.dart';
import '../../models/saved_investigation.dart';
import '../../services/investigation_archive_service.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../investigation/investigation_results_screen.dart';

/// Reports tab — redesigned to match the marketing reference: a header
/// with title + subtitle, a search field, filter chips, KPI cards, a
/// "Recent reports" section header with a sort label, and a list of
/// report cards.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// Filter index — maps to [_filterDefs]:
  ///   0 = all
  ///   1 = companies
  ///   2 = brands
  ///   3 = products
  ///   4 = influencers
  ///   5 = markets
  int _filterIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _SortMode _sortMode = _SortMode.newest;
  late final LatestInvestigationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LatestInvestigationsController();
    _controller.addListener(_onControllerChanged);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_query == _searchCtrl.text) return;
    setState(() => _query = _searchCtrl.text);
  }

  /// Opens the saved report for the tapped card. Mirrors the
  /// tap behaviour used in the home + latest investigations +
  /// explore screens.
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
      debugPrint('[ReportsScreen] openSavedReport failed: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this report.')),
      );
    }
  }

  // ============================ Filter definitions ============================
  //
  // The original screen had four "favorites / shared / archived" filters that
  // we don't actually persist on a SavedInvestigation. To stay useful with
  // the data we DO have, the filter row now classifies by entity type
  // (matches the latest investigations screen) plus an "All" entry.

  static const List<_FilterDef> _filterDefs = <_FilterDef>[
    _FilterDef(_FilterKind.all, 'reports_filter_all', Icons.dashboard_customize_outlined),
    _FilterDef(
      _FilterKind.companies,
      'li_tab_companies',
      Icons.apartment_outlined,
    ),
    _FilterDef(
      _FilterKind.brands,
      'li_tab_brands',
      Icons.local_offer_outlined,
    ),
    _FilterDef(
      _FilterKind.products,
      'li_tab_products',
      Icons.inventory_2_outlined,
    ),
    _FilterDef(
      _FilterKind.influencers,
      'li_tab_influencers',
      Icons.person_outline,
    ),
    _FilterDef(
      _FilterKind.markets,
      'li_tab_markets',
      Icons.public,
    ),
  ];

  EntityType? _entityTypeForKind(_FilterKind kind) {
    switch (kind) {
      case _FilterKind.all:
        return null;
      case _FilterKind.companies:
        return EntityType.company;
      case _FilterKind.brands:
        return EntityType.brand;
      case _FilterKind.products:
        return EntityType.product;
      case _FilterKind.influencers:
        return EntityType.influencer;
      case _FilterKind.markets:
        return EntityType.market;
    }
  }

  // ============================ KPI computation ============================

  /// Computes the four KPI values from the Firestore snapshot. The
  /// original screen used hardcoded numbers; we now surface live
  /// counts so the user always sees the truth.
  List<_KpiDef> _kpisFor(AppLocalizations l) {
    final items = _controller.items;
    final completed = items.length; // every saved record is completed
    final highConfidence = items.where((it) => it.confidenceBand == 'high').length;
    final mediumConfidence =
        items.where((it) => it.confidenceBand == 'medium').length;
    final lowConfidence =
        items.where((it) => it.confidenceBand == 'low').length;
    // "In review" is our best proxy for "needs another look" given
    // that no review state is persisted — low confidence items.
    return <_KpiDef>[
      _KpiDef(
        value: completed.toString(),
        labelKey: 'reports_kpi_completed',
        icon: Icons.check_circle_outline,
        iconBg: const Color(0xFF22C55E),
        iconFg: Colors.white,
      ),
      _KpiDef(
        value: highConfidence.toString(),
        labelKey: 'reports_kpi_high',
        icon: Icons.verified_outlined,
        iconBg: const Color(0xFF3B82F6),
        iconFg: Colors.white,
      ),
      _KpiDef(
        value: mediumConfidence.toString(),
        labelKey: 'reports_kpi_medium',
        icon: Icons.description_outlined,
        iconBg: const Color(0xFFF59E0B),
        iconFg: Colors.white,
      ),
      _KpiDef(
        value: lowConfidence.toString(),
        labelKey: 'reports_kpi_review',
        icon: Icons.refresh,
        iconBg: const Color(0xFF8B5CF6),
        iconFg: Colors.white,
      ),
    ];
  }

  // ============================ Filtering + sorting ============================

  /// Applies the active search query, filter chip and sort mode
  /// to the controller's snapshot. Mirrors the latest investigations
  /// screen behaviour so the two screens feel consistent.
  List<SavedInvestigation> _filteredItems(AppLocalizations l) {
    Iterable<SavedInvestigation> view = _controller.items;
    final entityType = _entityTypeForKind(_filterDefs[_filterIndex].kind);
    if (entityType != null) {
      view = view.where((it) => it.entityType == entityType);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      view = view.where((it) {
        return it.title.toLowerCase().contains(q) ||
            it.subtitle.toLowerCase().contains(q) ||
            it.tags.any((t) => t.toLowerCase().contains(q));
      });
    }
    final list = view.toList();
    switch (_sortMode) {
      case _SortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortMode.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortMode.confidence:
        list.sort(
          (a, b) => b.confidencePercent.compareTo(a.confidencePercent),
        );
    }
    return list;
  }

  /// Toggles a saved investigation's "favourited" visual state
  /// (cosmetic only — bookmarking isn't persisted yet). Keeps
  /// the bookmark icon on each card functional so the UI feels
  /// alive even before we wire persistence.
  void _toggleBookmark(String id) {
    setState(() {
      if (_bookmarkedIds.contains(id)) {
        _bookmarkedIds.remove(id);
      } else {
        _bookmarkedIds.add(id);
      }
    });
  }

  final Set<String> _bookmarkedIds = <String>{};

  /// Bottom-sheet menu for the sort dropdown on the recent header.
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
                _SortMenuTile(
                  icon: Icons.schedule,
                  label: l.t('li_sort_newest'),
                  selected: _sortMode == _SortMode.newest,
                  onTap: () =>
                      Navigator.of(sheetCtx).pop(_SortMode.newest),
                ),
                _SortMenuTile(
                  icon: Icons.history,
                  label: l.t('li_sort_oldest'),
                  selected: _sortMode == _SortMode.oldest,
                  onTap: () =>
                      Navigator.of(sheetCtx).pop(_SortMode.oldest),
                ),
                _SortMenuTile(
                  icon: Icons.bolt,
                  label: l.t('li_sort_confidence'),
                  selected: _sortMode == _SortMode.confidence,
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Subscribe to theme changes so the IndexedStack container in
    // [HomeShell] actually rebuilds us when the user picks a
    // different palette.
    ThemeScope.of(context);
    final items = _filteredItems(l);
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Header(l: l, onFilter: () {}),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SearchField(
                    controller: _searchCtrl,
                    hint: l.t('reports_search_hint'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _FilterChipsRow(
                    filters: _filterDefs,
                    selectedIndex: _filterIndex,
                    onSelect: (i) => setState(() => _filterIndex = i),
                    l: l,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _KpiRow(kpis: _kpisFor(l), l: l),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 22, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: _RecentHeader(
                    l: l,
                    onSort: _openSortMenu,
                    sortLabel: _sortLabelFor(l),
                  ),
                ),
              ),
              if (_controller.isLoading && _controller.items.isEmpty)
                const SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _ReportsSkeleton(),
                  ),
                )
              else if (items.isEmpty)
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _EmptyState(
                      l: l,
                      isFilterResult: _controller.items.isNotEmpty,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ReportCard(
                      saved: items[i],
                      bookmarked: _bookmarkedIds.contains(items[i].id),
                      onTap: () => _openSavedReport(items[i]),
                      onToggleBookmark: () => _toggleBookmark(items[i].id),
                      l: l,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortLabelFor(AppLocalizations l) {
    switch (_sortMode) {
      case _SortMode.newest:
        return l.t('li_sort_newest');
      case _SortMode.oldest:
        return l.t('li_sort_oldest');
      case _SortMode.confidence:
        return l.t('li_sort_confidence');
    }
  }
}

// =====================================================================
// Sort mode + filter kinds
// =====================================================================

enum _SortMode { newest, oldest, confidence }

enum _FilterKind {
  all,
  companies,
  brands,
  products,
  influencers,
  markets,
}

// =====================================================================
// Header
// =====================================================================

class _Header extends StatelessWidget {
  const _Header({required this.l, required this.onFilter});
  final AppLocalizations l;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final textPrimary = KashfPalette.active.textPrimary;
    final textSecondary = KashfPalette.active.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: [
        _FilterIconButton(onTap: onFilter),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('reports_title'),
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t('reports_subtitle'),
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KashfPalette.active.background,
            border: Border.all(color: KashfColors.gold, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.tune, size: 20, color: KashfColors.gold),
        ),
      ),
    );
  }
}

// =====================================================================
// Search
// =====================================================================

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 0),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: KashfPalette.active.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Filter chips
// =====================================================================

class _FilterDef {
  const _FilterDef(this.kind, this.labelKey, this.icon);
  final _FilterKind kind;
  final String labelKey;
  final IconData icon;
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.filters,
    required this.selectedIndex,
    required this.onSelect,
    required this.l,
  });

  final List<_FilterDef> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      reverse: l.isRtl,
      child: Row(
        children: [
          for (int i = 0; i < filters.length; i++) ...[
            _FilterChip(
              label: l.t(filters[i].labelKey),
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
              l: l,
              icon: filters[i].icon,
            ),
            if (i != filters.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.l,
    required this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppLocalizations l;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? KashfColors.gold : KashfPalette.active.textPrimary;
    final borderColor = selected
        ? KashfColors.gold
        : KashfPalette.active.cardBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 0),
          decoration: BoxDecoration(
            color: selected
                ? KashfColors.gold.withValues(alpha: 0.10)
                : KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// KPI row
// =====================================================================

class _KpiDef {
  const _KpiDef({
    required this.value,
    required this.labelKey,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });
  final String value;
  final String labelKey;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis, required this.l});
  final List<_KpiDef> kpis;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          Expanded(
            child: _KpiCard(kpi: kpis[i], l: l),
          ),
          if (i != kpis.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, required this.l});
  final _KpiDef kpi;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final textSecondary = KashfPalette.active.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kpi.iconBg.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(kpi.icon, size: 18, color: kpi.iconBg),
          ),
          const SizedBox(height: 10),
          Text(
            kpi.value,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.t(kpi.labelKey),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondary, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Recent header
// =====================================================================

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({
    required this.l,
    required this.onSort,
    required this.sortLabel,
  });
  final AppLocalizations l;
  final VoidCallback onSort;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l.t('reports_section_recent'),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onSort,
            child: Container(
              height: 34,
              padding: EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
              decoration: BoxDecoration(
                color: KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KashfPalette.active.cardBorder),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sortLabel,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.swap_vert,
                    size: 16,
                    color: KashfPalette.active.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Report card
// =====================================================================

/// Visual status palette derived from the saved record's confidence
/// band. Maps onto the same three pills the original screen used
/// (completed / review / progress) so the chrome stays identical
/// while the underlying data is now live.
class _ReportStatusStyle {
  const _ReportStatusStyle(this.bg, this.fg, this.labelKey);
  final Color bg;
  final Color fg;
  final String labelKey;
}

_ReportStatusStyle _styleFor(SavedInvestigation saved) {
  switch (saved.confidenceBand) {
    case 'high':
      return const _ReportStatusStyle(
        Color(0xFF22C55E),
        Colors.white,
        'reports_status_completed',
      );
    case 'low':
      return const _ReportStatusStyle(
        Color(0xFFF59E0B),
        Colors.white,
        'reports_status_review',
      );
    default:
      return const _ReportStatusStyle(
        Color(0xFF3B82F6),
        Colors.white,
        'reports_status_progress',
      );
  }
}

/// Sector label key derived from the entity type. Keeps the
/// little dot + sector line on each card populated from real data
/// instead of a hardcoded constant.
String _sectorLabelKey(EntityType type) {
  switch (type) {
    case EntityType.company:
      return 'reports_sector_company';
    case EntityType.brand:
      return 'reports_sector_brand';
    case EntityType.product:
      return 'reports_sector_product';
    case EntityType.influencer:
      return 'reports_sector_influencer';
    case EntityType.market:
      return 'reports_sector_market';
  }
}

/// "x ago" label for the timestamp row. Mirrors the helper used
/// in the home / latest investigations screens.
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.saved,
    required this.bookmarked,
    required this.onTap,
    required this.onToggleBookmark,
    required this.l,
  });

  final SavedInvestigation saved;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final textPrimary = KashfPalette.active.textPrimary;
    final textSecondary = KashfPalette.active.textSecondary;

    final style = _styleFor(saved);
    final sectorKey = _sectorLabelKey(saved.entityType);

    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.ltr,
        children: [
          // Vertical icon column on the left. Bookmark icon is
          // its own tappable target so we don't trigger the
          // card's onTap when the user only wants to star.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggleBookmark,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: bookmarked ? KashfColors.gold : textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Icon(Icons.more_vert, size: 14, color: textSecondary),
            ],
          ),
          const SizedBox(width: 12),
          // Content (title + meta)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: KashfColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l.t(sectorKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sinceLabel(l, saved.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusPill(
                      label: l.t(style.labelKey),
                      bg: style.bg,
                      fg: style.fg,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Thumbnail on the right — uses the bundled report.jpg
          // so every saved investigation shares a consistent
          // visual anchor (matches the rest of the app).
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              color: const Color(0xFF1A1C28),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/report.jpg',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_outlined,
                  size: 26,
                  color: KashfPalette.active.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: KashfPalette.active.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// =====================================================================
// Loading + empty states
// =====================================================================

class _ReportsSkeleton extends StatefulWidget {
  const _ReportsSkeleton();

  @override
  State<_ReportsSkeleton> createState() => _ReportsSkeletonState();
}

class _ReportsSkeletonState extends State<_ReportsSkeleton>
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
            for (var i = 0; i < 4; i++) ...[
              if (i != 0) const SizedBox(height: 12),
              Container(
                height: 84,
                decoration: BoxDecoration(
                  color:
                      KashfPalette.active.surface.withValues(alpha: alpha),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l, required this.isFilterResult});
  final AppLocalizations l;
  final bool isFilterResult;

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
      child: Row(
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
                      : l.t('reports_empty_title'),
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
                      : l.t('reports_empty_sub'),
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
    );
  }
}

// =====================================================================
// Sort menu tile
// =====================================================================

class _SortMenuTile extends StatelessWidget {
  const _SortMenuTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
            if (selected)
              const Icon(Icons.check, color: KashfColors.gold, size: 18),
          ],
        ),
      ),
    );
  }
}
