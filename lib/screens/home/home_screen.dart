import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import '../market/market_screen.dart';
import '../files/files_screen.dart';
import '../files/latest_investigations_screen.dart';
import 'today_case_screen.dart';

/// KASHF Lite dashboard. The entry point after sign-in. Layout mirrors
/// the marketing reference: greeting + user avatar, featured investigation
/// card, weekly market pulse, 6 quick actions in a 2-column grid, and
/// recent updates carousel.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Use the natural direction for the active language so Arabic flows
    // right-to-left and English flows left-to-right natively.
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                sliver: SliverToBoxAdapter(child: _TopBar()),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                sliver: SliverToBoxAdapter(child: _Greeting(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(child: _FeaturedInvestigation(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l.t('home_market_pulse'),
                    trailing: l.t('home_view_all'),
                    onTrailingTap: () => Navigator.of(
                      context,
                    ).push(kashfRoute(const MarketScreen())),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(child: _MarketPulseList(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l.t('home_quick_actions'),
                    trailing: l.t('home_view_all'),
                    onTrailingTap: () => Navigator.of(
                      context,
                    ).push(kashfRoute(const FilesScreen())),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(child: _QuickActionsGrid(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l.t('home_recent_activity'),
                    trailing: l.t('home_view_all'),
                    onTrailingTap: () => Navigator.of(
                      context,
                    ).push(kashfRoute(const LatestInvestigationsScreen())),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                sliver: SliverToBoxAdapter(child: _RecentUpdatesList(l: l)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    // The logo image already contains the brand name, so we just render it
    // as-is. Width is sized to match the action controls (bell + avatar).
    final logoMark = Image.asset(
      'assets/images/logo_appbar.png',
      height: 30,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, _, _) => KashfLogo(width: 90),
    );

    final bell = _NotificationBell();
    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KashfColors.gold.withValues(alpha: 0.18),
        border: Border.all(color: KashfColors.gold, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/logoprofile.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, color: KashfColors.gold, size: 18),
      ),
    );

    // Children are listed in natural LTR visual order. Directionality
    // mirrors them for RTL automatically:
    //   LTR: [avatar] [bell] ... [logo]
    //   RTL: [logo]  ... [bell] [avatar]
    return Row(
      children: [avatar, SizedBox(width: 8), bell, Spacer(), logoMark],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KashfPalette.active.surface,
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_none_outlined,
              color: KashfPalette.active.textPrimary,
              size: 16,
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: KashfColors.gold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: KashfPalette.active.background,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Greeting ============================
// Compact greeting line shown between the top bar and the featured card:
// "Good morning, Noor" + a softer "Welcome to KASHF Lite" subtitle.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.t('home_greeting')),
                TextSpan(text: ', '),
                TextSpan(
                  text: l.t('home_user_name'),
                  style: TextStyle(color: KashfColors.gold),
                ),
              ],
            ),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            l.t('home_greeting_sub'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 11,
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

// ============================ Featured Investigation ============================
class _FeaturedInvestigation extends StatelessWidget {
  const _FeaturedInvestigation({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Purple is the primary accent for this card.
    const purple = Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(kashfRoute(const TodayCaseScreen())),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: star icon + "قضية اليوم" label
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  l.t('home_featured_today'),
                  style: TextStyle(
                    color: purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.star_outline, color: purple, size: 20),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F1810), Color(0xFF2D2418)],
              ),
              border: Border.all(
                color: purple.withValues(alpha: 0.40),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1) Text column (RIGHT side in RTL = START).
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title â€" white, bold.
                          Text(
                            l.t('home_featured_title'),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          // Subtitle â€" lighter gray, plain text (no icon).
                          Text(
                            l.t('home_featured_subtitle'),
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 11,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Spacer(),
                          // Bottom row: stats (start side) + CTA pill (end side).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Stats inline with thin vertical dividers.
                              Expanded(
                                child: Row(
                                  children: [
                                    _FeaturedStat(
                                      value: '12',
                                      unit: l.t('home_featured_metric1_ar'),
                                      color: purple,
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      width: 1,
                                      height: 22,
                                      color: purple.withValues(alpha: 0.30),
                                    ),
                                    SizedBox(width: 6),
                                    _FeaturedStat(
                                      value: '8',
                                      unit: l.t('home_featured_metric2_ar'),
                                      color: purple,
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      width: 1,
                                      height: 22,
                                      color: purple.withValues(alpha: 0.30),
                                    ),
                                    SizedBox(width: 6),
                                    _FeaturedStat(
                                      value: '24',
                                      unit: l.t('home_featured_metric3_ar'),
                                      color: purple,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              // Outlined purple pill CTA on the END side.
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: purple, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l.t('home_featured_open'),
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.chevron_right,
                                      color: purple,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    // 2) Image tile (ends up on the RIGHT side in RTL). Expands
                    // to the full height of the card so it doesn't look like a
                    // small thumbnail.
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF1A0F08),
                          border: Border.all(
                            color: purple.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/lattafa.jpeg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF2A1A0F),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.local_florist,
                                  color: purple,
                                  size: 36,
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topEnd,
                                  end: AlignmentDirectional.bottomStart,
                                  colors: [
                                    Colors.transparent,
                                    purple.withValues(alpha: 0.18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedStat extends StatelessWidget {
  const _FeaturedStat({
    required this.value,
    required this.unit,
    required this.color,
  });
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small number â€" purple accent.
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        SizedBox(height: 1),
        // Unit label â€" purple accent. FittedBox guarantees it shrinks
        // instead of overflowing when the string is long.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            unit,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ============================ Section Header ============================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================ Market Pulse ============================
class _MarketPulseList extends StatelessWidget {
  const _MarketPulseList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return _MarketPulsePanel(l: l);
  }
}

class _MarketPulsePanel extends StatelessWidget {
  const _MarketPulsePanel({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Color tokens used across the panel.
    const green = Color(0xFF22C55E);
    const blue = Color(0xFF38BDF8);
    const red = Color(0xFFEF4444);
    const gold = Color(0xFFF4C542);

    final cards = <_PulseCardData>[
      _PulseCardData(
        label: l.t('home_pulse_top_gainers'),
        value: l.t('home_pulse_gainers_val'),
        sub: l.t('home_pulse_gainers_sub'),
        color: green,
        bg: const Color(0xFF12241A),
        points: _kSparkUp,
      ),
      _PulseCardData(
        label: l.t('home_pulse_top_traded'),
        value: l.t('home_pulse_traded_val'),
        sub: l.t('home_pulse_traded_sub'),
        color: blue,
        bg: const Color(0xFF13202A),
        points: _kSparkWave1,
      ),
      _PulseCardData(
        label: l.t('home_pulse_top_losers'),
        value: l.t('home_pulse_losers_val'),
        sub: l.t('home_pulse_losers_sub'),
        color: red,
        bg: const Color(0xFF241318),
        points: _kSparkDown,
      ),
      _PulseCardData(
        label: l.t('home_pulse_top_campaigns'),
        value: l.t('home_pulse_campaigns_val'),
        sub: l.t('home_pulse_campaigns_sub'),
        color: gold,
        bg: const Color(0xFF241F12),
        points: _kSparkWave2,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row of 4 colored cards (equal width, side-by-side).
        Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(width: 8),
              Expanded(child: _PulseMetricCard(data: cards[i])),
            ],
          ],
        ),
        SizedBox(height: 8),
        // Bottom activity row: clock icon + label/sub on the start,
        // big percentage + small chart on the end (RTL-aware ordering).
        Container(
          padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Row(
            children: [
              // Start side: clock icon + text block.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.access_time, color: green, size: 16),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.t('home_pulse_market_active'),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),
                    Text(
                      l.t('home_pulse_market_active_h'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // End side: text block + small chart image.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.t('home_pulse_market_alert'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1),
                  Text(
                    l.t('home_pulse_market_vs'),
                    style: TextStyle(
                      color: green,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              SizedBox(width: 6),
              Container(
                width: 36,
                height: 22,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size(36, 22),
                  painter: _SparklinePainter(color: green, points: _kSparkUp),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseCardData {
  const _PulseCardData({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.bg,
    required this.points,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color bg;
  final List<double> points;
}

class _PulseMetricCard extends StatelessWidget {
  const _PulseMetricCard({required this.data});
  final _PulseCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: 0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: small label (Ø§Ù„Ø£ÙƒØ«Ø± ØµØ¹ÙˆØ¯Ù‹Ø§, etc.).
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          // Middle: big value (+24%, #Lattafa, -8%, 12).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: data.color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 3),
          // Subtitle (Ø§Ù„Ø¹Ø·ÙˆØ±, 328K Ù…Ù†Ø´ÙˆØ±, etc.).
          Text(
            data.sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          // Bottom: wavy sparkline chart.
          SizedBox(
            height: 22,
            width: double.infinity,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                color: data.color,
                points: data.points,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny sparkline painter that draws a small, irregular zig-zag line
/// through the given normalized values (0..1). Used at the bottom of
/// each pulse card and inside the small chart thumbnail.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color, required this.points});

  final Color color;
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Compress the line to the lower portion of the box, mirroring
    // the small, low-positioned trend lines in the screenshot.
    // Baseline sits near the bottom and amplitude stays small.
    final baseY = size.height * 0.80; // baseline
    final amp = size.height * 0.30; // max up/down swing
    double yFor(double v) => baseY - (v - 0.1) * amp;

    final path = Path();
    final n = points.length;
    final dx = size.width / (n - 1);

    // Straight segments: the screenshot shows a jagged zig-zag, not a
    // smooth wave, so we just connect the points directly.
    path.moveTo(0, yFor(points[0]));
    for (var i = 1; i < n; i++) {
      path.lineTo(i * dx, yFor(points[i]));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.points != points;
}

/// Pre-baked wave shapes that look like the screenshot. All values are
/// normalized to 0..1 (vertical range used by the painter). Each card
/// uses a different irregular pattern with varying amplitudes so the
/// trend lines look natural â€" small and zig-zaggy.
const List<double> _kSparkUp = [
  0.52,
  0.38,
  0.61,
  0.46,
  0.55,
  0.40,
  0.66,
  0.50,
  0.58,
  0.80,
  0.72,
  0.55,
  0.2,
  0.99,
  0.68,
  0.53,
  0.74,
];

const List<double> _kSparkDown = [
  0.48,
  0.102,
  0.40,
  0.55,
  0.44,
  0.60,
  0.36,
  0.52,
  0.99,
  0.58,
  0.32,
  0.50,
  0.42,
  0.56,
  0.38,
  0.52,
  0.30,
];

// Extra distinct patterns for variety.
const List<double> _kSparkWave1 = [
  0.45,
  0.60,
  0.50,
  0.38,
  0.55,
  0.99,
  0.42,
  0.58,
  0.46,
  0.64,
  0.50,
  0.36,
  0.58,
  0.48,
  0.62,
  0.01,
  0.56,
];

const List<double> _kSparkWave2 = [
  0.55,
  0.8,
  0.30,
  0.80,
  0.50,
  0.64,
  0.40,
  0.99,
  0.01,
  0.62,
  0.44,
  0.58,
  0.50,
  0.38,
  0.54,
  0.46,
  0.80,
];

// ============================ Quick Actions ============================
// Mirrors the marketing reference: a horizontal carousel of activity
// cards. Each card shows a cover image with a status dot, the activity
// title, a percentage, a colored progress bar, and a status label.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        title: l.t('home_quick_title_perfume'),
        progress: 0.72,
        progressColor: const Color(0xFF22C55E),
        status: l.t('home_monitored'),
        statusColor: const Color(0xFF22C55E),
        imagePath: 'assets/images/parfum.jpeg',
        showDot: true,
        dotColor: const Color(0xFF22C55E),
      ),
      _QuickAction(
        title: l.t('home_quick_title_brand'),
        progress: 0.65,
        progressColor: const Color(0xFFF59E0B),
        status: l.t('home_quick_analyzing'),
        statusColor: const Color(0xFFF59E0B),
        imagePath: 'assets/images/borge.jpeg',
      ),
      _QuickAction(
        title: l.t('home_quick_title_influencer'),
        progress: 0.48,
        progressColor: const Color(0xFFFB923C),
        status: l.t('home_quick_collecting'),
        statusColor: const Color(0xFFFB923C),
        imagePath: 'assets/images/winner.jpeg',
      ),
      _QuickAction(
        title: l.t('home_quick_title_starbucks'),
        progress: 0.38,
        progressColor: const Color(0xFFEF4444),
        status: l.t('home_quick_new_updates'),
        statusColor: const Color(0xFFEF4444),
        imagePath: 'assets/images/sauvage.jpeg',
        showDot: true,
        dotColor: const Color(0xFFEF4444),
      ),
      _QuickAction(
        title: l.t('home_quick_title_iphone'),
        progress: 0.92,
        progressColor: const Color(0xFF22C55E),
        status: l.t('home_monitored'),
        statusColor: const Color(0xFF22C55E),
        imagePath: 'assets/images/parfum.jpeg',
        showDot: true,
        dotColor: const Color(0xFF22C55E),
      ),
      _QuickAction(
        title: l.t('home_quick_title_adidas'),
        progress: 0.88,
        progressColor: const Color(0xFF3B82F6),
        status: l.t('home_monitored'),
        statusColor: const Color(0xFF3B82F6),
        imagePath: 'assets/images/borge.jpeg',
      ),
      _QuickAction(
        title: l.t('home_quick_title_tiktok'),
        progress: 0.65,
        progressColor: const Color(0xFFF59E0B),
        status: l.t('home_quick_analyzing'),
        statusColor: const Color(0xFFF59E0B),
        imagePath: 'assets/images/winner.jpeg',
      ),
      _QuickAction(
        title: l.t('home_quick_title_lattafa'),
        progress: 0.45,
        progressColor: const Color(0xFFEF4444),
        status: l.t('home_quick_new_updates'),
        statusColor: const Color(0xFFEF4444),
        imagePath: 'assets/images/lattafa.jpeg',
        showDot: true,
        dotColor: const Color(0xFFEF4444),
      ),
    ];
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _QuickActionCard(action: actions[i]),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.title,
    required this.progress,
    required this.progressColor,
    required this.status,
    required this.statusColor,
    required this.imagePath,
    this.showDot = false,
    this.dotColor = const Color(0xFF22C55E),
  });
  final String title;
  final double progress;
  final Color progressColor;
  final String status;
  final Color statusColor;
  final String imagePath;
  final bool showDot;
  final Color dotColor;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final pct = (action.progress * 100).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 80,
                      color: const Color(0xFF2D2418),
                      child: Image.asset(
                        action.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          alignment: Alignment.center,
                          color: const Color(0xFF2D2418),
                          child: const Icon(
                            Icons.image_outlined,
                            color: KashfColors.gold,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    if (action.showDot)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: action.dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: action.dotColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: action.progressColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: action.progress,
                        minHeight: 4,
                        backgroundColor: KashfPalette.active.cardBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          action.progressColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      action.status,
                      style: TextStyle(
                        color: action.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

// ============================ Recent Updates ============================
class _RecentUpdatesList extends StatelessWidget {
  const _RecentUpdatesList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_UpdateItem>[
      _UpdateItem(
        title: l.t('home_update_perfume'),
        price: l.t('home_update_perfume_h'),
        views: l.t('home_update_perfume_views'),
        status: l.t('home_update_perfume_status'),
        time: l.t('home_update_perfume_time'),
        score: l.t('home_update_perfume_score'),
        scoreColor: const Color(0xFF22C55E),
        dotColor: const Color(0xFF22C55E),
        imagePath: 'assets/images/parfum.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_campaign'),
        price: l.t('home_update_campaign_h'),
        views: l.t('home_update_campaign_views'),
        status: l.t('home_update_campaign_status'),
        time: l.t('home_update_campaign_time'),
        score: l.t('home_update_campaign_score'),
        scoreColor: const Color(0xFF3B82F6),
        dotColor: const Color(0xFF3B82F6),
        imagePath: 'assets/images/borge.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_market'),
        price: l.t('home_update_market_h'),
        views: l.t('home_update_market_views'),
        status: l.t('home_update_market_status'),
        time: l.t('home_update_market_time'),
        score: l.t('home_update_market_score'),
        scoreColor: const Color(0xFFF59E0B),
        dotColor: const Color(0xFFF59E0B),
        imagePath: 'assets/images/sauvage.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_yasmine'),
        price: l.t('home_update_yasmine_h'),
        views: l.t('home_update_yasmine_views'),
        status: l.t('home_update_yasmine_status'),
        time: l.t('home_update_yasmine_time'),
        score: l.t('home_update_yasmine_score'),
        scoreColor: const Color(0xFFEF4444),
        dotColor: const Color(0xFFEF4444),
        imagePath: 'assets/images/lattafa.jpeg',
      ),
    ];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UpdateCard(item: items[i]),
    );
  }
}

class _UpdateItem {
  const _UpdateItem({
    required this.title,
    required this.price,
    required this.views,
    required this.status,
    required this.time,
    required this.score,
    required this.scoreColor,
    required this.dotColor,
    required this.imagePath,
  });
  final String title;
  final String price;
  final String views;
  final String status;
  final String time;
  final String score;
  final Color scoreColor;
  final Color dotColor;
  final String imagePath;
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.item});
  final _UpdateItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Far left: 3-dot menu
            const Icon(Icons.more_vert, color: Color(0xFF6B7280), size: 18),
            const SizedBox(width: 10),
            // Right column: percentage (top), time (bottom)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.score}%',
                  style: TextStyle(
                    color: item.scoreColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.time,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Middle of the row: status text + colored dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.status,
                  style: TextStyle(
                    color: item.scoreColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Title column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.price,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.views,
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
            ),
            const SizedBox(width: 12),
            // Far right (in LTR) / Far left (in RTL): thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFF2D2418),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    alignment: Alignment.center,
                    color: const Color(0xFF2D2418),
                    child: const Icon(
                      Icons.image_outlined,
                      color: KashfColors.gold,
                      size: 24,
                    ),
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
