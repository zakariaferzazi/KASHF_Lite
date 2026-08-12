import 'package:flutter/material.dart';
import 'package:kashf_lite/widgets/loading_overlay.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../models/investigation_result.dart';
import '../../theme.dart';
import '../../utils/text_direction_utils.dart';

/// "نتائج التحقيق" / "Investigation Results" — the destination
/// screen the [InvestigationScreen] pushes to once the service
/// finishes a run.
///
/// Layout (top → bottom):
///   1. Top bar (back · title · share/more)
///   2. Confidence hero card (overall confidence + summary)
///   3. Tab row (one chip per [InvestigationResultKind])
///   4. Section content: headline + summary + item cards
///   5. Action row (export / monitor / report / save)
class InvestigationResultsScreen extends StatefulWidget {
  const InvestigationResultsScreen({super.key, required this.result});
  final InvestigationResult result;

  @override
  State<InvestigationResultsScreen> createState() =>
      _InvestigationResultsScreenState();
}

class _InvestigationResultsScreenState
    extends State<InvestigationResultsScreen> {
  late int _activeSection;

  @override
  void initState() {
    super.initState();
    _activeSection = 0;
  }

  /// Sections that actually have items to render. Empty sections
  /// are kept in the model (so the canonical order is preserved
  /// for the parser) but hidden from the tab strip — otherwise a
  /// sparse report renders five empty tabs and looks broken.
  List<InvestigationResultSection> get _visibleSections =>
      widget.result.sections.where((s) => s.items.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visible = _visibleSections;
    // Clamp the active index in case the visible-section list
    // shrank (e.g. result came back from an older run already
    // cached before the new schema shipped).
    final activeIndex = _activeSection.clamp(0, visible.length - 1);
    final section = visible[activeIndex];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(l: l, result: widget.result),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _HeroCard(result: widget.result, l: l),
                    const SizedBox(height: 14),
                    _TabsRow(
                      sections: visible,
                      active: activeIndex,
                      onSelect: (i) => setState(() => _activeSection = i),
                      l: l,
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(section: section, l: l),
                    const SizedBox(height: 10),
                    for (final item in section.items) ...[
                      _ItemCard(item: item, l: l),
                      const SizedBox(height: 8),
                    ],
                    if (section.items.isEmpty)
                      _EmptyState(l: l),
                  ],
                ),
              ),
              _ActionBar(result: widget.result, l: l),
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
  const _TopBar({required this.l, required this.result});
  final AppLocalizations l;
  final InvestigationResult result;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.chevron_left,
              color: KashfPalette.active.textPrimary,
              size: 24,
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                l.t('ir_screen_title'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.t('ir_action_share')),
                  backgroundColor: KashfColors.gold,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              Icons.share_outlined,
              color: KashfPalette.active.textPrimary,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              color: KashfPalette.active.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Hero card with overall confidence
//
// A vertically stacked "report header":
//
//   ┌────────────────────────────────────────────────────────┐
//   │  ▢  TITLE                                            │  ← big title +
//   │      Subtitle line                                   │     subtitle
//   │                                                    │
//   │  ┌──────┐  ● Sources · Items                         │  ← thumbnail + meta
//   │  │ IMG  │                                            │
//   │  └──────┘                                            │
//   │                                                    │
//   │  86%   Confidence ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔              │  ← confidence +
//   │        ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱                            │     progress
//   └────────────────────────────────────────────────────────┘
//
// Three independent rows give each element room to breathe,
// avoid horizontal cramping on narrow phones, and scale
// gracefully on wider screens without changing the design.
// ============================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final confidence = (result.confidence ?? 0) * 100;
    final thumbnail = result.thumbnailUrl;
    final palette = KashfPalette.active;
    final generatedAt = result.generatedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            palette.surface,
            palette.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: KashfColors.gold.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----- Header: status eyebrow + title -----
          Row(
            children: [
              _StatusEyebrow(l: l),
              const Spacer(),
              if (generatedAt != null)
                Text(
                  _formatTimestamp(generatedAt),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          autoDirection(
            result.title,
            Text(
              result.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isRtlText(result.title)
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          autoDirection(
            result.subtitle,
            Text(
              result.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isRtlText(result.subtitle)
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ----- Visual half / stats half -----
          //
          // Left: circular confidence ring with NN% in the middle,
          //       sources + items chips stacked underneath.
          // Right: large thumbnail of the investigated subject.
          //
          // Splitting the row in two equal halves lets the
          // thumbnail breathe on small phones and look deliberate
          // on wider ones, without the cramped three-column feel
          // of the previous layout.
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConfidenceRing(value: confidence / 100, l: l),
                    const SizedBox(height: 10),
                    _HeroMetaRow(
                      sourcesCount: result.sources.length,
                      itemsCount: result.sections.fold<int>(
                        0,
                        (sum, s) => sum + s.items.length,
                      ),
                      l: l,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _HeroThumbnail(url: thumbnail, l: l)),
            ],
          ),
        ],
      ),
    );
  }

  /// Short "Mar 14 · 14:23" timestamp. Falls back to a generic
  /// label when the timestamp can't be formatted.
  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[local.month - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$m ${local.day} · $hh:$mm';
  }
}

