import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// The Explore workspace. Layout mirrors the marketing reference:
/// top bar with greeting + filter button, search bar, category chips,
/// 6 entity-tile cards with stats, recent updates list, and a
/// "Suggested for you" / "Now trending" section.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tabs = <_Tab>[
      _Tab(Icons.grid_view_rounded, l.t('explore_tab_all')),
      _Tab(Icons.business_outlined, l.t('explore_tab_companies')),
      _Tab(Icons.label_outline, l.t('explore_tab_brands')),
      _Tab(Icons.inventory_2_outlined, l.t('explore_tab_products')),
      _Tab(Icons.person_outline, l.t('explore_tab_influencers')),
      _Tab(Icons.show_chart_outlined, l.t('explore_tab_markets')),
    ];
    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(child: _TopBar(l: l)),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(child: _Header(l: l)),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(
                  controller: _searchCtrl,
                  hint: l.t('explore_search_hint'),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _TabsRow(
                  tabs: tabs,
                  current: _tab,
                  onChange: (i) => setState(() => _tab = i),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 200,
                ),
                itemCount: 6,
                itemBuilder: (_, i) => _CategoryCard(index: i, l: l),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: l.t('explore_recent'),
                  trailing: l.t('explore_view_all'),
                  onTrailing: () {},
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              sliver: SliverList.builder(
                itemCount: 3,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _RecentUpdateRow(index: i, l: l),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: l.t('explore_suggested'),
                  trailing: l.t('explore_view_all'),
                  onTrailing: () {},
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      _SuggestedTile(index: i, l: l),
                      if (i != 3) SizedBox(height: 10),
                    ],
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

// ===================== Top Bar =====================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KashfLogo(width: 56),
        Spacer(),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KashfPalette.active.surface,
            border: Border.all(color: KashfColors.gold, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person, color: KashfColors.gold, size: 20),
        ),
      ],
    );
  }
}

