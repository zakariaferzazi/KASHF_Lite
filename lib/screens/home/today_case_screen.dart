import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// "ملفي النشط" / "قضية اليوم" detail screen — opens when the user
/// taps the featured investigation card on the home screen.
///
/// Layout (top → bottom), mirroring the reference screenshot:
///   1. Top bar: back arrow (start) + title (center) + share/download
///      icons (end)
///   2. Hero card: cover image (end side) + title + social icons
///      (start side), gold border
///   3. KPI strip (4 metrics): Reach / Mentions / Confidence / Active
///   4. Tab bar: ملخص | الأدلة | التحديثات | الرؤى (right-to-left in RTL)
///   5. "الملخص التنفيذي" body text + "اقرأ المزيد" gold pill
///   6. "مؤشرات سريعة" 2x2 stat grid
///   7. "تحديث سريع" timeline with date pills
///   8. "عرض جدول زمني كامل" outlined CTA
class TodayCaseScreen extends StatefulWidget {
  const TodayCaseScreen({super.key});

  @override
  State<TodayCaseScreen> createState() => _TodayCaseScreenState();
}

// Brand-aligned gold accent used across the screen — matches the
// global brand gold so the status pill, "اقرأ المزيد", "$482K"
// value, Ask AI CTA, and the selected bottom-bar item all share
// the same accent color.
const Color _tcAccent = Color(0xFFF4C542);

// Accent colors used on the metric strip / timeline.
const Color _tcGreen = Color(0xFF22C55E);
const Color _tcBlue = Color(0xFF3B82F6);

class _TodayCaseScreenState extends State<TodayCaseScreen> {
  int _tabIndex = 0;

  // Brand-aligned gold accent used across the screen — matches the
  // global brand gold so the status pill, "اقرأ المزيد", "$482K"
  // value, Ask AI CTA, and the selected bottom-bar item all share
  // the same accent color.
  static const Color _accent = _tcAccent;

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
              _TopBar(l: l),
              const SizedBox(height: 12),
              _HeroCard(l: l, accent: _accent),
              const SizedBox(height: 12),
              _KpiStrip(l: l),
              const SizedBox(height: 12),
              _TabsRow(
                index: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
                l: l,
              ),
              const SizedBox(height: 12),
              _SectionTitle(text: l.t('tc_section_overview_ar')),
              const SizedBox(height: 6),
              _AboutBody(text: l.t('tc_about_body')),
              const SizedBox(height: 10),
              _ReadMoreCta(l: l, accent: _accent),
              const SizedBox(height: 16),
              _SectionTitle(text: l.t('tc_quick_ar')),
              const SizedBox(height: 8),
              _QuickIndicatorsGrid(l: l),
              const SizedBox(height: 16),
              _SectionTitle(text: l.t('tc_timeline_ar')),
              const SizedBox(height: 8),
              _TimelineList(l: l),
              const SizedBox(height: 16),
              _AskAiCta(l: l, accent: _accent),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: _BottomActionBar(l: l),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
// Forced LTR so the layout reads exactly like the reference
// screenshot regardless of the app's text direction:
//   [back] ............ [title/subtitle] ............ [scan] [avatar]
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button (always on the LEFT).
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.maybePop(context),
            size: 14,
          ),
          const Spacer(),
          // Center: title + subtitle stacked vertically.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l.t('tc_top_title'),
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.t('tc_top_subtitle'),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // End actions (always on the RIGHT): scan icon + avatar.
          SizedBox(
            width: 26,
            height: 26,
            child: CustomPaint(
              painter: _ScanIconPainter(color: KashfPalette.active.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tcAccent.withValues(alpha: 0.18),
              border: Border.all(color: _tcAccent, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/logoprofile.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, color: _tcAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a small document-scanner glyph: square outline with two
/// short corner brackets on the top-left and bottom-right. Mirrors
/// the icon shown in the reference screenshot's app bar.
class _ScanIconPainter extends CustomPainter {
  _ScanIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = size.width * 0.18;
    final bracketLen = size.width * 0.32;

    // Top-left corner brackets.
    canvas.drawLine(
      Offset(inset, inset + bracketLen),
      Offset(inset, inset),
      stroke,
    );
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset + bracketLen, inset),
      stroke,
    );
    // Bottom-right corner brackets.
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - bracketLen),
      Offset(size.width - inset, size.height - inset),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - bracketLen, size.height - inset),
      stroke,
    );
    // Small dot in the middle to read as a "scan target".
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.07,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanIconPainter old) => old.color != color;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
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
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KashfPalette.active.surface,
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: KashfPalette.active.textPrimary, size: size),
      ),
    );
  }
}