/// Small "Completed" eyebrow shown at the top of the hero card.
/// Lives next to the timestamp so the user always sees the run
/// status + when it finished in one glance.
class _StatusEyebrow extends StatelessWidget {
  const _StatusEyebrow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.t('home_latest_status_complete'),
            style: const TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero-card thumbnail. Now sized by [fit] — when wrapped in an
/// [Expanded] (the typical usage in the hero card) the tile fills
/// the right half of the row. Falls back to a flat icon tile when
/// the AI didn't provide an image URL or the network image fails.
///
/// `asset://` URLs (and any path that doesn't look like an
/// http(s) URL) are rendered via [Image.asset] so we can ship a
/// bundled default thumbnail without going through the network.
class _HeroThumbnail extends StatelessWidget {
  const _HeroThumbnail({required this.url, required this.l});
  final String? url;
  final AppLocalizations l;

  /// Square fallback shown when [url] is empty / fails to load.
  /// Constrained so the visual weight matches [_ConfidenceRing].
  static const double fallbackSize = 132;

  /// Returns true when [url] should be rendered as a bundled
  /// asset rather than fetched from the network. The
  /// [InvestigationThumbnailResolver] uses the `asset://` scheme
  /// to signal the default report thumbnail.
  bool _isAsset(String value) {
    if (value.startsWith('asset://')) return true;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return false;
    }
    // Treat anything else that looks like a path as an asset.
    return value.startsWith('assets/');
  }

  /// Strips the `asset://` scheme so we can hand the path to
  /// [Image.asset] directly.
  String _assetPath(String value) {
    if (value.startsWith('asset://')) return value.substring('asset://'.length);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final fallback = AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: KashfColors.gold.withValues(alpha: 0.30),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: KashfColors.gold.withValues(alpha: 0.7),
          size: 40,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;

    final source = url!;
    final child = _isAsset(source)
        ? Image.asset(
            _assetPath(source),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            source,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: palette.fieldFill,
                alignment: Alignment.center,
                child: const InlineSpinner(size: 22),
              );
            },
            errorBuilder: (_, _, _) => fallback,
          );

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

/// Circular confidence ring rendered as a determinate progress arc.
/// The "NN%" sits in the centre and the ring fills clockwise as the
/// score grows — no separate progress bar required.
class _ConfidenceRing extends StatelessWidget {
  const _ConfidenceRing({required this.value, required this.l});
  final double value;
  final AppLocalizations l;

