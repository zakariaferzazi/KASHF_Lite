import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// "تحقيق جديد" / "New Investigation" — a strict, pixel-perfect
/// recreation of the provided reference screenshot.
///
/// The reference is an Arabic-language RTL screen. Visual order
/// (left → right as drawn):
///
///   ┌─ top bar ────────────────────────────────────┐
///   │ [X] ····················· [🧠  تحقيق جديد]  │
///   └──────────────────────────────────────────────┘
///   ┌─ Smart search card (purple border) ─────────┐
///   │  🧠  البحث الذكي                              │
///   │  ابحث عن أي شيء يثير اهتمامك…              │
///   │  ┌──────────── search field ────────────┐    │
///   │  │ 🔍 ابحث عن شركة أو منتج…           │    │
///   │  └──────────────────────────────────────┘    │
///   │  أسئلة سريعة                                  │
///   │  ┌──────────┐  ┌──────────┐                  │
///   │  │ ✦ Nike   │  │ ✦ Dior   │                  │
///   │  └──────────┘  └──────────┘                  │
///   │  ┌──────────┐  ┌──────────┐                  │
///   │  │ ✦ منتج X │  │ ✦ مؤثرين │                  │
///   │  └──────────┘  └──────────┘                  │
///   │  ┌────────────  ابدأ التحقيق  ────────────┐  │
///   │  └────────────────────────────────────────┘  │
///   └──────────────────────────────────────────────┘
///   ┌─ Or upload evidence card ───────────────────┐
///   │  📎 أو ابدأ برفع الأدلة                     │
///   │  أضف ملفات بأنواعها ومصادرها…               │
///   │  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐              │
///   │  │مل│ │إع│ │PD│ │في│ │صو│ │را│              │
///   │  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘              │
///   │  ┌──── اسحب الملفات هنا أو انقر ─────────┐  │
///   │  └────────────────────────────────────────┘  │
///   └──────────────────────────────────────────────┘
///   ┌─ Quick actions card ────────────────────────┐
///   │  ⚡ الإجراءات السريعة                         │
///   │  اختر إجراءً سريعًا للبدء…                  │
///   │  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐              │
///   │  │مق│ │مر│ │تن│ │تح│ │حl│ │تح│              │
///   │  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘              │
///   └──────────────────────────────────────────────┘
class InvestigationScreen extends StatefulWidget {
  const InvestigationScreen({super.key});

  @override
  State<InvestigationScreen> createState() => _InvestigationScreenState();
}

class _InvestigationScreenState extends State<InvestigationScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Visual order in the reference has the close (X) on the LEFT
    // and the title + brain icon on the RIGHT. Render the screen in
    // LTR so the layout matches exactly while keeping the Arabic
    // strings flowing right-to-left inside their own widgets.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            children: [
              _TopBar(l: l),
              const SizedBox(height: 8),
              _SmartSearchCard(l: l),
              const SizedBox(height: 8),
              _UploadEvidenceCard(l: l),
              const SizedBox(height: 8),
              _QuickActionsCard(l: l),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar — [X] (close) on the LEFT · [title + brain icon] on the RIGHT.
// ============================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Close button on the LEFT edge.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: KashfPalette.active.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close,
                  color: KashfPalette.active.textPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
          // Title + brain icon group centered on the RIGHT.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l.t('inv_title'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KashfColors.gold, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.gps_fixed,
                    color: KashfColors.gold,
                    size: 16,
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

// ============================================================================
// Section card wrapper — provides the rounded border surface every
// section shares in the reference.
// ============================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? KashfPalette.active.cardBorder,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ============================================================================
// Section header — icon visually on the RIGHT (start in RTL), title +
// subtitle flow right-to-left.
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // In RTL the row reads visually as [icon ...... title].
          // We render LTR but put the icon on the trailing edge so
          // the icon sits on the right side of the title, matching
          // the reference screenshot.
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                subtitle,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Smart search section — card with the search field, the 2x2 quick
// question grid and the gold CTA button.
// ============================================================================
class _SmartSearchCard extends StatelessWidget {
  const _SmartSearchCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.smart_toy_sharp,
            iconColor: KashfColors.gold,
            title: l.t('inv_section_smart'),
            subtitle: l.t('inv_section_smart_sub'),
          ),
          _SearchField(hint: l.t('inv_search_hint')),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l.t('inv_quick_label'),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _QuickQuestionGrid(
            questions: [
              l.t('inv_q1'),
              l.t('inv_q2'),
              l.t('inv_q3'),
              l.t('inv_q4'),
            ],
          ),
          const SizedBox(height: 8),
          _StartInvestigationButton(
            label: l.t('inv_cta_start'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.t('inv_cta_start')),
                  backgroundColor: KashfColors.gold,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Search field with the magnifying-glass icon on the LEFT (the visual
// "end" in the RTL layout — we render LTR and put the icon on the
// trailing edge so it ends up on the LEFT in the reference).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KashfPalette.active.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.search,
              color: KashfColors.gold,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: TextEditingController(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
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

// 2x2 grid of suggested question chips. Each chip displays the
// question text on the right and the sparkle icon on the left edge.
class _QuickQuestionGrid extends StatelessWidget {
  const _QuickQuestionGrid({required this.questions});
  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _QuestionChip(text: questions[0])),
            const SizedBox(width: 6),
            Expanded(child: _QuestionChip(text: questions[1])),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _QuestionChip(text: questions[2])),
            const SizedBox(width: 6),
            Expanded(child: _QuestionChip(text: questions[3])),
          ],
        ),
      ],
    );
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 10, 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: KashfColors.gold, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
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