// ============================ Hero Card ============================
// Gold-bordered tile. Children listed in visual LTR order so
// Directionality mirrors them naturally:
//   LTR: [text col] [image]
//   RTL: [image] [text col]
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.l, required this.accent});
  final AppLocalizations l;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: KashfPalette.active.surface,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1) Text column (RIGHT side in RTL = START in Directionality).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status pill: "قضية" + small dot + "اليوم"
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.t('tc_results_today_ar'),
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Title.
                Text(
                  l.t('tc_hero_title_ar'),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Subtitle below the title.
                Text(
                  l.t('tc_hero_sub_ar'),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Dotted decorative divider under the title.
                _DashedDivider(color: accent.withValues(alpha: 0.50)),
                const SizedBox(height: 8),
                // Social icons row — Instagram, TikTok, YouTube, X, +8.
                Row(
                  children: [
                    _SocialBadge(
                      background: const Color(0xFFE1306C),
                      gradientColors: const [
                        Color(0xFFF58529),
                        Color(0xFFDD2A7B),
                        Color(0xFF8134AF),
                      ],
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    _SocialBadge(
                      background: Colors.black,
                      child: CustomPaint(
                        size: const Size(13, 13),
                        painter: _TikTokPainter(),
                      ),
                    ),
                    _SocialBadge(
                      background: const Color(0xFFFF0000),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    _SocialBadge(
                      background: const Color(0xFF000000),
                      child: const Text(
                        '𝕏',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                    _SocialBadge(
                      background: Colors.transparent,
                      borderColor: accent,
                      child: Text(
                        '+8',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 2) Image tile (LEFT side in RTL = END in Directionality).
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A0F08),
              border: Border.all(
                color: accent.withValues(alpha: 0.50),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/parfum.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF2A1A0F),
                    alignment: Alignment.center,
                    child: Icon(Icons.local_florist, color: accent, size: 32),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topEnd,
                      end: AlignmentDirectional.bottomStart,
                      colors: [
                        Colors.transparent,
                        accent.withValues(alpha: 0.18),
                      ],
                    ),
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

class _SocialBadge extends StatelessWidget {
  const _SocialBadge({
    required this.child,
    this.background,
    this.gradientColors,
    this.borderColor,
  });
  final Widget child;
  final Color? background;
  final List<Color>? gradientColors;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradientColors != null
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                )
              : null,
          color: gradientColors != null
              ? null
              : (background ?? Colors.black.withValues(alpha: 0.35)),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Draws a simple TikTok-style music-note-ish glyph in white on a
/// black circular background. Used inside [_SocialBadge].
class _TikTokPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    // Note head (filled ellipse) at bottom-left.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.32, size.height * 0.72),
        width: size.width * 0.55,
        height: size.height * 0.42,
      ),
      paint,
    );
    // Stem from note head up to top-right.
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.70),
      Offset(size.width * 0.78, size.height * 0.22),
      stroke,
    );
    // Flag at top.
    final flag = Path()
      ..moveTo(size.width * 0.78, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.36,
        size.width * 0.86,
        size.height * 0.52,
      );
    canvas.drawPath(flag, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (_, c) {
          const dash = 4.0;
          const gap = 3.0;
          final count = (c.maxWidth / (dash + gap)).floor();
          return Row(
            children: List.generate(count, (_) {
              return Container(
                width: dash,
                height: 1,
                margin: const EdgeInsetsDirectional.only(end: gap),
                color: color,
              );
            }),
          );
        },
      ),
    );
  }
}

// ============================ KPI Strip ============================
// Four equal-width tiles on the same dark surface. Each tile shows
// a small accent-colored icon + a big colored value on the top row,
// and a gray label below. Children listed in visual LTR order so
// RTL mirrors them (the first item ends up on the RIGHT = START).
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final tiles = <_KpiTile>[
      _KpiTile(
        icon: Icons.gps_fixed,
        iconColor: _tcGreen,
        value: l.t('tc_metric_reach_v'),
        valueColor: _tcGreen,
        label: l.t('tc_metric_reach_label'),
        labelColor: _tcGreen,
      ),
      _KpiTile(
        icon: Icons.camera_alt_outlined,
        iconColor: _tcGreen,
        value: l.t('tc_metric_mentions_v'),
        valueColor: _tcGreen,
        label: l.t('tc_metric_mentions_label'),
        labelColor: _tcGreen,
      ),
      _KpiTile(
        icon: Icons.donut_large,
        iconColor: const Color.fromARGB(255, 255, 255, 255),
        value: l.t('tc_metric_index_v'),
        valueColor: const Color.fromARGB(255, 255, 255, 255),
        label: l.t('tc_metric_index_label'),
        labelColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      _KpiTile(
        icon: Icons.access_time,
        iconColor: _tcGreen,
        value: l.t('tc_metric_active_label'),
        valueColor: _tcGreen,
        label: l.t('tc_metric_active_v'),
        labelColor: _tcGreen,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _KpiTileView(tile: tiles[i])),
        ],
      ],
    );
  }
}