// ===================== Header (Title) =====================
class _Header extends StatelessWidget {
  const _Header({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: l.isRtl
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          l.t('explore_title'),
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          l.t('explore_subtitle'),
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ===================== Search Bar =====================
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: KashfPalette.active.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: KashfColors.gold, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
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
          ),
        ),
        SizedBox(width: 8),
        Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune, color: KashfColors.gold, size: 18),
              SizedBox(height: 2),
              Text(
                localizedText(context, 'explore_filter'),
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Workaround: bottom-sheet builders lose the AppLocalizations widget, so
// keep helper that resolves the localizations via the build context.
String localizedText(BuildContext context, String key) =>
    AppLocalizations.of(context).t(key);

// ===================== Tabs Row =====================
class _Tab {
  const _Tab(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.tabs,
    required this.current,
    required this.onChange,
  });
  final List<_Tab> tabs;
  final int current;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == current;
          return GestureDetector(
            onTap: () => onChange(i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? KashfColors.gold.withValues(alpha: 0.18)
                    : KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? KashfColors.gold
                      : KashfPalette.active.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tabs[i].icon,
                    color: selected
                        ? KashfColors.gold
                        : KashfPalette.active.textSecondary,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    tabs[i].label,
                    style: TextStyle(
                      color: selected
                          ? KashfColors.gold
                          : KashfPalette.active.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===================== Section Header =====================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              trailing!,
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ===================== Category Card =====================
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.index, required this.l});
  final int index;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Order matches the reference image:
    // 0=Influencers, 1=Companies, 2=Markets,
    // 3=Products, 4=Hot tags, 5=Content.
    final data = <_CategoryData>[
      _CategoryData(
        title: l.t('explore_category_users'),
        subtitle: l.t('explore_category_users_sub'),
        icon: Icons.people_outline,
        bg: Color(0xFF6F3AFF),
        stats: [
          _Stat('2.1K', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('178', l.t('explore_stat_new'), Color(0xFF22C55E)),
          _Stat('24', l.t('explore_stat_active'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '35'}),
      ),
      _CategoryData(
        title: l.t('explore_category_companies'),
        subtitle: l.t('explore_category_companies_sub'),
        icon: Icons.business_outlined,
        bg: Color(0xFF1F5DFF),
        stats: [
          _Stat('1.4K', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('86', l.t('explore_stat_new'), Color(0xFF22C55E)),
          _Stat('31', l.t('explore_stat_active'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '1'}),
      ),
      _CategoryData(
        title: l.t('explore_category_markets'),
        subtitle: l.t('explore_category_markets_sub'),
        icon: Icons.bar_chart,
        bg: Color(0xFF1FAE5C),
        stats: [
          _Stat('12', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('5', l.t('explore_stat_new'), Color(0xFF22C55E)),
          _Stat('3', l.t('explore_stat_active'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '0.25'}),
      ),
      _CategoryData(
        title: l.t('explore_category_products'),
        subtitle: l.t('explore_category_products_sub'),
        icon: Icons.inventory_2_outlined,
        bg: Color(0xFFFB923C),
        stats: [
          _Stat('3.2K', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('247', l.t('explore_stat_new'), Color(0xFF22C55E)),
          _Stat('58', l.t('explore_stat_active'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '15'}),
      ),
      _CategoryData(
        title: l.t('explore_category_tags'),
        subtitle: l.t('explore_category_tags_sub'),
        icon: Icons.sell_outlined,
        bg: Color(0xFFEC4899),
        stats: [
          _Stat('892', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('39', l.t('explore_stat_new'), Color(0xFF22C55E)),
          _Stat('16', l.t('explore_stat_active'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '40'}),
      ),
      _CategoryData(
        title: l.t('explore_category_content'),
        subtitle: l.t('explore_category_content_sub'),
        icon: Icons.mic_none,
        bg: Color(0xFF0EA5E9),
        stats: [
          _Stat('1.8K', l.t('explore_stat_accounts'), KashfColors.gold),
          _Stat('312', l.t('explore_views'), Color(0xFF22C55E)),
          _Stat('97', l.t('explore_likes'), Color(0xFFEF4444)),
        ],
        ago: l.tp('explore_update_hours', {'n': '20'}),
      ),
    ][index];

    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + mini chart line.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: data.bg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(data.icon, color: data.bg, size: 18),
                ),
                SizedBox(width: 8),
                Expanded(child: _MiniChart(color: data.bg)),
              ],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              data.title,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              data.subtitle,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacer(),
          // Stats row.
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: KashfPalette.active.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (var i = 0; i < data.stats.length; i++) ...[
                  Expanded(child: _StatColumn(stat: data.stats[i])),
                  if (i != data.stats.length - 1)
                    Container(
                      width: 1,
                      height: 24,
                      color: KashfPalette.active.cardBorder,
                    ),
                ],
              ],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data.ago,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DirectionalChevron(
                  color: KashfPalette.active.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryData {
  const _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.stats,
    required this.ago,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final List<_Stat> stats;
  final String ago;
}

class _Stat {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: TextStyle(
            color: stat.color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2),
        Text(
          stat.label,
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: CustomPaint(
        size: const Size(double.infinity, 36),
        painter: _ChartPainter(color),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Sample points (0..1) chosen to mimic the marketing reference —
    // a single dramatic peak, a dip, and a smaller recovery.
    final points = [0.85, 0.55, 0.95, 0.32, 0.62, 0.20, 0.48, 0.30, 0.55];
    final stepX = size.width / (points.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(i * stepX, size.height * points[i]),
    ];

    // Build a smooth path using cubic beziers between every pair of
    // sample points. The control points sit on the horizontal axis
    // halfway between neighbors with a small vertical pull — this
    // gives the easy-flowing curve in the reference image.
    final curve = Path();
    curve.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      curve.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // 1) Subtle filled area under the curve to add depth.
    final fillPath = Path.from(curve)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 2) Soft blurred under-glow line for "tiny stroke + halo" feel.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 0.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(curve, glowPaint);

    // 3) Solid trend line on top.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(curve, linePaint);

    // 4) Highlight the last sample point as a small dot.
    final last = pts.last;
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(last, 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ===================== Recent Update Row =====================
class _RecentUpdateRow extends StatelessWidget {
  const _RecentUpdateRow({required this.index, required this.l});
  final int index;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_RecentItem>[
      _RecentItem(
        icon: Icons.local_florist,
        coverColors: const [Color(0xFF7B5A2B), Color(0xFF2D2418)],
        title: l.t('explore_trend_perfume'),
        ago: l.tp('explore_trend_perfume_h', {'n': '25'}),
        status: l.t('explore_brand_active'),
        statusColor: Color(0xFF22C55E),
        stats: [
          _EngStat('48', Icons.fingerprint),
          _EngStat('12', Icons.bar_chart),
          _EngStat('35', Icons.chat_bubble_outline),
        ],
      ),
      _RecentItem(
        icon: Icons.person_outline,
        coverColors: const [Color(0xFF3A2E25), Color(0xFF1A1A1A)],
        title: l.t('explore_trend_influencer'),
        ago: l.tp('explore_trend_influencer_h', {'n': '8'}),
        status: l.t('explore_brand_new'),
        statusColor: KashfColors.gold,
        stats: [
          _EngStat('32', Icons.fingerprint),
          _EngStat('8', Icons.bar_chart),
          _EngStat('21', Icons.chat_bubble_outline),
        ],
      ),
      _RecentItem(
        icon: Icons.location_city_outlined,
        coverColors: const [Color(0xFF2A2F36), Color(0xFF0E1014)],
        title: l.t('explore_trend_competitor'),
        ago: l.tp('explore_trend_competitor_h', {'n': '5'}),
        status: l.t('explore_trend_competitor_status'),
        statusColor: Color(0xFFEF4444),
        stats: [
          _EngStat('60', Icons.fingerprint),
          _EngStat('15', Icons.bar_chart),
          _EngStat('40', Icons.chat_bubble_outline),
        ],
      ),
    ][index];
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: items.coverColors,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              items.icon,
              color: KashfColors.gold.withValues(alpha: 0.85),
              size: 24,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: items.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        items.status,
                        style: TextStyle(
                          color: items.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < items.stats.length; i++) ...[
                      _EngagementStat(stat: items.stats[i]),
                      if (i != items.stats.length - 1) SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          Icon(
            Icons.more_horiz,
            color: KashfPalette.active.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _RecentItem {
  const _RecentItem({
    required this.icon,
    required this.coverColors,
    required this.title,
    required this.ago,
    required this.status,
    required this.statusColor,
    required this.stats,
  });
  final IconData icon;
  final List<Color> coverColors;
  final String title;
  final String ago;
  final String status;
  final Color statusColor;
  final List<_EngStat> stats;
}

class _EngStat {
  const _EngStat(this.value, this.icon);
  final String value;
  final IconData icon;
}

class _EngagementStat extends StatelessWidget {
  const _EngagementStat({required this.stat});
  final _EngStat stat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(stat.icon, color: KashfPalette.active.textSecondary, size: 12),
        SizedBox(width: 4),
        Text(
          stat.value,
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ===================== Suggested Tile =====================
class _SuggestedTile extends StatelessWidget {
  const _SuggestedTile({required this.index, required this.l});
  final int index;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_SuggestedItem>[
      _SuggestedItem(
        icon: Icons.brush_outlined,
        coverColors: const [Color(0xFF2A2F36), Color(0xFF0E1014)],
        title: l.t('explore_suggested_sauvage'),
        subtitle: l.tp('explore_suggested_sauvage_h', {'p': '48'}),
        statusColor: KashfColors.gold,
      ),
      _SuggestedItem(
        icon: Icons.check,
        coverColors: const [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
        title: l.t('explore_suggested_nike'),
        subtitle: l.t('explore_suggested_nike_h'),
        statusColor: Color(0xFF22C55E),
      ),
      _SuggestedItem(
        icon: Icons.local_fire_department,
        coverColors: const [Color(0xFF7B5A2B), Color(0xFF2D2418)],
        title: l.t('explore_suggested_lattafa'),
        subtitle: l.tp('explore_suggested_lattafa_h', {'p': '32'}),
        statusColor: Color(0xFF22C55E),
      ),
      _SuggestedItem(
        icon: Icons.eco_outlined,
        coverColors: const [Color(0xFF1FAE5C), Color(0xFF0E3A24)],
        title: l.t('explore_suggested_herbal'),
        subtitle: l.t('explore_suggested_herbal_h'),
        statusColor: Color(0xFF22C55E),
      ),
    ][index];
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: items.coverColors,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              items.icon,
              color: KashfColors.gold.withValues(alpha: 0.85),
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: items.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        items.subtitle,
                        style: TextStyle(
                          color: items.statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.star_border,
            color: KashfPalette.active.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _SuggestedItem {
  const _SuggestedItem({
    required this.icon,
    required this.coverColors,
    required this.title,
    required this.subtitle,
    required this.statusColor,
  });
  final IconData icon;
  final List<Color> coverColors;
  final String title;
  final String subtitle;
  final Color statusColor;
}
