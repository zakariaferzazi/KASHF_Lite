import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:flutter/material.dart';
import 'package:kashf_lite/widgets/loading_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../models/entity_type.dart';
import '../../models/investigation.dart';
import '../../models/investigation_result.dart';
import '../../models/saved_investigation.dart';
import '../../services/auto_refresh_service.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/pdf_media_store.dart';
import '../../services/report_pdf_writer.dart';
import '../../theme.dart';
import '../../utils/text_direction_utils.dart';

/// "نتائج التحقيق" / "Investigation Results" — the destination
/// screen the [InvestigationScreen] pushes to once the service
/// finishes a run.
///
/// Layout (top → bottom):
///   1. Top bar (back · title · share)            ← UNCHANGED
///   2. Redesigned dashboard content area         ← THIS REDESIGN
///   3. Bottom actions row (Export / Auto-refresh) ← UNCHANGED
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
                    // 1. Overview header card (subject + status + id/dates/confidence grid)
                    _OverviewHeaderCard(
                      result: widget.result,
                      sectionsCount: visible.length,
                      l: l,
                    ),
                    const SizedBox(height: 14),

                    // 2. Investigation lifecycle timeline — derived from
                    //    the existing InvestigationPhase enum (draft →
                    //    collecting → processing → analyzing → completed).
                    //    A completed result lights every step gold.
                    _LifecycleTimelineCard(l: l),
                    const SizedBox(height: 14),

                    // 3. Result tabs / categories — preserved 1:1
                    //    (same enum, same active state, same tap handler).
                    _TabsRow(
                      sections: visible,
                      active: activeIndex,
                      onSelect: (i) => setState(() => _activeSection = i),
                      l: l,
                    ),
                    const SizedBox(height: 14),

                    // 4. Main summary card — same data the old hero
                    //    card showed, restructured as a dashboard
                    //    panel: confidence ring + per-section bars.
                    _SummaryDashboardCard(
                      result: widget.result,
                      sections: visible,
                      l: l,
                    ),
                    const SizedBox(height: 14),

                    // 5. Statistics / metrics grid (icon + value + label)
                    _MetricsGridCard(
                      result: widget.result,
                      sections: visible,
                      l: l,
                    ),
                    const SizedBox(height: 14),

                    // 6. Active section content (headline + items)
                    _SectionHeader(section: section, l: l),
                    const SizedBox(height: 10),
                    for (final item in section.items) ...[
                      _ItemCard(item: item, l: l),
                      const SizedBox(height: 8),
                    ],
                    if (section.items.isEmpty) _EmptyState(l: l),

                    // 7. Recent activity / updates — existing sections
                    //    rendered as a timeline of headline+summary
                    //    entries stamped with the run's generatedAt.
                    if (visible.length > 1) ...[
                      const SizedBox(height: 18),
                      _RecentActivityTimeline(
                        result: widget.result,
                        sections: visible,
                        l: l,
                      ),
                    ],

                    // 8. Sources & references panel (unchanged behaviour)
                    if (widget.result.sources.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SourcesPanel(sources: widget.result.sources, l: l),
                    ],
                  ],
                ),
              ),
              _BottomActionsRow(result: widget.result, l: l),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar — back · title · share (real PDF).                              [KEPT]
// ============================================================================

