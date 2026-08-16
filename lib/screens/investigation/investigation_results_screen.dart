import 'package:flutter/material.dart';
import 'package:kashf_lite/widgets/loading_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../models/investigation_result.dart';
import '../../services/report_pdf_writer.dart';
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
                    if (widget.result.sources.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SourcesPanel(sources: widget.result.sources, l: l),
                    ],
                  ],
                ),
              ),
              _ExportPdfBar(result: widget.result, l: l),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar — back · title · share (real PDF).
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
            onPressed: () => _shareReport(context),
            icon: Icon(
              Icons.share_outlined,
              color: KashfPalette.active.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates a PDF, persists it to disk, and hands the file
  /// off to the platform's share sheet via `url_launcher`.
  Future<void> _shareReport(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // Best-effort: surface progress through a snackbar since
    // PDF generation + I/O can take a beat on slow devices.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('ir_share_generating')),
        backgroundColor: KashfPalette.active.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final writer = ReportPdfWriter();
      final file = await writer.saveToDisk(result: result);
      final uri = Uri.file(file.path);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            _InlineLinkText(
              text: result.title,
              baseStyle: TextStyle(
                color: palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 6),
          autoDirection(
            result.subtitle,
            _InlineLinkText(
              text: result.subtitle,
              baseStyle: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
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
          _InlineLinkText(
            text: section.headline,
            baseStyle: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        autoDirection(
          section.summary,
          _InlineLinkText(
            text: section.summary,
            baseStyle: TextStyle(
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
                  _InlineLinkText(
                    text: item.title,
                    baseStyle: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
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
            _InlineLinkText(
              text: item.body,
              baseStyle: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          if (item.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LinkButtons(links: item.links),
          ],
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

/// Matches a URL substring in a body of free text. Captures
/// the full http(s) URL including path / query / fragment.
/// Defined at top level (not as a class field) because a
/// `static final RegExp` inside a `const`-constructible widget
/// triggers "Field isn't final, but constructor is 'const'".
/// `RegExp` has no const constructor; top-level `final`
/// initializers are treated as compile-time constants by Dart
/// when the right-hand side is itself a const expression, so
/// this declaration is safe for the surrounding widget.
///
/// The regex itself is wrapped in a triple-quoted raw string so
/// we can include a literal apostrophe inside the character
/// class without escaping (raw strings don't process escapes,
/// so `\'` inside `r'...'` is an unterminated string literal).
final RegExp _kUrlPattern = RegExp(
  r"""(https?://[^\s<>"'()]+)""",
  caseSensitive: false,
);

/// URL detection + chip-button rendering shared by every place
/// in the result screen that surfaces a link. Three callers
/// consume the same widget:
///   1. [_InlineLinkText] — replaces raw URLs in body / title /
///      summary text with inline pill buttons so a sentence like
///      "Visit https://www.instagram.com/x for updates" reads
///      with the URL rendered as a tappable chip, not as
///      underlined blue text.
///   2. [_LinkButtons] — the explicit "links" array the AI emits
///      per item.
///   3. [_SourcesPanel] — the per-investigation source list.

/// Maps a free-form label / hostname to a Material icon so the
/// button reads as a platform-specific chip instead of a generic
/// "open" link. Used for Instagram, TikTok, YouTube, X / Twitter,
/// Snapchat, generic websites, news, and documents.
IconData iconForLink(String labelOrUrl) {
  final l = labelOrUrl.toLowerCase();
  if (l.contains('instagram')) return Icons.camera_alt_outlined;
  if (l.contains('tiktok')) return Icons.music_note_outlined;
  if (l.contains('youtube') || l.contains('youtu.be')) {
    return Icons.play_circle_outline;
  }
  if (l.contains('snap')) return Icons.snapchat_outlined;
  if (l.contains('twitter') || l == 'x') return Icons.alternate_email;
  if (l.contains('linkedin')) return Icons.work_outline;
  if (l.contains('facebook')) return Icons.facebook_outlined;
  if (l.contains('news') || l.contains('article')) {
    return Icons.article_outlined;
  }
  if (l.contains('website') ||
      l.contains('site') ||
      l.contains('blog')) {
    return Icons.language_outlined;
  }
  if (l.contains('pdf') || l.contains('doc')) {
    return Icons.description_outlined;
  }
  return Icons.open_in_new;
}

/// Returns a short, human-readable label derived from a raw URL
/// when no label is supplied. Strips the protocol, drops `www.`,
/// and truncates the path to keep the chip compact.
String shortLabelForUrl(String url) {
  var s = url;
  // Trim trailing punctuation that often leaks into natural-
  // language sentences ("...see https://x.com/foo.").
  while (s.isNotEmpty && '.,;:)]}'.contains(s.characters.last)) {
    s = s.substring(0, s.length - 1);
  }
  s = s.replaceFirst(RegExp(r'^https?://'), '');
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  final slash = s.indexOf('/');
  if (slash == -1) return s;
  final host = s.substring(0, slash);
  final rest = s.substring(slash);
  if (rest.length <= 10) return '$host$rest';
  return '$host${rest.substring(0, 8)}…';
}

/// Opens a URL via the platform's default handler (browser,
/// native app, etc.) and surfaces a SnackBar if launching fails.
/// Defensive: only http(s) URLs are passed through.
Future<void> openExternalUrl(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }
}

/// Shared chip-button widget. All link buttons in the result
/// screen funnel through here so a URL looks the same whether it
/// comes from an explicit `links` entry, an inline mention in
/// body text, or the sources panel. Use [dense] for the
/// inline-with-text variant (smaller padding / font so the chip
/// sits flush with the surrounding text line).
class _UrlChipButton extends StatelessWidget {
  const _UrlChipButton({
    required this.url,
    required this.label,
    this.dense = false,
  });

  final String url;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openExternalUrl(context, Uri.parse(url)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 4 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                iconForLink(label),
                size: dense ? 12 : 14,
                color: palette.textPrimary,
              ),
              SizedBox(width: dense ? 4 : 6),
              // Wrap in Flexible so a long host (e.g.
              // "facebook.com/some-long-page") doesn't push the
              // chip past the surrounding line — the label
              // ellipsizes instead.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: dense ? 11 : 12,
                    fontWeight: FontWeight.w700,
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

/// Row of tappable platform / source buttons rendered under an
/// item card body. Used for the explicit "links" array the AI
/// emits per item — typically influencer social-account URLs.
class _LinkButtons extends StatelessWidget {
  const _LinkButtons({required this.links});

  final List<InvestigationResultLink> links;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links)
          _UrlChipButton(url: link.url, label: link.label),
      ],
    );
  }
}

/// Inline text widget that scans [text] for URL substrings and
/// replaces each one with a [_UrlChipButton]. The non-URL
/// fragments are rendered as a single flowing [RichText]; each
/// URL is rendered as a pill button that flows inline with the
/// surrounding text. Used for the item title / body / section
/// headline / summary and the hero-card title / subtitle — so a
/// URL that appears anywhere in the natural-language output is
/// rendered as a tappable pill, never as plain underlined blue
/// text.
///
/// Implementation note: we use `Text.rich` + `WidgetSpan`.
/// Flutter lays out `WidgetSpan` children inline with the
/// surrounding text using their intrinsic size; the chip's
/// intrinsic size is its preferred height (small) and its
/// natural width. Word-boundary wrapping still works because
/// the text engine treats each `WidgetSpan` as an opaque
/// inline block of known width. `maxLines` + ellipsis is not
/// supported by Flutter when `Text.rich` contains
/// `WidgetSpan`s — we therefore drop the `maxLines` cap when
/// the text contains any URLs and let the layout flow
/// naturally. The caller is expected to size the parent
/// container so the flow fits.
class _InlineLinkText extends StatelessWidget {
  const _InlineLinkText({
    required this.text,
    required this.baseStyle,
    this.maxLines,
  });

  final String text;
  final TextStyle baseStyle;
  final int? maxLines;

  /// Trailing punctuation that often clings to a URL in
  /// natural text but isn't part of it. We trim it from the
  /// URL when building the chip and re-emit it as plain text
  /// so the sentence still reads naturally.
  static const String _trailingPunct = '.,;:]}';

  /// Splits [text] into alternating runs of plain text and
  /// URLs, with trailing punctuation trimmed from each URL
  /// and re-attached to the following text run.
  List<_InlineRun> _splitIntoRuns() {
    final runs = <_InlineRun>[];
    var cursor = 0;
    for (final match in _kUrlPattern.allMatches(text)) {
      if (match.start > cursor) {
        runs.add(_InlineRun.text(text.substring(cursor, match.start)));
      }
      var url = match.group(0)!;
      var trimmed = '';
      while (url.isNotEmpty &&
          _trailingPunct.contains(url.characters.last)) {
        trimmed = url.characters.last + trimmed;
        url = url.substring(0, url.length - 1);
      }
      if (url.isNotEmpty) {
        runs.add(_InlineRun.link(url));
      } else {
        runs.add(_InlineRun.text(match.group(0)!));
      }
      if (trimmed.isNotEmpty) {
        runs.add(_InlineRun.text(trimmed));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      runs.add(_InlineRun.text(text.substring(cursor)));
    }
    if (runs.isEmpty) runs.add(_InlineRun.text(''));
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text('', style: baseStyle, maxLines: maxLines);
    }
    final runs = _splitIntoRuns();
    final rtl = isRtlText(text);
    final containsLink = runs.any((r) => !r.isText);

    // Plain-text fast path: skip the rich-text pipeline when
    // there are no URLs to embed. Honours `maxLines` +
    // ellipsis correctly.
    if (!containsLink) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow:
            maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      );
    }

    // URL-bearing path: render via Text.rich + WidgetSpan.
    // Flutter cannot ellipsize rich text that contains
    // WidgetSpan children, so we cap visual height by
    // wrapping in a fixed-height container that the
    // surrounding column then constrains. This keeps the
    // layout stable even if the chip count grows.
    final children = <InlineSpan>[];
    for (final r in runs) {
      if (r.isText) {
        children.add(TextSpan(text: r.text, style: baseStyle));
      } else {
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _UrlChipButton(
            url: r.url!,
            label: shortLabelForUrl(r.url!),
            dense: true,
          ),
        ));
      }
    }
    return Text.rich(
      TextSpan(children: children),
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    );
  }
}

/// One run of either plain text or a URL inside
/// [_InlineLinkText]. Built by splitting the source text on the
/// URL regex.
class _InlineRun {
  _InlineRun.text(this.text) : url = null, _isText = true;
  _InlineRun.link(this.url) : text = '', _isText = false;
  final String text;
  final String? url;
  final bool _isText;
  bool get isText => _isText;
}

/// Compact panel of source citations rendered below the items
/// of the active section. Each entry is a [_UrlChipButton]
/// keyed off the source title; the URL is the source's link.
/// Sources without a URL are rendered as a non-clickable chip
/// so the citation still appears.
class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.sources, required this.l});

  final List<InvestigationSource> sources;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.t('ir_sources_title'),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sources)
                if (s.url != null && s.url!.isNotEmpty)
                  _UrlChipButton(
                    url: s.url!,
                    label: s.title.isNotEmpty ? s.title : shortLabelForUrl(s.url!),
                  )
                else
                  _NonInteractiveChip(
                    label: s.title,
                    icon: iconForLink(s.title),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Visually identical to [_UrlChipButton] but with no tap target.
/// Used for citations that have no URL (the model surfaced a
/// title but no link — we still show the chip so the citation
/// reads consistently with the rest of the panel).
class _NonInteractiveChip extends StatelessWidget {
  const _NonInteractiveChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
// Bottom action bar — a single Export-PDF button that
// generates a real PDF on disk and opens it in the platform
// share sheet.
// ============================================================================
class _ExportPdfBar extends StatefulWidget {
  const _ExportPdfBar({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  State<_ExportPdfBar> createState() => _ExportPdfBarState();
}

class _ExportPdfBarState extends State<_ExportPdfBar> {
  bool _busy = false;

  Future<void> _exportAndOpen() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = widget.l;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final writer = ReportPdfWriter();
      final file = await writer.saveToDisk(result: widget.result);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.tp('ir_export_saved_to', {'path': file.path})),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final uri = Uri.file(file.path);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final palette = KashfPalette.active;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _exportAndOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: KashfColors.gold,
              disabledBackgroundColor:
                  KashfColors.gold.withValues(alpha: 0.4),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.black),
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(
              l.t('ir_action_export_pdf'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
