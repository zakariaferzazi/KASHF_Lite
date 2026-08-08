import 'dart:math' as math;
import 'package:syncfusion_flutter_charts/charts.dart'
    show NumericAxis, SfCartesianChart, SplineAreaSeries, SplineSeries, SplineType;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import '../../services/ai/ai_text_utils.dart';
import '../../services/ai/chart_axis.dart';
import '../../services/ai/market_data_controller.dart';
import '../../services/ai/market_models.dart';
import '../../services/ai/logo_service.dart';

/// "Market Pulse" screen — a strict, pixel-perfect clone of the
/// reference screenshot. Layout (top → bottom):
///   1. Top bar (back arrow + title + help + 3-dot menu + refresh)
///   2. Live status row (green dot + "last updated")
///   3. Tab bar (Overview | Campaigns | Brands | Products | Influencers)
///   4. 4 KPI cards (total posts, total tweets, dominance, activity)
///   5. Two side-by-side charts (line trend + source donut)
///   6. "Most traded topics" section (5 horizontal cards)
///   7. "Fastest growing brands" section (5 horizontal cards)
///   8. "Most important current events" section (3 news rows)
///   9. Action buttons row (compare / watchlist / start investigation)
///
/// As of the OpenRouter integration, the KPI cards, donut,
/// trend line, topics, brands, and events are populated from
/// [MarketDataController]. The user must tap the refresh icon
/// in the top bar to fetch fresh data; the initial paint
/// renders the demo data with no API call.
///
/// The screen is fully RTL-aware and reacts to the active palette
/// from [KashfPalette.active].
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  int _tabIndex = 0;
  late final MarketDataController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MarketDataController();
    _controller.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      _controller.bootstrap(
        language: l.language.code,
        region: 'Kuwait',
      );
    });
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 96),
            children: [
              _TopBar(
                l: l,
                isRefreshing: _controller.isLoading,
                onRefresh: () => _controller.refreshNow(
                  language: l.language.code,
                ),
              ),
              const SizedBox(height: 6),
              _LastUpdated(l: l),
              const SizedBox(height: 6),
              _TabBar(
                index: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
                l: l,
              ),
              const SizedBox(height: 6),
              _KpiRow(
                l: l,
                data: _controller.state.data,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 8),
              _ChartsRow(
                l: l,
                data: _controller.state.data,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 8),
              _SectionHeader(
                title: l.t('mp_section_topics'),
              ),
              const SizedBox(height: 4),
              _TopicsRow(
                l: l,
                data: _controller.state.data,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 8),
              _SectionHeader(
                title: l.t('mp_section_brands'),
              ),
              const SizedBox(height: 4),
              _BrandsRow(
                l: l,
                data: _controller.state.data,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 8),
              _SectionHeader(
                title: l.t('mp_section_events'),
              ),
              const SizedBox(height: 4),
              _EventsList(
                l: l,
                data: _controller.state.data,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.l,
    required this.isRefreshing,
    required this.onRefresh,
  });
  final AppLocalizations l;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    // Visual order (left → right) should be:
    //   [back]  [title]  [refresh]  [help]  [more]
    // In an RTL Row, the first child renders on the right, so the data
    // order is reversed: [more, help, refresh, title, back].
    return Row(
      children: [
        _IconCircle(
          icon: Icons.more_horiz,
          onTap: () {},
          size: 16,
        ),
        const SizedBox(width: 6),
        _IconCircle(
          icon: Icons.help_outline,
          onTap: () {},
          size: 16,
        ),
        const SizedBox(width: 6),
        _RefreshIcon(
          isLoading: isRefreshing,
          onTap: isRefreshing ? null : onRefresh,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.t('mp_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _IconCircle(
          icon: Icons.arrow_forward_ios,
          onTap: () => Navigator.maybePop(context),
          size: 14,
        ),
      ],
    );
  }
}

/// Round gold-bordered refresh button matching the home screen
/// refresh icon. Spins while a fetch is in flight and ignores
/// taps so the user cannot double-fire.
class _RefreshIcon extends StatelessWidget {
  const _RefreshIcon({
    required this.isLoading,
    required this.onTap,
  });
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KashfPalette.active.surface,
          border: Border.all(color: KashfColors.gold.withValues(alpha: 0.55)),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation(KashfColors.gold),
                ),
              )
            : const Icon(
                Icons.refresh_rounded,
                color: KashfColors.gold,
                size: 16,
              ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onTap,
    this.size = 16,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KashfPalette.active.surface,
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: KashfPalette.active.textPrimary,
          size: size,
        ),
      ),
    );
  }
}