class _KpiTile {
  const _KpiTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.label,
    required this.labelColor,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String label;
  final Color labelColor;
}

class _KpiTileView extends StatelessWidget {
  const _KpiTileView({required this.tile});
  final _KpiTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: small icon + big colored value.
          Row(
            children: [
              Icon(tile.icon, color: tile.iconColor, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tile.value,
                    style: TextStyle(
                      color: tile.valueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bottom row: gray-ish label.
          Text(
            tile.label,
            style: TextStyle(
              color: tile.labelColor.withValues(alpha: 0.75),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================ Tabs ============================
// Tabs are listed in visual LTR order so the first item ends up on
// the RIGHT (start) in RTL. First tab is selected by default.
class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.index,
    required this.onChanged,
    required this.l,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Order in the screenshot, right→left in RTL = first item here:
    // ملخص | الأدلة | التحديثات | الرؤى
    final tabs = <String>[
      l.t('tc_tab_overview_ar'),
      l.t('tc_tab_evidence_ar'),
      l.t('tc_tab_updates_ar'),
      l.t('tc_tab_insights_ar'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index
                        ? _tcAccent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color: i == index
                          ? _tcAccent
                          : KashfPalette.active.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================ About ============================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        "",
        style: TextStyle(
          color: KashfPalette.active.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          color: KashfPalette.active.textSecondary,
          fontSize: 11,
          height: 1.55,
        ),
      ),
    );
  }
}

// "اقرأ المزيد" gold outlined pill CTA below the summary.
class _ReadMoreCta extends StatelessWidget {
  const _ReadMoreCta({required this.l, required this.accent});
  final AppLocalizations l;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent, width: 1),
        ),
        child: Text(
          l.t('tc_read_more'),
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ============================ Quick Indicators ============================
// A single horizontal row of 4 stat cards. The row scrolls
// horizontally on narrow screens so all 4 cards stay visible at
// the same height without being squeezed. Each card is fixed-width
// (≈ 25% of the available row) and the whole row respects
// Directionality so RTL mirrors naturally.
class _QuickIndicatorsGrid extends StatelessWidget {
  const _QuickIndicatorsGrid({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Order in the screenshot, right→left in RTL:
    // $482K الإيرادات | 81% إيجابي | 286K تفاعل | 4.2M حجم التداول
    final tiles = <_QuickTile>[
      _QuickTile(
        label: l.t('tc_quick_volume_ar'),
        value: l.t('tc_quick_volume_v_ar'),
        sub: l.t('tc_quick_volume_sub_ar'),
      ),
      _QuickTile(
        label: l.t('tc_quick_engagement_ar'),
        value: l.t('tc_quick_engagement_v_ar'),
        sub: l.t('tc_quick_engagement_sub_ar'),
      ),
      _QuickTile(
        label: l.t('tc_quick_positive_ar'),
        value: l.t('tc_quick_positive_v_ar'),
        sub: l.t('tc_quick_positive_sub_ar'),
      ),
      _QuickTile(
        label: l.t('tc_quick_revenue_ar'),
        value: l.t('tc_quick_revenue_v_ar'),
        sub: l.t('tc_quick_revenue_sub_ar'),
      ),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _QuickCard(tile: tiles[i]),
      ),
    );
  }
}

class _QuickTile {
  const _QuickTile({
    required this.label,
    required this.value,
    required this.sub,
  });
  final String label;
  final String value;
  final String sub;
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.tile});
  final _QuickTile tile;

  @override
  Widget build(BuildContext context) {
    // Each card takes ~25% of the screen width but never below a
    // readable minimum so labels don't truncate.
    final width = MediaQuery.of(context).size.width * 0.24;
    return Container(
      width: width.clamp(82.0, 120.0),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tile.label,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              tile.value,
              style: TextStyle(
                color: _tcGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tile.sub,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
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

// ============================ Timeline ============================
// Dates on the LEFT (end in RTL), titles on the RIGHT (start in RTL).
// The connector line runs vertically THROUGH the date pills so the
// pills appear threaded onto the line.
class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_TimelineItem>[
      _TimelineItem(
        date: '2025-05-01',
        title: l.t('tc_tl1_title_ar'),
        h: l.t('tc_tl1_h_ar'),
      ),
      _TimelineItem(
        date: '2025-05-10',
        title: l.t('tc_tl2_title_ar'),
        h: l.t('tc_tl2_h_ar'),
      ),
      _TimelineItem(
        date: '2025-05-20',
        title: l.t('tc_tl3_title_ar'),
        h: l.t('tc_tl3_h_ar'),
      ),
      _TimelineItem(
        date: '2025-06-01',
        title: l.t('tc_tl4_title_ar'),
        h: l.t('tc_tl4_h_ar'),
      ),
    ];

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _TimelineRow(
              item: items[i],
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.date,
    required this.title,
    required this.h,
  });
  final String date;
  final String title;
  final String h;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });
  final _TimelineItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // Three columns in visual LTR order so Directionality mirrors
    // them for RTL:
    //   LTR: [title col] [line + dot] [date pill]
    //   RTL: [date pill] [line + dot] [title col]
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) Title + body (RIGHT in RTL = START).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vertical spacer matching the dot's center so the
                // text aligns with the date pill.
                const SizedBox(height: 6),
                Text(
                  item.title,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.h,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 2) Vertical line + dot (CENTER column).
          SizedBox(
            width: 12,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top connector: from the very top of the row down
                // to the dot. Hidden on the first row so the line
                // doesn't poke above the timeline.
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: 2,
                    child: ColoredBox(
                      color: isFirst ? const Color(0x00000000) : _tcGreen,
                    ),
                  ),
                ),
                // Center dot: the green circle that the line passes
                // through. Matches the screenshot.
                Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _tcGreen,
                    ),
                  ),
                ),
                // Bottom connector: from the dot down to the next
                // row. Hidden on the last row so the line doesn't
                // extend past the end.
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: 2,
                    child: ColoredBox(
                      color: isLast ? const Color(0x00000000) : _tcGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 30),
          // 3) Date text (LEFT in RTL = END). Plain green text — no
          // pill, no border — just the number aligned with the dot.
          Center(
            child: SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Text(
                  item.date,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: _tcGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Timeline CTA ============================
// Plain outlined CTA at the bottom of the timeline section. No
// background fill, no leading icon — just a thin border + label
// so it reads as a secondary action.
class _AskAiCta extends StatelessWidget {
  const _AskAiCta({required this.l, required this.accent});
  final AppLocalizations l;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        l.t('tc_ask_ai_ar'),
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ============================ Bottom Action Bar ============================
// 5-item dark pill bar matching the reference screenshot.
// Icons + labels listed in LTR order so RTL mirrors them:
//   LTR: [my-project] [new-report] [add-monitor] [import] [more]
//   RTL: [more]       [import]      [add-monitor]  [new-report] [my-project]
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_BarItem>[
      _BarItem(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.more_horiz,
        label: l.t('tc_bb_my_project_ar'),
        isSelected: true,
        onTap: () {},
      ),
      _BarItem(
        icon: Icons.description_outlined,
        selectedIcon: Icons.add_chart,
        label: l.t('tc_bb_new_report_ar'),
        onTap: () {},
      ),
      _BarItem(
        icon: Icons.visibility_outlined,
        selectedIcon: Icons.visibility,
        label: l.t('tc_bb_add_monitor_ar'),
        onTap: () {},
      ),
      _BarItem(
        icon: Icons.file_download_outlined,
        selectedIcon: Icons.file_download,
        label: l.t('tc_bb_import_reports_ar'),
        onTap: () {},
      ),
      _BarItem(
        icon: Icons.share,
        selectedIcon: Icons.more_horiz,
        label: l.t('tc_bb_more_ar'),
        onTap: () {},
      ),
    ];

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [for (final item in items) _BarButton(item: item)],
      ),
    );
  }
}

class _BarItem {
  const _BarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.item});
  final _BarItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isSelected ? item.selectedIcon : item.icon,
              color: item.isSelected
                  ? _tcAccent
                  : KashfPalette.active.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: item.isSelected
                    ? _tcAccent
                    : KashfPalette.active.textSecondary,
                fontSize: 8,
                fontWeight: item.isSelected ? FontWeight.w800 : FontWeight.w600,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
