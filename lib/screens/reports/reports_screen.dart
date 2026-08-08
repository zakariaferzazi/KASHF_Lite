import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

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
  int _filterIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const List<_FilterDef> _filters = [
    _FilterDef(_FilterKind.all, 'reports_filter_all'),
    _FilterDef(_FilterKind.favorites, 'reports_filter_favorites'),
    _FilterDef(_FilterKind.shared, 'reports_filter_shared'),
    _FilterDef(_FilterKind.archived, 'reports_filter_archived'),
  ];

  static const List<_KpiDef> _kpis = [
    _KpiDef(
      value: '24',
      labelKey: 'reports_kpi_completed',
      icon: Icons.check_circle_outline,
      iconBg: Color(0xFF22C55E),
      iconFg: Colors.white,
    ),
    _KpiDef(
      value: '8',
      labelKey: 'reports_kpi_in_progress',
      icon: Icons.access_time,
      iconBg: Color(0xFF3B82F6),
      iconFg: Colors.white,
    ),
    _KpiDef(
      value: '56',
      labelKey: 'reports_kpi_total',
      icon: Icons.description_outlined,
      iconBg: Color(0xFFF59E0B),
      iconFg: Colors.white,
    ),
    _KpiDef(
      value: '12',
      labelKey: 'reports_kpi_review',
      icon: Icons.refresh,
      iconBg: Color(0xFF8B5CF6),
      iconFg: Colors.white,
    ),
  ];

  static const List<_ReportItem> _items = [
    _ReportItem(
      titleKey: 'reports_item1_title',
      sectorKey: 'reports_sector_perfume',
      timeKey: 'reports_item1_time',
      statusKey: 'reports_status_completed',
      statusColor: _StatusColor.completed,
      bookmarked: false,
      image: 'assets/images/sauvage.jpeg',
      fallbackIcon: Icons.image_outlined,
    ),
    _ReportItem(
      titleKey: 'reports_item2_title',
      sectorKey: 'reports_sector_perfume',
      timeKey: 'reports_item2_time',
      statusKey: 'reports_status_completed',
      statusColor: _StatusColor.completed,
      bookmarked: false,
      image: 'assets/images/parfum.jpeg',
      fallbackIcon: Icons.image_outlined,
    ),
    _ReportItem(
      titleKey: 'reports_item3_title',
      sectorKey: 'reports_sector_perfume',
      timeKey: 'reports_item3_time',
      statusKey: 'reports_status_review',
      statusColor: _StatusColor.review,
      bookmarked: true,
      image: 'assets/images/winner.jpeg',
      fallbackIcon: Icons.image_outlined,
    ),
    _ReportItem(
      titleKey: 'reports_item4_title',
      sectorKey: 'reports_sector_social',
      timeKey: 'reports_item4_time',
      statusKey: 'reports_status_completed',
      statusColor: _StatusColor.completed,
      bookmarked: false,
      image: 'assets/images/lattafa.jpeg',
      fallbackIcon: Icons.image_outlined,
    ),
    _ReportItem(
      titleKey: 'reports_item5_title',
      sectorKey: 'reports_sector_social',
      timeKey: 'reports_item5_time',
      statusKey: 'reports_status_review',
      statusColor: _StatusColor.review,
      bookmarked: true,
      image: 'assets/images/borge.jpeg',
      fallbackIcon: Icons.image_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                    filters: _filters,
                    selectedIndex: _filterIndex,
                    onSelect: (i) => setState(() => _filterIndex = i),
                    l: l,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _KpiRow(kpis: _kpis, l: l),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 22, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: _RecentHeader(l: l, onSort: () {}),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ReportCard(item: _items[i], l: l),
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

enum _FilterKind { all, favorites, shared, archived }

class _FilterDef {
  const _FilterDef(this.kind, this.labelKey);
  final _FilterKind kind;
  final String labelKey;
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
              icon: _iconFor(filters[i].kind),
            ),
            if (i != filters.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  IconData? _iconFor(_FilterKind k) {
    switch (k) {
      case _FilterKind.all:
        return Icons.dashboard_customize_outlined;
      case _FilterKind.favorites:
        return Icons.star_border;
      case _FilterKind.shared:
        return Icons.group_outlined;
      case _FilterKind.archived:
        return Icons.calendar_month_outlined;
    }
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
  const _RecentHeader({required this.l, required this.onSort});
  final AppLocalizations l;
  final VoidCallback onSort;

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
                    l.t('reports_sort_label'),
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

enum _StatusColor { completed, review, progress }

class _ReportItem {
  const _ReportItem({
    required this.titleKey,
    required this.sectorKey,
    required this.timeKey,
    required this.statusKey,
    required this.statusColor,
    required this.bookmarked,
    required this.image,
    required this.fallbackIcon,
  });
  final String titleKey;
  final String sectorKey;
  final String timeKey;
  final String statusKey;
  final _StatusColor statusColor;
  final bool bookmarked;
  final String image;
  final IconData fallbackIcon;
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, required this.l});
  final _ReportItem item;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final textPrimary = KashfPalette.active.textPrimary;
    final textSecondary = KashfPalette.active.textSecondary;

    final (statusBg, statusFg) = _statusColors(item.statusColor);

    return Container(
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
          // Vertical icon column on the left
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                item.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: item.bookmarked ? KashfColors.gold : textSecondary,
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
                  l.t(item.titleKey),
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
                        l.t(item.sectorKey),
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
                        l.t(item.timeKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusPill(
                      label: l.t(item.statusKey),
                      bg: statusBg,
                      fg: statusFg,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Thumbnail on the right
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              color: const Color(0xFF1A1C28),
              alignment: Alignment.center,
              child: Image.asset(
                item.image,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  item.fallbackIcon,
                  size: 26,
                  color: KashfPalette.active.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg) _statusColors(_StatusColor c) {
    switch (c) {
      case _StatusColor.completed:
        return (const Color(0xFF22C55E), Colors.white);
      case _StatusColor.review:
        return (const Color(0xFFF59E0B), Colors.white);
      case _StatusColor.progress:
        return (const Color(0xFF3B82F6), Colors.white);
    }
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
