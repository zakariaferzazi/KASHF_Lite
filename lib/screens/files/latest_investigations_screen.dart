import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// "Latest Investigations" (آخر التحقيقات) screen — a strict,
/// pixel-perfect recreation of the provided reference screenshot.
///
/// Layout (top → bottom):
///   1. Top bar (back · title · search · filter · more)
///   2. Subtitle line
///   3. Category chips row (All · Companies · Brands · Products · Influencers · Markets)
///   4. Sort row (Newest first dropdown · Apply N pill)
///   5. List of investigation cards (6 items)
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
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
              _TopBar(l: l),
              const SizedBox(height: 8),
              _Subtitle(l: l),
              const SizedBox(height: 14),
              _CategoryChips(
                l: l,
                selected: _selectedTab,
                onSelect: (i) => setState(() => _selectedTab = i),
              ),
              const SizedBox(height: 12),
              _SortRow(l: l),
              const SizedBox(height: 12),
              _InvestigationCard(
                l: l,
                title: l.t('li1_title'),
                imageAsset: 'assets/images/lattafa.jpeg',
                badgeLabel: l.t('li_badge_company'),
                badgeColor: const Color(0xFFF4C542),
                statusLabel: l.t('li_status_complete'),
                statusColor: const Color(0xFF22C55E),
                confidenceLabel: l.t('li_confidence_high'),
                confidenceValue: '92%',
                confidenceColor: const Color(0xFF22C55E),
                dateValue: l.t('li1_date'),
                timeValue: l.t('li1_time'),
                sinceValue: l.t('li1_since'),
                tags: [
                  l.t('li1_tags'),
                  l.t('li1_tags2'),
                ],
              ),
              const SizedBox(height: 8),
              _InvestigationCard(
                l: l,
                title: l.t('li2_title'),
                imageAsset: 'assets/images/parfum.jpeg',
                badgeLabel: l.t('li_badge_product'),
                badgeColor: const Color(0xFF60A5FA),
                statusLabel: l.t('li_status_complete'),
                statusColor: const Color(0xFF22C55E),
                confidenceLabel: l.t('li_confidence_high'),
                confidenceValue: '89%',
                confidenceColor: const Color(0xFF22C55E),
                dateValue: l.t('li2_date'),
                timeValue: l.t('li2_time'),
                sinceValue: l.t('li2_since'),
                tags: [
                  l.t('li2_tags'),
                  l.t('li2_tags2'),
                  l.t('li2_tags3'),
                ],
              ),
              const SizedBox(height: 8),
              _InvestigationCard(
                l: l,
                title: l.t('li3_title'),
                imageAsset: 'assets/images/winner.jpeg',
                badgeLabel: l.t('li_badge_brand'),
                badgeColor: const Color(0xFFF4C542),
                statusLabel: l.t('li_status_progress'),
                statusColor: const Color(0xFFF4C542),
                confidenceLabel: l.t('li_confidence_medium'),
                confidenceValue: '65%',
                confidenceColor: const Color(0xFFF4C542),
                dateValue: l.t('li3_date'),
                timeValue: l.t('li3_time'),
                sinceValue: l.t('li3_since'),
                tags: [
                  l.t('li3_tags'),
                  l.t('li3_tags2'),
                  l.t('li3_tags3'),
                ],
              ),
              const SizedBox(height: 8),
              _InvestigationCard(
                l: l,
                title: l.t('li4_title'),
                imageAsset: 'assets/images/mic.jpeg',
                badgeLabel: l.t('li_badge_influencer'),
                badgeColor: const Color(0xFFEC4899),
                statusLabel: l.t('li_status_complete'),
                statusColor: const Color(0xFF22C55E),
                confidenceLabel: l.t('li_confidence_high'),
                confidenceValue: '78%',
                confidenceColor: const Color(0xFF22C55E),
                dateValue: l.t('li4_date'),
                timeValue: l.t('li4_time'),
                sinceValue: l.t('li4_since'),
                tags: [
                  l.t('li4_tags'),
                  l.t('li4_tags2'),
                  l.t('li4_tags3'),
                ],
              ),
              const SizedBox(height: 8),
              _InvestigationCard(
                l: l,
                title: l.t('li5_title'),
                imageAsset: 'assets/images/sauvage.jpeg',
                badgeLabel: l.t('li_badge_product'),
                badgeColor: const Color(0xFF60A5FA),
                statusLabel: l.t('li_status_review'),
                statusColor: const Color(0xFFF4C542),
                confidenceLabel: l.t('li_confidence_high'),
                confidenceValue: '88%',
                confidenceColor: const Color(0xFFF4C542),
                dateValue: l.t('li5_date'),
                timeValue: l.t('li5_time'),
                sinceValue: l.t('li5_since'),
                tags: [
                  l.t('li5_tags'),
                  l.t('li5_tags2'),
                  l.t('li5_tags3'),
                ],
              ),
              const SizedBox(height: 8),
              _InvestigationCard(
                l: l,
                title: l.t('li6_title'),
                imageAsset: 'assets/images/borge.jpeg',
                badgeLabel: l.t('li_badge_brand'),
                badgeColor: const Color(0xFFF4C542),
                statusLabel: l.t('li_status_progress'),
                statusColor: const Color(0xFFF4C542),
                confidenceLabel: l.t('li_confidence_medium'),
                confidenceValue: '60%',
                confidenceColor: const Color(0xFFF4C542),
                dateValue: l.t('li6_date'),
                timeValue: l.t('li6_time'),
                sinceValue: l.t('li6_since'),
                tags: [l.t('li6_tags')],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
//
// Visual order (left → right):
//   [back]  [title]  [search]  [filter w/ badge]  [more]
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BackIcon(),
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
        const _SearchIcon(),
        const SizedBox(width: 8),
        const _FilterIconWithBadge(),
        const SizedBox(width: 8),
        const _MoreIcon(),
      ],
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.maybePop(context),
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
  const _SearchIcon();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {},
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.search,
          color: KashfPalette.active.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _FilterIconWithBadge extends StatelessWidget {
  const _FilterIconWithBadge();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {},
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
                color: KashfPalette.active.textPrimary,
                size: 20,
              ),
            ),
            Positioned(
              right: 0,
              top: 2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KashfColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: KashfPalette.active.background,
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreIcon extends StatelessWidget {
  const _MoreIcon();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {},
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
    final tabs = <_TabSpec>[
      _TabSpec(l.t('li_tab_all'), Icons.layers_outlined),
      _TabSpec(l.t('li_tab_companies'), Icons.apartment_outlined),
      _TabSpec(l.t('li_tab_brands'), Icons.local_offer_outlined),
      _TabSpec(l.t('li_tab_products'), Icons.inventory_2_outlined),
      _TabSpec(l.t('li_tab_influencers'), Icons.person_outline),
      _TabSpec(l.t('li_tab_markets'), Icons.public),
    ];

    // We render chips left → right with the FIRST item on the LEFT
    // (matches the reference screenshot where "All" is highlighted on
    // the left edge). The chip text inside is RTL.
    final children = <Widget>[];
    for (int i = 0; i < tabs.length; i++) {
      children.add(_CategoryChip(
        label: tabs[i].label,
        icon: tabs[i].icon,
        selected: i == selected,
        onTap: () => onSelect(i),
      ));
      if (i != tabs.length - 1) children.add(const SizedBox(width: 8));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
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
//   [Newest first ▾]                                    [Apply 24]
class _SortRow extends StatelessWidget {
  const _SortRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
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
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l.t('li_sort_label'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
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
              l.tp('li_apply_count', {'n': '24'}),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
class _InvestigationCard extends StatelessWidget {
  const _InvestigationCard({
    required this.l,
    required this.title,
    required this.imageAsset,
    required this.badgeLabel,
    required this.badgeColor,
    required this.statusLabel,
    required this.statusColor,
    required this.confidenceLabel,
    required this.confidenceValue,
    required this.confidenceColor,
    required this.dateValue,
    required this.timeValue,
    required this.sinceValue,
    required this.tags,
  });

  final AppLocalizations l;
  final String title;
  final String imageAsset;
  final String badgeLabel;
  final Color badgeColor;
  final String statusLabel;
  final Color statusColor;
  final String confidenceLabel;
  final String confidenceValue;
  final Color confidenceColor;
  final String dateValue;
  final String timeValue;
  final String sinceValue;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            _Thumbnail(imageAsset: imageAsset),
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
                          label: badgeLabel,
                          color: badgeColor,
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
                      title,
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
                          value: timeValue,
                        ),
                        _InlineMetric(
                          icon: Icons.event_outlined,
                          value: dateValue,
                        ),
                        _InlineMetric(
                          icon: Icons.folder_outlined,
                          value: sinceValue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Tag chips (right-aligned, RTL flow).
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
                    label: statusLabel,
                    color: statusColor,
                  ),
                  const Spacer(),
                  Text(
                    confidenceValue,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: confidenceColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      confidenceLabel,
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