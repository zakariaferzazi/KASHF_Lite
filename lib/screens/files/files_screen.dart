import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// "My Active Files" screen — a strict, pixel-perfect recreation of
/// the provided reference screenshot.
///
/// The reference is an Arabic-language RTL screen whose *visual*
/// layout is LTR (back arrow on the left, image on the left,
/// bottom-nav Reports on the left). To preserve that 1:1 visual
/// mapping, the screen is rendered as `TextDirection.ltr` for the
/// layout while the text content itself flows RTL.
///
/// Layout (top → bottom):
///   1. Status bar mock (time on left + signal/wifi/battery on right)
///   2. Top bar (back + folder+title + page chip + 3-dot menu)
///   3. KPI row (4 cards)
///   4. Search field with filter on the right
///   5. List of file cards
///   6. Bottom navigation (Reports · Pulse · FAB · Explore · Home)
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      // The visual layout mirrors the reference exactly: back arrow,
      // card images, and bottom-nav "Reports" all sit on the left edge.
      // The Arabic strings still flow right-to-left inside their text
      // widgets.
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              _TopBar(l: l),
              const SizedBox(height: 12),
              _KpiRow(l: l),
              const SizedBox(height: 12),
              _SearchBar(l: l),
              const SizedBox(height: 12),
              _FileCard(
                l: l,
                title: l.t('mf_file1_title'),
                imageAsset: 'assets/images/parfum.jpeg',
                statusLabel: l.t('mf_status_viral'),
                statusColor: const Color(0xFFF4C542),
                metric1Value: '328',
                metric1Label: l.t('mf_metric_posts'),
                metric2Value: '24',
                metric2Label: l.t('mf_metric_source'),
                metric3Value: '15',
                metric3Label: l.t('mf_metric_days'),
                progressValue: 0.72,
                progressLabel: l.t('mf_progress_v'),
                progressColor: const Color(0xFFF4C542),
                avatars: const [
                  'assets/images/logoprofile.jpg',
                  'assets/images/logoprofile2.jpg',
                  'assets/images/logoprofile1.jpg',
                ],
                extraCount: 3,
              ),
              const SizedBox(height: 8),
              _FileCard(
                l: l,
                title: l.t('mf_file2_title'),
                imageAsset: 'assets/images/winner.jpeg',
                statusLabel: l.t('mf_status_under'),
                statusColor: const Color(0xFF22C55E),
                metric1Value: '286',
                metric1Label: l.t('mf_metric_posts'),
                metric2Value: '18',
                metric2Label: l.t('mf_metric_source'),
                metric3Value: '5',
                metric3Label: l.t('mf_metric_days'),
                progressValue: 0.65,
                progressLabel: l.t('mf_progress_n'),
                progressColor: const Color(0xFF22C55E),
                avatars: const [
                  'assets/images/logoprofile2.jpg',
                  'assets/images/logoprofile.jpg',
                ],
                extraCount: 2,
              ),
              const SizedBox(height: 8),
              _FileCard(
                l: l,
                title: l.t('mf_file3_title'),
                imageAsset: 'assets/images/lattafa.jpeg',
                statusLabel: l.t('mf_status_under'),
                statusColor: const Color(0xFF60A5FA),
                metric1Value: '142',
                metric1Label: l.t('mf_metric_posts'),
                metric2Value: '12',
                metric2Label: l.t('mf_metric_source'),
                metric3Value: '40',
                metric3Label: l.t('mf_metric_minutes'),
                progressValue: 0.48,
                progressLabel: l.t('mf_progress_l'),
                progressColor: const Color(0xFF60A5FA),
                avatars: const [
                  'assets/images/logoprofile.jpg',
                ],
                extraCount: 1,
              ),
              const SizedBox(height: 8),
              _FileCard(
                l: l,
                title: l.t('mf_file4_title'),
                imageAsset: 'assets/images/mic.jpeg',
                statusLabel: l.t('mf_status_review'),
                statusColor: const Color(0xFFEF4444),
                metric1Value: '174',
                metric1Label: l.t('mf_metric_posts'),
                metric2Value: '16',
                metric2Label: l.t('mf_metric_source'),
                metric3Value: '6',
                metric3Label: l.t('mf_metric_hours'),
                progressValue: 0.28,
                progressLabel: l.t('mf_progress_s'),
                progressColor: const Color(0xFFEF4444),
                avatars: const [
                  'assets/images/logoprofile2.jpg',
                  'assets/images/logoprofile1',
                ],
                extraCount: 2,
              ),
              const SizedBox(height: 8),
              _FileCard(
                l: l,
                title: l.t('mf_file5_title'),
                imageAsset: 'assets/images/sauvage.jpeg',
                statusLabel: l.t('mf_status_progress'),
                statusColor: const Color(0xFFF4C542),
                metric1Value: '210',
                metric1Label: l.t('mf_metric_posts'),
                metric2Value: '20',
                metric2Label: l.t('mf_metric_source'),
                metric3Value: '2',
                metric3Label: l.t('mf_metric_days'),
                progressValue: 1.0,
                progressLabel: l.t('mf_progress_a'),
                progressColor: const Color(0xFFFFFFFF),
                avatars: const [
                  'assets/images/logoprofile.jpg',
                  'assets/images/logoprofile2.jpg',
                  'assets/images/logoprofile1',
                ],
                extraCount: 4,
                buttonLabel: l.t('mf_open_file'),
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
//   [back]  [title+icon]  [page chip]  [3-dot menu]
//
// The folder icon + Arabic title group sits between the back button
// (left) and the page chip (right). The Arabic title still flows
// right-to-left inside its own text widget.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BackIcon(),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_outlined,
                color: KashfColors.gold,
                size: 22,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.t('mf_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const _PageChip(label: '1/3'),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          shape: BoxShape.circle,
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: KashfPalette.active.textPrimary,
          size: 14,
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
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          shape: BoxShape.circle,
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Icon(
          Icons.more_vert,
          color: KashfPalette.active.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: KashfPalette.active.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================ KPI Row ============================
//
// Visual order (left → right) in the reference:
//   [Total files 8] [Under review 3] [Updated today 4] [Needs review 1]
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.circle_outlined,
            iconColor: const Color(0xFF60A5FA),
            value: '8',
            label: l.t('mf_kpi_total'),
            subLabel: l.t('mf_kpi_total_sub'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.access_time,
            iconColor: const Color(0xFFF4C542),
            value: '3',
            label: l.t('mf_kpi_pending'),
            subLabel: l.t('mf_kpi_pending_sub'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.update,
            iconColor: const Color(0xFF22C55E),
            value: '4',
            label: l.t('mf_kpi_updated'),
            subLabel: l.t('mf_kpi_updated_sub'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFEF4444),
            value: '1',
            label: l.t('mf_kpi_review'),
            subLabel: l.t('mf_kpi_review_sub'),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subLabel,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String subLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Arabic label flows right-to-left even though the parent
          // Row is LTR.
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              subLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Search Bar ============================
//
// Reference: search icon on the LEFT, hint text in the middle, filter
// icon on the RIGHT.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          // Search icon on the LEFT.
          Icon(
            Icons.search,
            color: KashfPalette.active.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                l.t('mf_search_hint'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Filter button on the RIGHT.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KashfPalette.active.fieldFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            child: Icon(
              Icons.tune,
              color: KashfPalette.active.textPrimary,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ File Card ============================
//
// Visual order (left → right) in the reference:
//   [thumbnail]  [title row + status pill]  [more-vert icon]
// then
//   [3 metrics row]                            [progress label + value]
//   [progress bar full width]
//   [contributors stack]            [open-file pill button]
class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.l,
    required this.title,
    required this.imageAsset,
    required this.statusLabel,
    required this.statusColor,
    required this.metric1Value,
    required this.metric1Label,
    required this.metric2Value,
    required this.metric2Label,
    required this.metric3Value,
    required this.metric3Label,
    required this.progressValue,
    required this.progressLabel,
    required this.progressColor,
    required this.avatars,
    required this.extraCount,
    this.buttonLabel,
  });

  final AppLocalizations l;
  final String title;
  final String imageAsset;
  final String statusLabel;
  final Color statusColor;
  final String metric1Value;
  final String metric1Label;
  final String metric2Value;
  final String metric2Label;
  final String metric3Value;
  final String metric3Label;
  final double progressValue;
  final String progressLabel;
  final Color progressColor;
  final List<String> avatars;
  final int extraCount;
  final String? buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          // Row 1: thumbnail · title+status · more-vert (LTR visual order).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imageAsset: imageAsset),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: KashfPalette.active.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(7, 1, 7, 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            statusLabel,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.more_vert,
                color: KashfPalette.active.textSecondary,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: 3 metrics on the LEFT, progress label/value on the RIGHT.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.description_outlined,
                  value: metric1Value,
                  label: metric1Label,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _Metric(
                  icon: Icons.access_time,
                  value: metric2Value,
                  label: metric2Label,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _Metric(
                  icon: Icons.event_outlined,
                  value: metric3Value,
                  label: metric3Label,
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      l.t('mf_progress_label'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    progressLabel,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 4,
              backgroundColor:
                  KashfPalette.active.cardBorder.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 6),
          // Row 3: contributor avatars on the LEFT, "open file" pill
          // on the RIGHT (matching the reference).
          Row(
            children: [
              _Contributors(avatars: avatars, extra: extraCount),
              const Spacer(),
              _OpenFileButton(
                label: buttonLabel ?? l.t('mf_open_file'),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageAsset});
  final String imageAsset;

  // Slightly larger than the metric icons so the thumbnail feels like
  // the visual anchor of the card (matches the reference screenshot).
  static const double size = 80;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: KashfPalette.active.textSecondary,
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Contributors extends StatelessWidget {
  const _Contributors({required this.avatars, required this.extra});
  final List<String> avatars;
  final int extra;

  // Each tile is a small rounded rectangle. The face image is clipped
  // to a circle that's inset inside the rectangle (matches the
  // reference: rectangular tile with a circular face inside).
  static const double _tileSize = 32;
  static const double _tileRadius = 8;
  static const double _circleInset = 3;
  static const double _gap = 0.3;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (final asset in avatars) {
      children.add(
        Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            color: KashfPalette.active.fieldFill,
            borderRadius: BorderRadius.circular(_tileRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: _tileSize - (_circleInset * 2),
                height: _tileSize - (_circleInset * 2),
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person,
                    color: KashfPalette.active.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(width: _gap));
    }
    if (children.isNotEmpty) {
      // Remove the trailing gap we just added.
      children.removeLast();
    }

    if (extra > 0) {
      children.add(const SizedBox(width: 6));
      children.add(Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          '+$extra',
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _OpenFileButton extends StatelessWidget {
  const _OpenFileButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                label,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              color: KashfPalette.active.textPrimary,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