/// Returns the platform-appropriate directory where reports
/// should be saved.
///
/// On Android we use `getExternalStorageDirectory()` which
/// points to the app's own external files directory
/// (`/storage/emulated/0/Android/data/<pkg>/files/` on
/// Android 10 and below, or a scoped directory on Android 11+).
/// This path is always writable by this app without any storage
/// permission — it is the app's private sandbox on external
/// storage. Files placed here are accessible to the
/// FileProvider declared in `AndroidManifest.xml`, which
/// generates a `content://` URI for sharing with PDF viewers.
Future<Directory> _reportsDirectory() async {
  Directory base;
  if (Platform.isAndroid) {
    try {
      base =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    } catch (_) {
      base = await getTemporaryDirectory();
    }
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    base =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
  } else {
    base = await getApplicationDocumentsDirectory();
  }
  final sep = Platform.pathSeparator;
  final reports = Directory('${base.path}${sep}KASHF Lite');
  if (!await reports.exists()) {
    await reports.create(recursive: true);
  }
  return reports;
}

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

  /// Generates a PDF, writes it to the app's external
  /// cache, and hands the file off to the platform default
  /// viewer via `url_launcher`. The FileProvider declared in
  /// AndroidManifest.xml converts the `file://` URI to a
  /// `content://` URI with a temporary read grant, so
  /// external PDF viewers can read the file without
  /// `FileUriExposedException`.
  ///
  /// Every step logs to logcat (`flutter logs`) via
  /// [debugPrint] so the failure mode is visible in
  /// `adb logcat | grep flutter`. The SnackBar only shows
  /// a compact message so the user can read what went
  /// wrong without us dumping a 500-char stack trace on
  /// screen.
  Future<void> _shareReport(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    debugPrint('[Kashf/SharePDF] start — id=${result.investigationId}');
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.t('ir_share_generating')),
        backgroundColor: KashfPalette.active.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final writer = ReportPdfWriter();
      final bytes = await writer.buildBytes(result: result);
      debugPrint('[Kashf/SharePDF] built ${bytes.length} bytes');
      final fileName = await writer.fileNameFor(result: result);
      final dir = await _reportsDirectory();
      debugPrint('[Kashf/SharePDF] reports dir = ${dir.path}');
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[Kashf/SharePDF] wrote file = ${file.path}');
      debugPrint('[Kashf/SharePDF] handing off to native openPdf');
      final result0 = await PdfMediaStore.openPdf(
        path: file.path,
        title: result.title,
      );
      debugPrint('[Kashf/SharePDF] openPdf -> $result0');
      if (result0.isNoHandler && context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'PDF saved. The app handler is out of date — '
              'reinstall the app to enable the preview.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (result0.isError && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'PDF viewer error: ${result0.message ?? result0.code}',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      // Always log the FULL error + stack trace to logcat.
      // `debugPrint` is wired to `print` which lands in
      // `adb logcat | grep flutter` on Android and the
      // Xcode console on iOS. The SnackBar only shows a
      // short hint so we don't bury the UI in a 500-char
      // exception dump.
      debugPrint('[Kashf/SharePDF] FAILED: $e');
      debugPrint('[Kashf/SharePDF] STACK: $st');
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF error (see logcat): ${e.runtimeType}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ============================================================================
// (1) Overview header card
//
// Subject identity (title + subtitle), investigator / status badge,
// and a 4-column metric grid (ID · date · confidence · sections count).
// All values come straight from the existing [InvestigationResult];
// nothing here is invented.
// ============================================================================
class _OverviewHeaderCard extends StatelessWidget {
  const _OverviewHeaderCard({
    required this.result,
    required this.sectionsCount,
    required this.l,
  });

  final InvestigationResult result;
  final int sectionsCount;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final confidence = ((result.confidence ?? 0) * 100).round();
    final status = _statusForResult(result);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- Subject row: avatar + name + status badge -----
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _OverviewAvatar(result: result, l: l),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    autoDirection(
                      result.title,
                      _InlineLinkText(
                        text: result.title,
                        baseStyle: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    autoDirection(
                      result.subtitle,
                      _InlineLinkText(
                        text: result.subtitle,
                        baseStyle: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: status.label, color: status.color),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: palette.divider, height: 1),
          const SizedBox(height: 18),

          // ----- 4-column metric grid (status / confidence / updated / created)
          // Each column shares the row width equally. The value text
          // uses FittedBox so long values (full dates) auto-shrink to
          // fit instead of being ellipsized. All four labels are in
          // Arabic — matching the reference design.
          // In RTL, the first child in the Row appears on the LEFT,
          // so the visual reading order (left → right) is:
          //   [status] [confidence] [updated] [created]
          // matching the reference image exactly.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. حالة التحقيق — status (left column in RTL)
              Expanded(
                child: _OverviewMetric(
                  label: l.t('ir_overview_status_label'),
                  value: l.t(InvestigationPhase.completed.l10nKey),
                  icon: Icons.flag_outlined,
                  l: l,
                  valueColor: KashfColors.gold,
                ),
              ),
              _OverviewDivider(),
              // 2. مستوى الثقة العام — overall confidence
              Expanded(
                child: _OverviewMetric(
                  label: l.t('ir_hero_confidence'),
                  value: '$confidence%',
                  icon: Icons.verified_outlined,
                  l: l,
                  valueColor: KashfColors.gold,
                ),
              ),
              _OverviewDivider(),
              // 3. آخر تحديث — last update date
              Expanded(
                child: _OverviewMetric(
                  label: l.t('ir_overview_updated_label'),
                  value: _formatDate(result.generatedAt),
                  icon: Icons.schedule_outlined,
                  l: l,
                ),
              ),
              _OverviewDivider(),
              // 4. تاريخ الإنشاء — creation date (right column in RTL)
              Expanded(
                child: _OverviewMetric(
                  label: l.t('ir_overview_created_label'),
                  value: _formatDate(result.generatedAt),
                  icon: Icons.calendar_today_outlined,
                  l: l,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders the investigation's generated timestamp as a real,
  /// full-precision date (year-month-day) so the user can tell
  /// when the report was produced — not just a placeholder.
  /// Returns an empty string when the timestamp is missing.
  String _formatDate(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '—';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  _StatusInfo _statusForResult(InvestigationResult r) {
    // The result screen is only reached for completed runs —
    // derive a "complete" status with a green dot to mirror the
    // existing eyebrow behaviour without inventing new data.
    final phase = InvestigationPhase.completed;
    final label = l.t(phase.l10nKey);
    return _StatusInfo(label: label, color: const Color(0xFF22C55E));
  }
}

class _StatusInfo {
  const _StatusInfo({required this.label, required this.color});
  final String label;
  final Color color;
}

class _OverviewAvatar extends StatelessWidget {
  const _OverviewAvatar({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final url = result.thumbnailUrl;
    const double size = 52;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        color: KashfColors.gold.withValues(alpha: 0.85),
        size: 26,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    final isAsset =
        url.startsWith('asset://') ||
        (!url.startsWith('http://') && !url.startsWith('https://'));
    final src = isAsset && url.startsWith('asset://')
        ? url.substring('asset://'.length)
        : url;
    final image = isAsset
        ? Image.asset(
            src,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            src,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, p) {
              if (p == null) return child;
              return Container(
                width: size,
                height: size,
                color: palette.fieldFill,
                alignment: Alignment.center,
                child: const InlineSpinner(size: 18),
              );
            },
          );
    return ClipRRect(borderRadius: BorderRadius.circular(14), child: image);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
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

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.l,
    this.valueColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final AppLocalizations l;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Value text direction follows its dominant script — numerals
    // and English/Latin IDs render LTR even inside an RTL column,
    // while Arabic labels render RTL.
    final valueIsRtl = _looksRtl(value);
    final valueDir = valueIsRtl ? TextDirection.rtl : TextDirection.ltr;

    // Row layout: [icon] [value] in LTR, [value] [icon] in RTL —
    // so the icon always anchors the outer (trailing) edge of the
    // cell regardless of reading direction, matching the reference.
    final iconWidget = Icon(icon, color: KashfColors.gold, size: 22);
    final valueWidget = Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: valueIsRtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Directionality(
          textDirection: valueDir,
          child: Text(
            value,
            textAlign: valueIsRtl ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: valueColor ?? palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ),
    );

    final valueRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: isRtl
          ? [valueWidget, const SizedBox(width: 8), iconWidget]
          : [iconWidget, const SizedBox(width: 8), valueWidget],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isRtl
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
      children: [
        // Label on top
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isRtl ? Alignment.centerRight : Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Icon + value side-by-side below
        valueRow,
      ],
    );
  }

  /// Lightweight script detection — Arabic / Hebrew characters
  /// make the value render RTL; everything else (numerals, Latin,
  /// punctuation) renders LTR. Used so a date like `2026-08-18`
  /// stays LTR even inside an RTL column.
  bool _looksRtl(String s) {
    for (final c in s.runes) {
      if (c >= 0x0590 && c <= 0x08FF) return true;
    }
    return false;
  }
}

class _OverviewDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Slim vertical separator — small horizontal margin so it
    // sits cleanly between cells without intruding on the icon
    // / value glyphs.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 1,
        height: 56,
        child: ColoredBox(color: KashfPalette.active.divider),
      ),
    );
  }
}

// ============================================================================
// (2) Investigation lifecycle timeline
//
// Horizontal process visualization built from the existing
// [InvestigationPhase] enum. Completed results light every
// step gold with a check mark — no new data, no invented
// stages, no fake progress.
// ============================================================================
class _LifecycleTimelineCard extends StatelessWidget {
  const _LifecycleTimelineCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              '${l.t('ir_phase_completed')} · ${l.t('ir_screen_title')}',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LifecycleTimelineBar(l: l),
        ],
      ),
    );
  }
}