// Gold gradient CTA button matching the reference ("ابدأ التحقيق").
class _StartInvestigationButton extends StatelessWidget {
  const _StartInvestigationButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFF8C24A), Color(0xFFF5B92E)],
          ),
          boxShadow: [
            BoxShadow(
              color: KashfColors.gold.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// "Or upload evidence" card — header + 6 evidence-type tiles + dropzone.
// ============================================================================
class _UploadEvidenceCard extends StatelessWidget {
  const _UploadEvidenceCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8B5CF6);
    final tiles = <_EvidenceTileData>[
      _EvidenceTileData(
        icon: Icons.insert_drive_file_outlined,
        label: l.t('inv_type_file'),
        sub: l.t('inv_type_file_sub'),
      ),
      _EvidenceTileData(
        icon: Icons.campaign_outlined,
        label: l.t('inv_type_ad'),
        sub: l.t('inv_type_ad_sub'),
      ),
      _EvidenceTileData(
        icon: Icons.picture_as_pdf_outlined,
        label: l.t('inv_type_pdf'),
        sub: l.t('inv_type_pdf_sub'),
      ),
      _EvidenceTileData(
        icon: Icons.movie_outlined,
        label: l.t('inv_type_video'),
        sub: l.t('inv_type_video_sub'),
      ),
      _EvidenceTileData(
        icon: Icons.image_outlined,
        label: l.t('inv_type_image'),
        sub: l.t('inv_type_image_sub'),
      ),
      _EvidenceTileData(
        icon: Icons.link,
        label: l.t('inv_type_link'),
        sub: l.t('inv_type_link_sub'),
      ),
    ];
    return _SectionCard(
      borderColor: purple.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.attach_file_outlined,
            iconColor: purple,
            title: l.t('inv_section_upload'),
            subtitle: l.t('inv_section_upload_sub'),
          ),
          _EvidenceTypeGrid(tiles: tiles),
          const SizedBox(height: 8),
          _DropZone(hint: l.t('inv_drop_hint')),
        ],
      ),
    );
  }
}

class _EvidenceTileData {
  const _EvidenceTileData({
    required this.icon,
    required this.label,
    required this.sub,
  });
  final IconData icon;
  final String label;
  final String sub;
}

// 6-tile grid of evidence types (3 columns × 2 rows).
class _EvidenceTypeGrid extends StatelessWidget {
  const _EvidenceTypeGrid({required this.tiles});
  final List<_EvidenceTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _EvidenceTile(data: tiles[i])),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 3; i < 6; i++) ...[
              if (i > 3) const SizedBox(width: 6),
              Expanded(child: _EvidenceTile(data: tiles[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.data});
  final _EvidenceTileData data;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8B5CF6);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: purple, size: 20),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: DottedBorderContainer(
        radius: 12,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_outlined, color: KashfColors.gold, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

// Dashed border wrapper used for the upload dropzone so the boundary
// reads as a true dotted line (Flutter's [DashedDecoration] pattern).
class DottedBorderContainer extends StatelessWidget {
  const DottedBorderContainer({
    super.key,
    required this.child,
    this.radius = 12,
  });
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: KashfPalette.active.cardBorder,
        radius: radius,
        strokeWidth: 1,
        dashWidth: 4,
        dashGap: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final next = (dist + dashWidth).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(dist, next), paint);
        dist = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}

// ============================================================================
// Quick actions card — 6 gold-tinted action tiles.
// ============================================================================
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF4C542);
    final tiles = <_ActionTileData>[
      _ActionTileData(
        icon: Icons.compare_arrows,
        label: l.t('inv_action_compare'),
        sub: l.t('inv_action_compare_sub'),
      ),
      _ActionTileData(
        icon: Icons.remove_red_eye_outlined,
        label: l.t('inv_action_monitor'),
        sub: l.t('inv_action_monitor_sub'),
      ),
      _ActionTileData(
        icon: Icons.hearing_outlined,
        label: l.t('inv_action_listen'),
        sub: l.t('inv_action_listen_sub'),
      ),
      _ActionTileData(
        icon: Icons.verified_user_outlined,
        label: l.t('inv_action_match'),
        sub: l.t('inv_action_match_sub'),
      ),
      _ActionTileData(
        icon: Icons.trending_up,
        label: l.t('inv_action_campaign'),
        sub: l.t('inv_action_campaign_sub'),
      ),
      _ActionTileData(
        icon: Icons.person_outline,
        label: l.t('inv_action_influencer'),
        sub: l.t('inv_action_influencer_sub'),
      ),
    ];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.bolt_outlined,
            iconColor: gold,
            title: l.t('inv_section_actions'),
            subtitle: l.t('inv_section_actions_sub'),
          ),
          _ActionGrid(tiles: tiles),
        ],
      ),
    );
  }
}

class _ActionTileData {
  const _ActionTileData({
    required this.icon,
    required this.label,
    required this.sub,
  });
  final IconData icon;
  final String label;
  final String sub;
}

// 6-tile grid of quick actions (3 columns × 2 rows).
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.tiles});
  final List<_ActionTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _ActionTile(data: tiles[i])),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 3; i < 6; i++) ...[
              if (i > 3) const SizedBox(width: 6),
              Expanded(child: _ActionTile(data: tiles[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.data});
  final _ActionTileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: KashfColors.gold, size: 20),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
      ),
    );
  }
}
