import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  /// Index inside [ExploreCategory.values] (0 == All → pill highlighted).
  int _selectedCategory = 0;

  /// Index of the currently visible dot inside the trending carousel.
  int _trendingPage = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF050608),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
                sliver: SliverToBoxAdapter(child: _TopBar(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 6, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _CategoryChipsRow(
                    selected: _selectedCategory,
                    onChanged: (i) => setState(() => _selectedCategory = i),
                    l: l,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _TrendingSectionHeader(
                    title: l.t('explore_trending_title'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _TrendingCarousel(
                    onPageChanged: (i) => setState(() => _trendingPage = i),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: _DotsIndicator(count: 4, index: _trendingPage),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverSectionHeader(
                    title: l.t('explore_discover_title'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                sliver: SliverToBoxAdapter(child: _DiscoverGrid(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _RecentSectionHeader(
                    title: l.t('explore_recent_title'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 32),
                sliver: SliverToBoxAdapter(
                  child: _RecentInvestigationsList(
                    items: [
                      _RecentInvestigationItem(
                        brandAsset: 'assets/images/parfum.jpeg',
                        title: l.t('explore_recent1_title'),
                        subtitle: l.t('explore_recent1_sub'),
                        time: l.t('explore_recent1_time'),
                        statusLabel: l.t('explore_recent_complete'),
                        statusStyle: _StatusStyle.completed,
                      ),
                      _RecentInvestigationItem(
                        brandAsset: 'assets/images/sauvage.jpeg',
                        title: l.t('explore_recent2_title'),
                        subtitle: l.t('explore_recent2_sub'),
                        time: l.t('explore_recent2_time'),
                        statusLabel: l.t('explore_recent_add'),
                        statusStyle: _StatusStyle.quickAnswer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar
// ============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Mirror-friendly row: Directionality flips start/end in RTL.
    // LTR visual:  [filter] ──spacer── [title]
    // RTL visual:  [title] ──spacer── [filter]
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.t('nav_explore'),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: KashfColors.gold, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_alt_outlined,
                color: KashfColors.gold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Category filter chips
// ============================================================================

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.selected,
    required this.onChanged,
    required this.l,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Hand-picked visual order so "All" pill lands on the trailing side
    // (right in LTR, left in RTL) once ListView + Directionality flips it.
    const ordered = <ExploreCategory>[
      ExploreCategory.influencers,
      ExploreCategory.brands,
      ExploreCategory.beauty,
      ExploreCategory.products,
      ExploreCategory.markets,
      ExploreCategory.all,
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: l.isRtl,
        padding: EdgeInsets.zero,
        itemCount: ordered.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = ordered[i];
          final picked = c.valueIndex == selected;
          return _CategoryChip(
            icon: c.icon,
            label: c.label(l),
            selected: picked,
            onTap: () => onChanged(c.valueIndex),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? KashfColors.gold : const Color(0xFF2A2D38),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? KashfColors.gold : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? KashfColors.gold : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================
// Trending topics carousel
// ============================================================================

class _TrendingCarousel extends StatefulWidget {
  const _TrendingCarousel({required this.onPageChanged});
  final ValueChanged<int> onPageChanged;

  @override
  State<_TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<_TrendingCarousel> {
  static const _items = <_TrendingItem>[
    _TrendingItem(
      asset: 'assets/images/winner.jpeg',
      titleEn: 'Commodity analysis',
      titleAr: 'تحليل السلع',
      subtitleEn: 'Gold and oil',
      subtitleAr: 'الذهب والنفط',
    ),
    _TrendingItem(
      asset: 'assets/images/sauvage.jpeg',
      titleEn: 'Market news',
      titleAr: 'أخبار السوق',
      subtitleEn: 'Top economic headlines',
      subtitleAr: 'أبرز العناوين الاقتصادية',
    ),
    _TrendingItem(
      asset: 'assets/images/mic.jpeg',
      titleEn: 'Investor portfolio',
      titleAr: 'محفظة المستثمر',
      subtitleEn: 'Risk and reward management',
      subtitleAr: 'إدارة المخاطر والعوائد',
    ),
    _TrendingItem(
      asset: 'assets/images/borge.jpeg',
      titleEn: 'Highest influencer',
      titleAr: 'أعلى المؤثرين',
      subtitleEn: 'Top of the year',
      subtitleAr: 'لعام كامل',
    ),
  ];

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_recomputeActive);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_recomputeActive)
      ..dispose();
    super.dispose();
  }

  void _recomputeActive() {
    if (!_scroll.hasClients) return;
    const outerH = 20.0;
    const inner = 12.0;
    const visibleCount = 3;
    final width = MediaQuery.of(context).size.width;
    final cardW =
        (width - (outerH * 2) - (inner * (visibleCount - 1))) / visibleCount;
    final stride = cardW + inner;
    final x = _scroll.position.pixels;
    // Find the card whose center is closest to the viewport center.
    final center = x + width / 2;
    final raw = ((center - outerH - cardW / 2) / stride).round();
    final idx = raw.clamp(0, _items.length - 1);
    widget.onPageChanged(idx);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    // Card width: fit 3 cards side-by-side minus outer side margins and
    // inner spacing — 4th+ cards become reachable via scroll.
    const outerH = 20.0;
    const inner = 12.0;
    const visibleCount = 3;
    final cardWidth =
        (width - (outerH * 2) - (inner * (visibleCount - 1))) / visibleCount;

    return SizedBox(
      height: 210,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(outerH, 0, outerH, 0),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: inner),
        itemBuilder: (_, i) {
          final it = _items[i];
          final title = l.isRtl ? it.titleAr : it.titleEn;
          final subtitle = l.isRtl ? it.subtitleAr : it.subtitleEn;
          return _TrendingCard(
            asset: it.asset,
            title: title,
            subtitle: subtitle,
            width: cardWidth,
          );
        },
      ),
    );
  }
}

class _TrendingItem {
  const _TrendingItem({
    required this.asset,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
  });
  final String asset;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.width,
  });
  final String asset;
  final String title;
  final String subtitle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFF171A20),
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Image at top - fills card width with rounded TOP corners.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 130,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF0E0F14),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: 28,
                    color: const Color(0xFF8A8F9C),
                  ),
                ),
              ),
            ),
            // Bottom content area (dark card) with text + share icon.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 130,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9AA0A6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    // Small chart icon (line graph + arrow) — no background
                    // container; pinned to the LEFT visual edge via
                    // [centerEnd] alignment under the outer RTL row.
                    const SizedBox(height: 9),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: const Icon(
                        Icons.trending_up,
                        color: Color(0xFFD4A33A),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header specific to Trending — small gold trending icon on the
/// left, followed by the title text. Pinned to the LEFT side of the
/// screen via Directionality so the icon stays visually to the left of
/// the title regardless of the app's locale direction.
class _TrendingSectionHeader extends StatelessWidget {
  const _TrendingSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, color: const Color(0xFFD4A33A), size: 20),
              const SizedBox(width: 6),

              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Page indicator (4 dots)
// ============================================================================

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? KashfColors.gold : const Color(0xFF2A2D38),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Discover-by-medium 2×2 grid
// ============================================================================

class _DiscoverSectionHeader extends StatelessWidget {
  const _DiscoverSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Sparkle icon followed by the title, both left-aligned on the
    // leading edge of the screen. Wrapped in Directionality(LTR) so the
    // icon always sits to the LEFT of the title regardless of locale.
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: const Color(0xFFD4A33A),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverGrid extends StatelessWidget {
  const _DiscoverGrid({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_DiscoverItem>[
      _DiscoverItem(
        icon: Icons.business_outlined,
        title: l.t('explore_discover_companies_title'),
        subtitle: l.t('explore_discover_companies_sub'),
      ),
      _DiscoverItem(
        icon: Icons.link_outlined,
        title: l.t('explore_discover_products_title'),
        subtitle: l.t('explore_discover_products_sub'),
      ),
      _DiscoverItem(
        icon: Icons.people_outline,
        title: l.t('explore_discover_influencers_title'),
        subtitle: l.t('explore_discover_influencers_sub'),
      ),
      _DiscoverItem(
        icon: Icons.description_outlined,
        title: l.t('explore_discover_reports_title'),
        subtitle: l.t('explore_discover_reports_sub'),
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _DiscoverTile(item: items[0])),
            const SizedBox(width: 14),
            Expanded(child: _DiscoverTile(item: items[1])),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _DiscoverTile(item: items[2])),
            const SizedBox(width: 14),
            Expanded(child: _DiscoverTile(item: items[3])),
          ],
        ),
      ],
    );
  }
}

class _DiscoverItem {
  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({required this.item});
  final _DiscoverItem item;

  // Color tokens pinned exactly to the reference spec.
  static const _cardFill = Color(0xFF171A20);
  static const _cardBorder = Color(0xFF26282E);
  static const _iconCircleFill = Color(0xFF1F2128);
  static const _iconGold = Color(0xFFD4A33A);
  static const _chevronColor = Color(0xFF6B6F76);
  static const _secondaryText = Color(0xFF9AA0A6);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: TextDirection.ltr,
        children: [
          // Circular dark icon container (24px icon inside ~38px circle).
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _iconCircleFill,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: _iconGold, size: 24),
          ),
          const SizedBox(width: 10),
          // Title + description stacked.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Right-side chevron pinned to the far right, vertically centered.
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 2),
            child: Icon(Icons.chevron_left, color: _chevronColor, size: 20),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ============================================================================
// Recent investigations (Dior + Tom Ford rows) — single container list.
// ============================================================================

/// Section header for "تحقيقات حديثة" — outlined history icon + title,
/// right-aligned on the RTL leading edge.
class _RecentSectionHeader extends StatelessWidget {
  const _RecentSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Pinned to the RIGHT edge of the screen via [start] alignment under
    // the outer RTL Directionality (the row reads right→left, so [start]
    // = visual right). The icon is wrapped in a forced LTR Row so it
    // always sits to the LEFT of the title.
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_outlined,
                color: const Color(0xFFD4A33A),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visual style for a status badge on a recent investigation row.
enum _StatusStyle { completed, quickAnswer }

class _StatusPalette {
  const _StatusPalette({
    required this.bg,
    required this.fg,
    required this.icon,
  });
  final Color bg;
  final Color fg;
  final IconData icon;
}

class _RecentInvestigationItem {
  const _RecentInvestigationItem({
    required this.brandAsset,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.statusLabel,
    required this.statusStyle,
  });
  final String brandAsset;
  final String title;
  final String subtitle;
  final String time;
  final String statusLabel;
  final _StatusStyle statusStyle;
}

class _RecentInvestigationsList extends StatelessWidget {
  const _RecentInvestigationsList({required this.items});
  final List<_RecentInvestigationItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26282E), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _RecentInvestigationRow(item: items[i]),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 12, end: 12),
                child: Divider(
                  color: Color(0xFF26282E),
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentInvestigationRow extends StatelessWidget {
  const _RecentInvestigationRow({required this.item});
  final _RecentInvestigationItem item;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(item.statusStyle);

    // Single horizontal row. Honours the screen's outer Directionality so
    // Forced LTR direction so that the source order
    //   [Time] [Badge] [Title] [Image] [Menu]
    // renders visually left→right as
    //   [Time] [Badge] [Title] [Image] [Menu]
    // regardless of the screen's outer RTL Directionality.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Time — far left.
            SizedBox(
              width: 64,
              child: Text(
                item.time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            // 2. Status pill — immediately to the right of time.
            const SizedBox(width: 10),
            _StatusPill(label: item.statusLabel, palette: palette),
            // 3. Title + subtitle (Expanded) — center-right.
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // 4. Brand image — to the right of the title block.
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                color: const Color(0xFF0E0F14),
                alignment: Alignment.center,
                child: Image.asset(
                  item.brandAsset,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.branding_watermark_outlined,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            // 5. Three-dot menu — far right, 10–12 px from the image.
            const SizedBox(width: 10),
            const Icon(Icons.more_vert, color: Color(0xFF8A8A8A), size: 18),
          ],
        ),
      ),
    );
  }

  static _StatusPalette _paletteFor(_StatusStyle s) {
    switch (s) {
      case _StatusStyle.completed:
        return const _StatusPalette(
          bg: Color(0xFF103C26),
          fg: Color(0xFF3DDC84),
          icon: Icons.check,
        );
      case _StatusStyle.quickAnswer:
        return const _StatusPalette(
          bg: Color(0xFF112B45),
          fg: Color(0xFF4DA3FF),
          icon: Icons.bolt_outlined,
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.palette});
  final String label;
  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(7, 4, 7, 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(palette.icon, size: 11, color: palette.fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Categories enum + helpers (kept at the bottom so the build() method
// reads top-to-bottom like a story).
// ============================================================================

enum ExploreCategory {
  markets,
  products,
  beauty,
  brands,
  influencers,
  all;

  int get valueIndex => values.indexOf(this);

  IconData get icon => switch (this) {
    ExploreCategory.markets => Icons.show_chart_outlined,
    ExploreCategory.products => Icons.inventory_2_outlined,
    ExploreCategory.beauty => Icons.spa_outlined,
    ExploreCategory.brands => Icons.shopping_bag_outlined,
    ExploreCategory.influencers => Icons.person_outline,
    ExploreCategory.all => Icons.apps_rounded,
  };

  String label(AppLocalizations l) => switch (this) {
    ExploreCategory.markets => l.t('explore_filter_markets'),
    ExploreCategory.products => l.t('explore_filter_products'),
    ExploreCategory.beauty => l.t('explore_filter_beauty'),
    ExploreCategory.brands => l.t('explore_filter_brands'),
    ExploreCategory.influencers => l.t('explore_filter_influencers'),
    ExploreCategory.all => l.t('explore_filter_all'),
  };
}