class _LifecycleTimelineBar extends StatelessWidget {
  const _LifecycleTimelineBar({required this.l});
  final AppLocalizations l;

  /// Ordered phases that visually make up the run's lifecycle.
  /// Mirrors the existing InvestigationPhase progression in the
  /// model (no new states are introduced). "Failed" is omitted
  /// because the results screen is only shown for completed runs.
  List<InvestigationPhase> get _phases => const [
    InvestigationPhase.draft,
    InvestigationPhase.evidenceCollecting,
    InvestigationPhase.evidenceProcessing,
    InvestigationPhase.analyzing,
    InvestigationPhase.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return LayoutBuilder(
      builder: (context, constraints) {
        final phases = _phases;
        final nodeSize = 28.0;
        // Effective horizontal space available for the connector
        // segments between nodes — derived from the LayoutBuilder
        // so the bar stays responsive on narrow phones.
        final totalWidth = constraints.maxWidth;
        final step = (totalWidth - nodeSize) / (phases.length - 1);
        final gap = (step - nodeSize).clamp(2.0, 9999.0);

        return SizedBox(
          height: 56,
          child: Stack(
            children: [
              // Connector line behind the nodes
              Positioned(
                top: nodeSize / 2 - 1,
                left: nodeSize / 2,
                right: nodeSize / 2,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: palette.divider,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Filled gold connector indicating the run reached the end
              Positioned(
                top: nodeSize / 2 - 1,
                left: nodeSize / 2,
                right: nodeSize / 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    height: 2,
                    width: totalWidth - nodeSize,
                    decoration: BoxDecoration(
                      color: KashfColors.gold,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
              // Nodes
              for (var i = 0; i < phases.length; i++)
                Positioned(
                  left: i * (nodeSize + gap),
                  top: 0,
                  child: _LifecycleNode(phase: phases[i], size: nodeSize, l: l),
                ),
              // Labels under each node
              for (var i = 0; i < phases.length; i++)
                Positioned(
                  left: i * (nodeSize + gap) - 12,
                  top: nodeSize + 4,
                  width: nodeSize + 24,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _shortPhaseLabel(phases[i], l),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _shortPhaseLabel(InvestigationPhase p, AppLocalizations l) {
    // The full phase label is too long for a 28px column on small
    // phones — emit a single short word per phase to keep the
    // timeline scannable while remaining faithful to the model's
    // own l10n keys.
    switch (p) {
      case InvestigationPhase.draft:
        return l.t('ir_phase_draft');
      case InvestigationPhase.evidenceCollecting:
        return l.t('ir_phase_collecting');
      case InvestigationPhase.evidenceProcessing:
        return l.t('ir_phase_processing');
      case InvestigationPhase.analyzing:
        return l.t('ir_phase_analyzing');
      case InvestigationPhase.completed:
        return l.t('ir_phase_completed');
      case InvestigationPhase.failed:
        return l.t('ir_phase_failed');
    }
  }
}

class _LifecycleNode extends StatelessWidget {
  const _LifecycleNode({
    required this.phase,
    required this.size,
    required this.l,
  });
  final InvestigationPhase phase;
  final double size;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final isCompleted = phase == InvestigationPhase.completed;
    final isFailed = phase == InvestigationPhase.failed;
    final fill = isCompleted
        ? KashfColors.gold
        : (isFailed ? const Color(0xFFEF4444) : palette.surface);
    final border = isCompleted || isFailed ? fill : palette.cardBorder;
    final iconColor = (isCompleted || isFailed)
        ? Colors.black
        : palette.textSecondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.4),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: KashfColors.gold.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        isCompleted
            ? Icons.check_rounded
            : (isFailed ? Icons.close_rounded : _phaseIcon(phase)),
        size: size * 0.55,
        color: iconColor,
      ),
    );
  }

  IconData _phaseIcon(InvestigationPhase p) {
    switch (p) {
      case InvestigationPhase.draft:
        return Icons.edit_outlined;
      case InvestigationPhase.evidenceCollecting:
        return Icons.cloud_download_outlined;
      case InvestigationPhase.evidenceProcessing:
        return Icons.auto_awesome_outlined;
      case InvestigationPhase.analyzing:
        return Icons.psychology_outlined;
      case InvestigationPhase.completed:
        return Icons.check_rounded;
      case InvestigationPhase.failed:
        return Icons.close_rounded;
    }
  }
}

// ============================================================================
// (3) Tabs row (one chip per section).                                  [KEPT]
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
    final isRtl = l.language == AppLanguage.arabic;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
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
// (4) Main summary dashboard card
//
// Same data the old hero card exposed (overall confidence +
// per-section confidence), but laid out as a split panel: ring
// on the left, horizontal progress bars on the right.
// ============================================================================
class _SummaryDashboardCard extends StatelessWidget {
  const _SummaryDashboardCard({
    required this.result,
    required this.sections,
    required this.l,
  });

  final InvestigationResult result;
  final List<InvestigationResultSection> sections;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final overall = (result.confidence ?? 0).clamp(0.0, 1.0);
    final perSection = <_SectionConfidence>[];
    for (final s in sections) {
      // Prefer the section's own confidence (0..1); fall back to the
      // overall confidence if the model didn't emit a per-section
      // value. Either way the percentage shown is derived from the
      // existing confidence field — no invented metric.
      final c = (s.confidence ?? overall).clamp(0.0, 1.0);
      perSection.add(_SectionConfidence(label: l.t(s.kind.l10nKey), value: c));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.t('ir_overview_confidence_title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ConfidenceRing(value: overall, l: l),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final sc in perSection)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 6),
                          child: _ConfidenceBarLine(
                            label: sc.label,
                            value: sc.value,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (perSection.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.t('ir_section_empty'),
              style: TextStyle(color: palette.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionConfidence {
  const _SectionConfidence({required this.label, required this.value});
  final String label;
  final double value;
}

class _ConfidenceBarLine extends StatelessWidget {
  const _ConfidenceBarLine({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final pct = value.clamp(0.0, 1.0);
    final pctText = '${(pct * 100).round()}%';
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: palette.fieldFill),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: KashfColors.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            pctText,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KashfColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// (5) Statistics / metrics grid
//
// A 4-column grid of metric cards (label + value + icon). Each metric
// is derived from existing data: item counts per section + sources
// count + overall confidence. No invented numbers.
// ============================================================================
class _MetricsGridCard extends StatelessWidget {
  const _MetricsGridCard({
    required this.result,
    required this.sections,
    required this.l,
  });

  final InvestigationResult result;
  final List<InvestigationResultSection> sections;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    // Per-section item counts (existing data) — first 4 sections in
    // the canonical order, with any overflow joined into a single
    // "others" tile so the grid stays 4 wide.
    final first = sections.take(3).toList();
    final overflow = sections
        .skip(3)
        .fold<int>(0, (s, x) => s + x.items.length);

    final tiles = <_MetricTile>[
      for (final s in first)
        _MetricTile(
          icon: s.kind.icon,
          label: l.t(s.kind.l10nKey),
          value: '${s.items.length}',
        ),
      if (overflow > 0)
        _MetricTile(
          icon: Icons.more_horiz,
          label: l.t('home_latest_sections'),
          value: '$overflow',
        ),
      _MetricTile(
        icon: Icons.link,
        label: l.t('ir_sources_title'),
        value: '${result.sources.length}',
      ),
    ];
    // Always pad to 4 tiles so the grid stays consistent — uses
    // existing derived totals (no fake data).
    while (tiles.length < 4) {
      tiles.add(
        _MetricTile(
          icon: Icons.list_alt,
          label: l.t('ir_metric_items'),
          value:
              '${result.sections.fold<int>(0, (sum, s) => sum + s.items.length)}',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.t('home_latest_stats'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (final t in tiles.take(8)) _MetricTileCard(tile: t, l: l),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class _MetricTileCard extends StatelessWidget {
  const _MetricTileCard({required this.tile, required this.l});
  final _MetricTile tile;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tile.icon, color: KashfColors.gold, size: 18),
          const SizedBox(height: 6),
          Text(
            tile.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              tile.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// (6) Section header (headline + summary).                             [KEPT]
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
// (6b) Recent activity / updates timeline
//
// Renders every visible section as a timeline entry using its
// existing headline + summary + the run's generatedAt timestamp.
// All values come from existing data.
// ============================================================================
class _RecentActivityTimeline extends StatelessWidget {
  const _RecentActivityTimeline({
    required this.result,
    required this.sections,
    required this.l,
  });

  final InvestigationResult result;
  final List<InvestigationResultSection> sections;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.t('home_latest_recent_activity'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sections.length; i++) ...[
            _ActivityRow(
              section: sections[i],
              isFirst: i == 0,
              isLast: i == sections.length - 1,
              timestamp: result.generatedAt,
              l: l,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.section,
    required this.isFirst,
    required this.isLast,
    required this.timestamp,
    required this.l,
  });

  final InvestigationResultSection section;
  final bool isFirst;
  final bool isLast;
  final DateTime timestamp;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail (line + dot)
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : palette.divider,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: KashfColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KashfColors.gold.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : palette.divider,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        section.kind.icon,
                        size: 14,
                        color: KashfColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: autoDirection(
                          section.headline,
                          Text(
                            section.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (section.summary.isNotEmpty)
                    autoDirection(
                      section.summary,
                      Text(
                        section.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

// ============================================================================
// Item card — renders one [InvestigationResultItem].                    [KEPT]
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
  if (l.contains('website') || l.contains('site') || l.contains('blog')) {
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
/// replaces each one with a [_UrlChipButton].
class _InlineLinkText extends StatelessWidget {
  const _InlineLinkText({
    required this.text,
    required this.baseStyle,
    this.maxLines,
  });

  final String text;
  final TextStyle baseStyle;
  final int? maxLines;

  static const String _trailingPunct = '.,;:]}';

  List<_InlineRun> _splitIntoRuns() {
    final runs = <_InlineRun>[];
    var cursor = 0;
    for (final match in _kUrlPattern.allMatches(text)) {
      if (match.start > cursor) {
        runs.add(_InlineRun.text(text.substring(cursor, match.start)));
      }
      var url = match.group(0)!;
      var trimmed = '';
      while (url.isNotEmpty && _trailingPunct.contains(url.characters.last)) {
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

    if (!containsLink) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      );
    }

    final children = <InlineSpan>[];
    for (final r in runs) {
      if (r.isText) {
        children.add(TextSpan(text: r.text, style: baseStyle));
      } else {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _UrlChipButton(
              url: r.url!,
              label: shortLabelForUrl(r.url!),
              dense: true,
            ),
          ),
        );
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
/// of the active section.
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
                    label: s.title.isNotEmpty
                        ? s.title
                        : shortLabelForUrl(s.url!),
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

/// Metric + label row used inside item cards.                [KEPT]
class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.metric, required this.label});

  final String metric;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    final direction = hasLabel
        ? detectTextDirection(label!)
        : detectTextDirection(metric);
    final isRtl = direction == TextDirection.rtl;

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
      return Column(
        crossAxisAlignment: isRtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(textDirection: direction, child: pill),
          if (labelWidget != null) ...[const SizedBox(height: 4), labelWidget],
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

/// Compact gold pill that shows the metric value.            [KEPT]
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
          const Icon(Icons.inbox_outlined, size: 32, color: KashfColors.gold),
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
// Circular confidence ring rendered as a determinate progress arc.      [KEPT]
// ============================================================================
class _ConfidenceRing extends StatelessWidget {
  const _ConfidenceRing({required this.value, required this.l});
  final double value;
  final AppLocalizations l;

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
    final radius = size.shortestSide / 2 - 6;

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
      -1.5708,
      progress.clamp(0.0, 1.0) * 6.28318,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceRingPainter old) =>
      old.progress != progress || old.accent != accent || old.track != track;
}

// ============================================================================
// Bottom action bar — Export PDF + Stop auto-refresh.                  [KEPT]
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
    debugPrint('[Kashf/ExportPDF] start — id=${widget.result.investigationId}');
    try {
      final writer = ReportPdfWriter();
      final bytes = await writer.buildBytes(result: widget.result);
      debugPrint('[Kashf/ExportPDF] built ${bytes.length} bytes');
      final fileName = await writer.fileNameFor(result: widget.result);

      final dir = await _reportsDirectory();
      debugPrint('[Kashf/ExportPDF] reports dir = ${dir.path}');
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[Kashf/ExportPDF] wrote file = ${file.path}');

      // Surface a "saved" SnackBar with the leaf path so the
      // user knows where the PDF landed.
      final summary =
          '${dir.path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last}/$fileName';
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.tp('ir_export_saved_to', {'name': summary}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Open with the default handler. On Android the native
      // side wraps the `file://` URI in a `content://` URI
      // via FileProvider + FLAG_GRANT_READ_URI_PERMISSION
      // so external PDF viewers can read the file without
      // `FileUriExposedException`. The chooser dialog shows
      // every installed viewer (Drive, Files, Gmail, Adobe
      // Acrobat, etc).
      debugPrint('[Kashf/ExportPDF] handing off to native openPdf');
      final result0 = await PdfMediaStore.openPdf(
        path: file.path,
        title: widget.result.title,
      );
      debugPrint('[Kashf/ExportPDF] openPdf -> $result0');
      if (result0.isNoHandler && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'PDF saved. The app handler is out of date — '
              'reinstall the app to enable the preview.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (result0.isError && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'PDF viewer error: ${result0.message ?? result0.code}',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      // Log the FULL error + stack trace to logcat via
      // `debugPrint`. The SnackBar only shows a short
      // hint so the UI stays readable.
      debugPrint('[Kashf/ExportPDF] FAILED: $e');
      debugPrint('[Kashf/ExportPDF] STACK: $st');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF error (see logcat): ${e.runtimeType}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : _exportAndOpen,
        style: ElevatedButton.styleFrom(
          backgroundColor: KashfColors.gold,
          disabledBackgroundColor: KashfColors.gold.withValues(alpha: 0.4),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Text(
          l.t('ir_action_export_pdf'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Auto-refresh bar — shows a small "Auto-refresh on" hint plus         [KEPT]
// a Stop button. Always visible because every new investigation
// is auto-tracked by the archive service; tapping Stop clears
// the 60-day window so the background scheduler stops
// re-running the report.
// ============================================================================
class _AutoRefreshBar extends StatefulWidget {
  const _AutoRefreshBar({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  State<_AutoRefreshBar> createState() => _AutoRefreshBarState();
}

class _AutoRefreshBarState extends State<_AutoRefreshBar> {
  bool _busy = false;

  Future<void> _stopAutoRefresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = widget.l;
    final messenger = ScaffoldMessenger.of(context);
    final archive = InvestigationArchiveService.instance;
    SavedInvestigation? saved;
    for (var attempt = 0; attempt < 4; attempt++) {
      final rows = await archive.allForActiveUser();
      for (final r in rows) {
        if (r.id == widget.result.investigationId) {
          saved = r;
          break;
        }
      }
      if (saved != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    saved ??= SavedInvestigation(
      id: widget.result.investigationId,
      userId: 'anonymous',
      title: widget.result.title,
      subtitle: widget.result.subtitle,
      entityType: EntityType.brand,
      status: InvestigationStatus.completed,
      confidencePercent: 60,
      confidenceBand: 'medium',
      tags: const [],
      createdAt: widget.result.generatedAt,
    );
    try {
      await AutoRefreshService.instance.stopAutoRefresh(saved);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: KashfPalette.active.surface,
          content: Text(
            l.t('ir_auto_refresh_stopped_toast'),
            style: TextStyle(color: KashfPalette.active.textPrimary),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString()),
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
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _stopAutoRefresh,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: palette.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(KashfColors.gold),
                ),
              )
            : const Icon(Icons.stop, size: 16, color: Colors.red),
        label: Text(
          l.t('ir_auto_refresh_stop_button'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ============================================================================
// Single-row wrapper that hosts the Export-PDF button and the          [KEPT]
// Auto-refresh Stop button side-by-side. The two inner widgets
// are responsible for their own button chrome; this row supplies
// the shared surface, top border, padding, and SafeArea so the
// two buttons read as one cohesive action bar rather than two
// stacked blocks.
// ============================================================================
class _BottomActionsRow extends StatelessWidget {
  const _BottomActionsRow({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  /// Only Nawaff can export PDFs.
  static const String _kExportEmail = 'Nawaff89@gmail.com';

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final userEmail = user?.email?.trim().toLowerCase() ?? '';
            final canExport = userEmail == _kExportEmail.toLowerCase();
            return Row(
              children: [
                if (canExport)
                  Expanded(
                    flex: 3,
                    child: _ExportPdfBar(result: result, l: l),
                  ),
                if (canExport) const SizedBox(width: 10),
                Expanded(
                  flex: canExport ? 2 : 1,
                  child: _AutoRefreshBar(result: result, l: l),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