  /// Outer diameter. Matches the height of [_HeroThumbnail] so the
  /// two halves of the row stay vertically balanced.
  static const double size = 132;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final pct = value.clamp(0.0, 1.0);
    final pctText = '${(pct * 100).round()}%';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _ConfidenceRingPainter(
              progress: pct,
              accent: KashfColors.gold,
              track: palette.fieldFill,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pctText,
                style: TextStyle(
                  color: KashfColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.t('ir_hero_confidence'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfidenceRingPainter extends CustomPainter {
  _ConfidenceRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6; // leave room for stroke

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // 12 o'clock
      progress.clamp(0.0, 1.0) * 6.28318,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceRingPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.track != track;
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({
    required this.sourcesCount,
    required this.itemsCount,
    required this.l,
  });
  final int sourcesCount;
  final int itemsCount;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _MetaChip(
          icon: Icons.link,
          label: l.tp('ir_meta_sources', {'n': '$sourcesCount'}),
        ),
        _MetaChip(
          icon: Icons.list_alt,
          label: l.tp('ir_meta_items', {'n': '$itemsCount'}),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: KashfPalette.active.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tabs row (one chip per section).
// ============================================================================
class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.sections,
    required this.active,
    required this.onSelect,
    required this.l,
  });

  final List<InvestigationResultSection> sections;
  final int active;
  final ValueChanged<int> onSelect;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // The screen is intentionally LTR (the back chevron, layout
    // direction, etc. are all LTR-first). The tab row is the one
    // element where we want to follow the user's reading direction
    // so Arabic users see the active tab pinned to the right edge
    // with its icon leading the label.
    final isRtl = l.language == AppLanguage.arabic;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // `reverse: true` shifts the scroll origin to the right edge
        // when the surrounding Directionality is LTR, which is what
        // an Arabic-reading user expects (overview = rightmost tab).
        reverse: isRtl,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sections[i];
          final selected = i == active;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? KashfColors.gold.withValues(alpha: 0.14)
                    : KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? KashfColors.gold
                      : KashfPalette.active.cardBorder,
                  width: selected ? 1.2 : 1,
                ),
              ),
              // Inside each chip, swap the icon/label order so the
              // leading visual matches the user's reading direction:
              // icon-then-text in English, text-then-icon in Arabic.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Icon(
                    s.kind.icon,
                    size: 14,
                    color: selected
                        ? KashfColors.gold
                        : KashfPalette.active.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.t(s.kind.l10nKey),
                    style: TextStyle(
                      color: selected
                          ? KashfColors.gold
                          : KashfPalette.active.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

// ============================================================================
// Section header (headline + summary).
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.l});
  final InvestigationResultSection section;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        autoDirection(
          section.headline,
          Text(
            section.headline,
            textAlign: isRtlText(section.headline)
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        autoDirection(
          section.summary,
          Text(
            section.summary,
            textAlign: isRtlText(section.summary)
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Item card — renders one [InvestigationResultItem].
// ============================================================================
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.l});
  final InvestigationResultItem item;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: autoDirection(
                  item.title,
                  Text(
                    item.title,
                    textAlign: isRtlText(item.title)
                        ? TextAlign.right
                        : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                _Badge(label: item.badge!),
              ],
            ],
          ),
          if (item.metric != null) ...[
            const SizedBox(height: 8),
            _MetricLine(metric: item.metric!, label: item.metricLabel),
          ],
          const SizedBox(height: 6),
          autoDirection(
            item.body,
            Text(
              item.body,
              textAlign:
                  isRtlText(item.body) ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KashfColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KashfColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: KashfColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Metric + label row used inside item cards.
///
/// The metric is rendered as a compact gold pill so the value
/// reads as a "stat" rather than a headline. The label sits
/// beside it as readable text. Both the metric pill and the
/// label respect the **label's** dominant script — so an
/// Arabic label renders the pill on the right and the label
/// aligned right, while an English label keeps the pill on
/// the left and the label aligned left.
class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.metric, required this.label});

  final String metric;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    // The line direction tracks the label when present, otherwise
    // the metric. RTL ⇒ pill on the right, label aligned right.
    final direction = hasLabel
        ? detectTextDirection(label!)
        : detectTextDirection(metric);
    final isRtl = direction == TextDirection.rtl;

    // Inline row when both metric + label are short; otherwise
    // stack vertically so the label can wrap on its own line.
    final useColumn = metric.length > 6 || (hasLabel && label!.length > 24);

    final pill = _MetricPill(text: metric);
    final labelWidget = hasLabel
        ? Directionality(
            textDirection: direction,
            child: Text(
              label!,
              maxLines: useColumn ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          )
        : null;

    if (useColumn) {
      // In RTL, the pill should sit at the trailing edge (right),
      // so we pin it to the end of the column's cross-axis.
      return Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(textDirection: direction, child: pill),
          if (labelWidget != null) ...[
            const SizedBox(height: 4),
            labelWidget,
          ],
        ],
      );
    }

    return Directionality(
      textDirection: direction,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          pill,
          if (labelWidget != null) ...[
            const SizedBox(width: 8),
            Expanded(child: labelWidget),
          ],
        ],
      ),
    );
  }
}

/// Compact gold pill that shows the metric value (e.g. "12%",
/// "+1.2M"). Uses a small fixed font so the value never grows
/// past its pill — that's what made the previous layout look
/// like a giant yellow headline.
class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KashfColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          color: KashfColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 32,
            color: KashfColors.gold,
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.t('ir_section_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Bottom action bar — 4 actions.
// ============================================================================
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        border: Border(top: BorderSide(color: KashfPalette.active.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.picture_as_pdf_outlined,
                label: l.t('ir_action_export_pdf'),
                onTap: () => _toast(context, l, 'ir_action_export_pdf'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.notifications_active_outlined,
                label: l.t('ir_action_monitor'),
                onTap: () => _toast(context, l, 'ir_action_monitor_toast'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.assignment_outlined,
                label: l.t('ir_action_report'),
                onTap: () => _toast(context, l, 'ir_action_report'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.bookmark_border,
                label: l.t('ir_action_save'),
                onTap: () => _toast(context, l, 'ir_action_save'),
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, AppLocalizations l, String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t(key)),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: filled
              ? KashfColors.gold
              : KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? KashfColors.gold : KashfPalette.active.cardBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.black : KashfColors.gold,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.black : KashfPalette.active.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