// ============================ Last Updated ============================
class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0),
      child: Row(
        children: [
          Text(
            l.t('mp_updated'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Tab Bar ============================
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.onChanged,
    required this.l,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Five tabs in the reference: overview, campaigns, brands, products,
    // influencers. Active tab uses brand gold + underline indicator.
    final labels = <String>[
      l.t('mp_tab_overview'),
      l.t('mp_tab_campaigns'),
      l.t('mp_tab_brands'),
      l.t('mp_tab_products'),
      l.t('mp_tab_influencers'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (_, i) {
          final selected = i == index;
          // Underline indicator width matches the label width.
          return InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    color: selected
                        ? KashfColors.gold
                        : KashfPalette.active.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2,
                  width: selected ? 22 : 0,
                  decoration: BoxDecoration(
                    color: KashfColors.gold,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================ KPI Cards ============================
class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // When AI data is available we use it directly; otherwise we
    // render the original localized demo cards so the layout
    // never changes. Order is reversed so when rendered in an
    // RTL Row (which mirrors children left↔right), the visual
    // left-to-right order matches the reference screenshot:
    // posts → tweets → dominance → activity.
    final List<_KpiData> cards;
    if (data != null && data!.kpis.length >= 4) {
      // Reverse the AI list (which is in the same order as the
      // schema: posts, tweets, dominance, activity) so the RTL
      // Row puts them in the visual order activity → dominance
      // → tweets → posts.
      final ordered = data!.kpis.take(4).toList().reversed.toList();
      cards = ordered.map((k) {
        return _KpiData(
          label: k.label,
          value: k.value,
          sub: k.sub,
          delta: k.delta,
          positive: k.positive,
          isActivity: k.id == 'activity',
        );
      }).toList();
    } else {
      cards = <_KpiData>[
        _KpiData(
          label: l.t('mp_kpi_activity'),
          value: l.t('mp_kpi_high'),
          sub: l.t('mp_kpi_currently'),
          delta: '',
          positive: true,
          isActivity: true,
        ),
        _KpiData(
          label: l.t('mp_kpi_dominance'),
          value: '12%',
          sub: l.t('mp_kpi_24h'),
          delta: '-6%',
          positive: false,
        ),
        _KpiData(
          label: l.t('mp_kpi_tweets'),
          value: '24.7M',
          sub: l.t('mp_kpi_24h'),
          delta: '+18%',
          positive: true,
        ),
        _KpiData(
          label: l.t('mp_kpi_posts'),
          value: '128.4K',
          sub: l.t('mp_kpi_24h'),
          delta: '+24%',
          positive: true,
        ),
      ];
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _KpiCard(data: cards[i])),
        ],
      ],
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.sub,
    required this.delta,
    required this.positive,
    this.isActivity = false,
  });
  final String label;
  final String value;
  final String sub;
  final String delta;
  final bool positive;
  final bool isActivity;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final deltaColor = data.positive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top header row. Activity cards show a centered dash; other
          // cards show a small delta (with arrow). Both branches are
          // wrapped in the same fixed-height row so all four cards line
          // up exactly — regardless of which header is shown.
          SizedBox(
            height: 14,
            child: data.isActivity
                ? const _DashIndicator()
                : data.delta.isNotEmpty
                    ? Row(
                        children: [
                          Icon(
                            data.positive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: deltaColor,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            data.delta,
                            style: TextStyle(
                              color: deltaColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
          ),
          if (data.delta.isNotEmpty) const SizedBox(height: 6),
          Text(
            data.label,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              data.value,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.sub,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Small horizontal dash indicator shown at the top of the activity
/// card (replaces the delta arrow used by the other KPI cards).
class _DashIndicator extends StatelessWidget {
  const _DashIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 14,
        height: 2,
        decoration: BoxDecoration(
          color: KashfPalette.active.textSecondary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ============================ Charts Row ============================
class _ChartsRow extends StatelessWidget {
  const _ChartsRow({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Wrap the Row in IntrinsicHeight so the cross-axis stretch has a
    // bounded height (the natural height of the tallest child). This
    // is required when the row lives inside a vertically-scrolling
    // parent like a [ListView], which gives unbounded vertical
    // constraints to its children.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // In RTL Row the first child renders on the right, so we list
          // them in reference visual order (left → right): trend first,
          // donut second. This puts the donut on the right, matching the
          // reference.
          Expanded(
            flex: 4,
            child: _DonutCard(
              l: l,
              data: data,
              isLoading: isLoading,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _LineChartCard(
              l: l,
              data: data,
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Resolve trend points. Falls back to the original demo shape
    // (sharp rise to the right) when AI data is unavailable.
    final List<MarketTrendPoint> trendPoints = (data != null &&
            data!.trend.length >= 2)
        ? data!.trend
        : const [
            MarketTrendPoint(label: 'D7', value: 4500),
            MarketTrendPoint(label: 'D6', value: 5200),
            MarketTrendPoint(label: 'D5', value: 6800),
            MarketTrendPoint(label: 'D4', value: 8400),
            MarketTrendPoint(label: 'D3', value: 11200),
            MarketTrendPoint(label: 'D2', value: 15800),
            MarketTrendPoint(label: 'D1', value: 22400),
          ];

    // Derive the effective yMax from the actual data so the line
    // always fills the chart area. We start with the AI's yMax as
    // a hint, then fall back to the data's max with 15% headroom.
    // This makes the chart robust to under-sized AI estimates
    // (e.g. AI returns yMax=25K but the data sits at 3K-8K, which
    // would otherwise collapse the line near the bottom).
    final dataMax = trendPoints
        .map((p) => p.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final aiMax = (data != null && data!.trendYMax > 0)
        ? data!.trendYMax
        : 0.0;
    final effectiveYMax = ChartAxis.deriveYMax(
      aiMax: aiMax,
      dataMax: dataMax,
    );
    final yLabels = ChartAxis.yAxisLabels(effectiveYMax);

    // X-axis labels: pick up to 4 evenly spaced labels from the
    // trend points so the labels map to actual points.
    final xLabelCount = trendPoints.length >= 4 ? 4 : trendPoints.length;
    final xIndices = <int>[];
    for (var i = 0; i < xLabelCount; i++) {
      final idx = (i * (trendPoints.length - 1) / (xLabelCount - 1))
          .clamp(0, trendPoints.length - 1)
          .round();
      xIndices.add(idx);
    }

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t('mp_chart_trend'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
                decoration: BoxDecoration(
                  color: KashfPalette.active.fieldFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.expand_more,
                      color: KashfPalette.active.textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      l.t('mp_chart_days'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Sparkline(
                    color: const Color(0xFF22C55E),
                    points: _normalizeToUnit(trendPoints, effectiveYMax),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 28,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final t in yLabels) _YLabel(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final idx in xIndices) _XLabel(trendPoints[idx].label),
            ],
          ),
        ],
      ),
    );
  }

  // Y-axis labels are produced by [ChartAxis.yAxisLabels] in
  // `lib/services/ai/chart_axis.dart` (extracted so the logic is
  // unit-testable in isolation).

  /// Normalizes real-valued [points] (e.g. 4K, 8K, 12K) to the
  /// 0..1 range expected by [_Sparkline]. We use the same
  /// [effectiveYMax] we already computed so the visual height
  /// matches the Y-axis labels on the side.
  static List<double> _normalizeToUnit(
    List<MarketTrendPoint> points,
    double yMax,
  ) {
    if (points.isEmpty) return const [];
    if (yMax <= 0) {
      // Fall back to the data's own max with a touch of headroom.
      final max = points
          .map((p) => p.value)
          .fold<double>(0, (a, b) => a > b ? a : b);
      if (max <= 0) return points.map((_) => 0.0).toList();
      return points.map((p) => (p.value / max).clamp(0.0, 1.0)).toList();
    }
    return points
        .map((p) => (p.value / yMax).clamp(0.0, 1.0))
        .toList();
  }
}

class _YLabel extends StatelessWidget {
  const _YLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: KashfPalette.active.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _XLabel extends StatelessWidget {
  const _XLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: KashfPalette.active.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ============================ Donut Chart ============================
class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Resolve source segments. Fall back to localized demo values.
    final List<MarketSourceSegment> segments =
        (data != null && data!.sources.length >= 3)
            ? data!.sources.take(3).toList()
            : <MarketSourceSegment>[
                MarketSourceSegment(
                  name: l.t('mp_source_news'),
                  fraction: 0.68,
                  colorName: 'green',
                ),
                MarketSourceSegment(
                  name: l.t('mp_source_chats'),
                  fraction: 0.20,
                  colorName: 'amber',
                ),
                MarketSourceSegment(
                  name: l.t('mp_source_social'),
                  fraction: 0.12,
                  colorName: 'red',
                ),
              ];

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.t('mp_chart_sources'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Donut centered at the top.
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                size: const Size(72, 72),
                painter: _DonutPainter(segments: segments),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend below the donut, evenly distributed across the
          // available width. Each item gets equal space via
          // [Expanded] so long names ellipsize cleanly instead of
          // overflowing the card.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _LegendItem(
                    color: _colorForName(segments[i].colorName),
                    label: '${(segments[i].fraction * 100).round()}%',
                    name: segments[i].name,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Color _colorForName(String name) {
    switch (name) {
      case 'amber':
        return const Color(0xFFFBBF24);
      case 'red':
        return const Color(0xFFEF4444);
      case 'green':
      default:
        return const Color(0xFF22C55E);
    }
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.name,
  });
  final Color color;
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    // Compact horizontal layout: dot + name + percentage.
    // Wrapped in a Column so each legend slot has a uniform height
    // regardless of the source name's length.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Paints a 3-segment donut chart. Segments and colors are
/// supplied so the painter can render AI-driven or demo data.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required List<MarketSourceSegment> segments})
      : _segments = segments;
  final List<MarketSourceSegment> _segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final stroke = 12.0;

    var start = -math.pi / 2;
    const gap = 0.012; // small gap between segments, in radians
    for (final s in _segments) {
      final color = _colorForName(s.colorName);
      final sweep = s.fraction * 2 * math.pi - gap;
      final paint = Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += s.fraction * 2 * math.pi;
    }
  }

  static Color _colorForName(String name) {
    switch (name) {
      case 'amber':
        return const Color(0xFFFBBF24);
      case 'red':
        return const Color(0xFFEF4444);
      case 'green':
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old._segments != _segments;
}

class _DonutSegment {
  const _DonutSegment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

// ============================ Section Header ============================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0),
      child: Text(
        title,
        style: TextStyle(
          color: KashfPalette.active.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ============================ Topics Row ============================
class _TopicsRow extends StatelessWidget {
  const _TopicsRow({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final List<_TopicCardData> topics;
    if (data != null && data!.topics.isNotEmpty) {
      topics = data!.topics.take(5).map((t) {
        return _TopicCardData(
          label: localiseBrandOrTag(t.label, locale: l.language.code),
          brand: localiseBrandOrTag(t.brand, locale: l.language.code),
          change: t.change,
          positive: t.positive,
          points: t.points,
        );
      }).toList();
    } else {
      topics = <_TopicCardData>[
        _TopicCardData(
          label: l.t('mp_topic1_label'),
          brand: l.t('mp_topic1_brand'),
          change: l.t('mp_topic1_change'),
          positive: true,
          points: _kTopic1,
        ),
        _TopicCardData(
          label: l.t('mp_topic2_label'),
          brand: l.t('mp_topic2_brand'),
          change: l.t('mp_topic2_change'),
          positive: true,
          points: _kTopic2,
        ),
        _TopicCardData(
          label: l.t('mp_topic3_label'),
          brand: l.t('mp_topic3_brand'),
          change: l.t('mp_topic3_change'),
          positive: false,
          points: _kTopic3,
        ),
        _TopicCardData(
          label: l.t('mp_topic4_label'),
          brand: l.t('mp_topic4_brand'),
          change: l.t('mp_topic4_change'),
          positive: false,
          points: _kTopic4,
        ),
        _TopicCardData(
          label: l.t('mp_topic5_label'),
          brand: l.t('mp_topic5_brand'),
          change: l.t('mp_topic5_change'),
          positive: true,
          points: _kTopic5,
        ),
      ];
    }

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _TopicCard(data: topics[i]),
      ),
    );
  }
}

class _TopicCardData {
  const _TopicCardData({
    required this.label,
    required this.brand,
    required this.change,
    required this.positive,
    required this.points,
  });
  final String label;
  final String brand;
  final String change;
  final bool positive;
  final List<double> points;
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.data});
  final _TopicCardData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = data.positive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Container(
      width: 100,
      // Top-only padding: title + sub-label have horizontal padding, but
      // the sparkline at the bottom touches the card's bottom, left, and
      // right edges with no rounded-corner clipping.
      padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Header block: title + sub-label, with horizontal padding.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: title (start) + percentage (end).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic label — on the start side.
                    Expanded(
                      child: Text(
                        data.label,
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.change,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Brand + "24 ساعة" sub-label on the end side.
                Row(
                  children: [
                    Text(
                      l.t('mp_kpi_24h'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.brand,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
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
          // Sparkline pinned to the bottom of the card, with no
          // padding on the left, right, or bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 20,
            child: _Sparkline(
              color: color,
              points: data.points,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Brands Row ============================
class _BrandsRow extends StatelessWidget {
  const _BrandsRow({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const fallbackImages = <String>[
      'assets/images/lattafa.jpeg',
      'assets/images/borge.jpeg',
      'assets/images/sauvage.jpeg',
      'assets/images/winner.jpeg',
      'assets/images/parfum.jpeg',
    ];
    const hintToImage = <String, String>{
      'perfume': 'assets/images/parfum.jpeg',
      'phone': 'assets/images/sauvage.jpeg',
      'shoe': 'assets/images/borge.jpeg',
      'coffee': 'assets/images/sauvage.jpeg',
      'fashion': 'assets/images/winner.jpeg',
      'beauty': 'assets/images/lattafa.jpeg',
    };

    final List<_BrandCardData> brands;
    if (data != null && data!.brands.isNotEmpty) {
      brands = data!.brands.take(6).toList().asMap().entries.map((e) {
        final b = e.value;
        final lower = b.imageHint.toLowerCase();
        final logo = hintToImage.entries
                .firstWhere(
                  (kv) => lower.contains(kv.key),
                  orElse: () => const MapEntry('', ''),
                )
                .value
                .isNotEmpty
            ? hintToImage.entries
                .firstWhere((kv) => lower.contains(kv.key))
                .value
            : fallbackImages[e.key % fallbackImages.length];
        return _BrandCardData(
          logo: logo,
          name: b.name,
          growth: b.growth,
          positive: b.positive,
          logoUrl: LogoService.urlFor(b.domain, size: 128),
        );
      }).toList();
      // Diagnostic: show which resolved logo URLs we're about to
      // render. Helps debug cases where the AI didn't return a
      // domain or the resolver returned null.
      // ignore: avoid_print
      print('[MarketScreen] brand logo URLs:');
      for (var i = 0; i < brands.length; i++) {
        // ignore: avoid_print
        print('  [$i] ${brands[i].name} -> ${brands[i].logoUrl ?? "(asset)"}');
      }
    } else {
      brands = <_BrandCardData>[
        _BrandCardData(
          logo: 'assets/images/lattafa.jpeg',
          name: l.t('mp_brand_lattafa'),
          growth: '+45%',
          positive: true,
        ),
        _BrandCardData(
          logo: 'assets/images/borge.jpeg',
          name: l.t('mp_brand_nike'),
          growth: '+32%',
          positive: true,
        ),
        _BrandCardData(
          logo: 'assets/images/sauvage.jpeg',
          name: l.t('mp_brand_dior'),
          growth: '+28%',
          positive: true,
        ),
        _BrandCardData(
          logo: 'assets/images/winner.jpeg',
          name: l.t('mp_brand_starbucks'),
          growth: '+24%',
          positive: true,
        ),
        _BrandCardData(
          logo: 'assets/images/parfum.jpeg',
          name: l.t('mp_brand_adidas'),
          growth: '+21%',
          positive: true,
        ),
        _BrandCardData(
          logo: 'assets/images/lattafa.jpeg',
          name: l.t('mp_brand_skin'),
          growth: '+18%',
          positive: true,
        ),
      ];
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _BrandCard(data: brands[i]),
      ),
    );
  }
}

class _BrandCardData {
  const _BrandCardData({
    required this.logo,
    required this.name,
    required this.growth,
    required this.positive,
    this.logoUrl,
  });
  final String logo;
  final String name;
  final String growth;
  final bool positive;
  /// Remote logo URL (Logo.dev) when the AI gave us a domain. The
  /// card renders this URL with the bundled `logo` asset as a
  /// fallback for any network failure.
  final String? logoUrl;
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.data});
  final _BrandCardData data;

  @override
  Widget build(BuildContext context) {
    final color = data.positive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Container(
      width: 78,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          // Logo circle. Uses a `Stack` with `Positioned.fill` to
          // guarantee the image paints the entire inner rect of the
          // circle edge-to-edge. No border on the container (it
          // would consume pixels and leave a visible gap).
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KashfPalette.active.fieldFill,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox.expand(
              child: data.logoUrl != null
                  ? Image.network(
                      data.logoUrl!,
                      fit: BoxFit.cover,
                      // Logo.dev 404s are common for regional
                      // perfume / fashion brands that don't have a
                      // public website. Log the failure (so we can
                      // tell which brands to drop from the
                      // dictionary) and fall back to the bundled
                      // asset so the user always sees something.
                      errorBuilder: (context, error, stack) {
                        // ignore: avoid_print
                        print(
                            '[MarketScreen] Logo.dev failed for '
                            '${data.name} (${data.logoUrl}): $error');
                        return Image.asset(
                          data.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        );
                      },
                      // Loading: keep the slot reserved with the
                      // fallback asset already painted underneath.
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Image.asset(
                          data.logo,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      data.logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.name,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward, color: color, size: 10),
              const SizedBox(width: 2),
              Text(
                data.growth,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================ Events List ============================
class _EventsList extends StatelessWidget {
  const _EventsList({
    required this.l,
    this.data,
    this.isLoading = false,
  });
  final AppLocalizations l;
  final MarketDetailData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final List<_EventData> events;
    if (data != null && data!.events.isNotEmpty) {
      events = data!.events.take(3).map((e) {
        final colors = _statusColors(e.statusColorName);
        return _EventData(
          title: e.title,
          subtitle: e.subtitle,
          time: e.time,
          status: e.status,
          statusColor: colors.fg,
          statusBg: colors.bg,
        );
      }).toList();
    } else {
      events = <_EventData>[
        _EventData(
          title: l.t('mp_news1_title'),
          subtitle: l.t('mp_news1_sub'),
          time: l.t('mp_event_35m'),
          status: l.t('mp_news_status_viral'),
          statusColor: const Color(0xFFFBBF24),
          statusBg: const Color(0xFF241F12),
        ),
        _EventData(
          title: l.t('mp_news2_title'),
          subtitle: l.t('mp_news2_sub'),
          time: l.t('mp_event_2h'),
          status: l.t('mp_news_status_important'),
          statusColor: const Color(0xFF22C55E),
          statusBg: const Color(0xFF12241A),
        ),
        _EventData(
          title: l.t('mp_news3_title'),
          subtitle: l.t('mp_news3_sub'),
          time: l.t('mp_event_4h'),
          status: l.t('mp_news_status_banned'),
          statusColor: const Color(0xFFEF4444),
          statusBg: const Color(0xFF241318),
        ),
      ];
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _EventCard(data: events[i]),
        ],
      ],
    );
  }

  static ({Color fg, Color bg}) _statusColors(String name) {
    switch (name) {
      case 'red':
        return (
          fg: const Color(0xFFEF4444),
          bg: const Color(0xFF241318),
        );
      case 'green':
        return (
          fg: const Color(0xFF22C55E),
          bg: const Color(0xFF12241A),
        );
      case 'amber':
      default:
        return (
          fg: const Color(0xFFFBBF24),
          bg: const Color(0xFF241F12),
        );
    }
  }
}

class _EventData {
  const _EventData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBg,
  });
  final String title;
  final String subtitle;
  final String time;
  final String status;
  final Color statusColor;
  final Color statusBg;
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.data});
  final _EventData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title (start) + status pill (end).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
                decoration: BoxDecoration(
                  color: data.statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  style: TextStyle(
                    color: data.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Bottom row: time (with clock icon).
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: KashfPalette.active.textSecondary,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                data.time,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// // ============================ Action Buttons ============================
// class _ActionButtons extends StatelessWidget {
//   const _ActionButtons({required this.l});
//   final AppLocalizations l;

//   @override
//   Widget build(BuildContext context) {
//     // Visual order (left → right) should be:
//     //   [Compare] [Watchlist] [Start new investigation]
//     // In an RTL Row, the first child renders on the right, so the
//     // data order is reversed: [Investigate, Watchlist, Compare].
//     return Row(
//       children: [
//         // Start new investigation (gold filled) — renders on the
//         // visual right edge.
//         Expanded(
//           child: _PrimaryActionButton(
//             icon: Icons.search,
//             label: l.t('mp_investigate_btn'),
//             onTap: () {},
//           ),
//         ),
//         const SizedBox(width: 6),
//         // Watchlist (outline).
//         Expanded(
//           child: _OutlineActionButton(
//             icon: Icons.bookmark_outline,
//             label: l.t('mp_watchlist_btn'),
//             onTap: () {},
//           ),
//         ),
//         const SizedBox(width: 6),
//         // Compare (outline) — renders on the visual left edge.
//         Expanded(
//           child: _OutlineActionButton(
//             icon: Icons.compare_arrows,
//             label: l.t('mp_compare_btn'),
//             onTap: () {},
//           ),
//         ),
//       ],
//     );
//   }
// }

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: KashfPalette.active.textPrimary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
        decoration: BoxDecoration(
          color: KashfColors.gold,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ Reusable Sparkline ============================
/// Tiny static smooth-curve sparkline backed by Syncfusion's
/// [SfCartesianChart]. Renders the given normalized values as a
/// professional-looking spline (smooth curve) with a hairline stroke
/// and no animation, no axis chrome, no trackball, no markers.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.color, required this.points});

  final Color color;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final series = <_ChartPoint>[
      for (var i = 0; i < points.length; i++)
        _ChartPoint(x: i.toDouble(), y: points[i]),
    ];
    return SizedBox.expand(
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        primaryXAxis: NumericAxis(
          isVisible: false,
          minimum: 0,
          maximum: (points.length - 1).toDouble(),
        ),
        primaryYAxis: NumericAxis(
          isVisible: false,
          minimum: 0,
          maximum: 1,
        ),
        // Two stacked series: a translucent area-fill under a clean
        // smooth spline line — the same look used by the reference.
        series: [
          SplineAreaSeries<_ChartPoint, double>(
            dataSource: series,
            xValueMapper: (_ChartPoint p, _) => p.x,
            yValueMapper: (_ChartPoint p, _) => p.y,
            color: color.withValues(alpha: 0.18),
            borderColor: Colors.transparent,
            splineType: SplineType.natural,
            cardinalSplineTension: 0.5,
            animationDuration: 0,
            enableTooltip: false,
          ),
          SplineSeries<_ChartPoint, double>(
            dataSource: series,
            xValueMapper: (_ChartPoint p, _) => p.x,
            yValueMapper: (_ChartPoint p, _) => p.y,
            color: color,
            width: 1.4,
            splineType: SplineType.natural,
            cardinalSplineTension: 0.5,
            animationDuration: 0,
            enableTooltip: false,
          ),
        ],
      ),
    );
  }
}

class _ChartPoint {
  const _ChartPoint({required this.x, required this.y});
  final double x;
  final double y;
}

// Pre-baked trend shapes used by the "topics" cards. Each list is an
// UPWARD-trending line with small wavy ripples on top — the same look
// as the reference screenshot. The line climbs from a low baseline to
// a higher value across the chart, with organic high-frequency
// variation (not a pure zig-zag, not a flat ramp).
//
// Parameters:
//   n     — number of points.
//   seed  — RNG seed (different per card so each line looks unique).
//   start — value at the left edge (low).
//   end   — value at the right edge (high).
//   wave  — amplitude of the small ripples on top of the trend.
List<double> _uptrend(
  int n,
  int seed, {
  required double start,
  required double end,
  required double wave,
}) {
  final rand = math.Random(seed);
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    // Linear upward trend from `start` → `end`.
    final t = i / (n - 1);
    final trend = start + (end - start) * t;
    // A fast sine of moderate amplitude + a tiny random jitter
    // produces organic ripples without dominating the trend.
    final ripple =
        math.sin(t * math.pi * 4 + rand.nextDouble() * 1.2) * wave;
    final jitter = (rand.nextDouble() - 0.5) * wave * 0.5;
    final v = (trend + ripple + jitter).clamp(0.05, 0.95);
    out.add(v);
  }
  return out;
}

final List<double> _kTopic1 = _uptrend(17, 1, start: 0.20, end: 0.85, wave: 0.08);
final List<double> _kTopic2 = _uptrend(17, 7, start: 0.30, end: 0.80, wave: 0.10);
final List<double> _kTopic3 = _uptrend(17, 13, start: 0.15, end: 0.75, wave: 0.09);
final List<double> _kTopic4 = _uptrend(17, 21, start: 0.25, end: 0.90, wave: 0.07);
final List<double> _kTopic5 = _uptrend(17, 35, start: 0.35, end: 0.85, wave: 0.08);
