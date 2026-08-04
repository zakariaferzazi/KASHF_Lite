import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// "نظرة عامة على النظام" / "System Overview" — a strict, pixel-perfect
/// recreation of the provided reference screenshot.
///
/// Layout (top → bottom), mirroring the reference screenshot:
///   1. Top bar: KASHF Lite pill (start) + bell-with-badge + avatar with
///      "مراجعة نور" / "أمن النظام" (end) — same pattern as HomeScreen
///   2. Greeting line: "نظرة عامة على النظام" (start aligned)
///   3. KPI strip: 4 cards (مسح النزاهة 92% | مقياس البيانات 78 |
///      التصنيفات النشطة 24 | إجمالي الملفات 142)
///   4. "أدوات الملفات" section: 5 tool buttons (إعدادات النظام | إزالة
///      المصادر | مقارنة | تقارير دورية | إنشاء تصنيف)
///   5. "استوديو المحتوى": 2 large studio cards (Script Podcast |
///      Script Reel) with CTAs and last-script rows
///   6. "آخر التحقيقات": 4-row table (title/subject, status pill,
///      circular-score) + "عرض الكل" link
///   7. "إجراءات سريعة": 4 action buttons (مشاركة لوحة الحكم | تصدير
///      البيانات | تنبيهات | حذف جميع البيانات)
///
/// Children are listed in natural LTR visual order so Directionality
/// mirrors them for RTL: the first item in the row ends up on the RIGHT
/// in RTL, the last item ends up on the LEFT — exactly like the
/// reference screenshot.
class SystemOverviewScreen extends StatelessWidget {
  const SystemOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // Top bar
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(child: _TopBar(l: l)),
              ),
              // Page title
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(child: _PageTitle(l: l)),
              ),
              // KPI strip
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(child: _KpiStrip(l: l)),
              ),
              // أدوات الملفات
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(child: _ToolsSection(l: l)),
              ),
              // استوديو المحتوى
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(child: _StudioSection(l: l)),
              ),
              // آخر التحقيقات
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(child: _InvestigationsSection(l: l)),
              ),
              // إجراءات سريعة
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(child: _QuickActionsSection(l: l)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
// Children in natural LTR order — Directionality mirrors for RTL:
//   LTR: [kashf pill] ... [bell] [avatar]
//   RTL: [avatar] [bell] ... [kashf pill]
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final logoMark = _KashfLitePill(l: l);
    final bell = _NotificationBell();
    final avatar = _AvatarChip(l: l);

    return Row(
      children: [
        logoMark,
        const Spacer(),
        bell,
        const SizedBox(width: 8),
        avatar,
      ],
    );
  }
}

class _KashfLitePill extends StatelessWidget {
  const _KashfLitePill({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // K logo glyph — matches the home screen logo mark.
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KashfColors.gold,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'K',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.t('app_title_root'),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              l.t('app_title_lite_badge'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(
                  color: KashfPalette.active.background,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                '3',
                style: TextStyle(
                  color: Colors.white,
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

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KashfColors.gold.withValues(alpha: 0.20),
              border: Border.all(color: KashfColors.gold, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/logoprofile.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person, color: KashfColors.gold, size: 14),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('so_user_name'),
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                l.t('so_user_role'),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================ Page Title ============================
class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        l.t('so_page_title'),
        style: TextStyle(
          color: KashfPalette.active.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ============================ Section Header ============================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ============================ KPI Strip ============================
// Children in natural LTR order — Directionality mirrors them so the
// first item in this list ends up on the RIGHT in RTL (== START).
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final tiles = <_KpiTileData>[
      _KpiTileData(
        icon: Icons.shield_moon_outlined,
        accent: const Color(0xFF8B5CF6),
        value: l.t('so_kpi1_value'),
        label: l.t('so_kpi1_label'),
        sub: l.t('so_kpi1_sub'),
        subColor: const Color(0xFF22C55E),
      ),
      _KpiTileData(
        icon: Icons.dataset_outlined,
        accent: const Color(0xFF22C55E),
        value: l.t('so_kpi2_value'),
        label: l.t('so_kpi2_label'),
        sub: l.t('so_kpi2_sub'),
        subColor: const Color(0xFF22C55E),
      ),
      _KpiTileData(
        icon: Icons.bolt_outlined,
        accent: const Color(0xFFF59E0B),
        value: l.t('so_kpi3_value'),
        label: l.t('so_kpi3_label'),
        sub: l.t('so_kpi3_sub'),
        subColor: const Color(0xFFF59E0B),
      ),
      _KpiTileData(
        icon: Icons.layers_outlined,
        accent: const Color(0xFFEF4444),
        value: l.t('so_kpi4_value'),
        label: l.t('so_kpi4_label'),
        sub: l.t('so_kpi4_sub'),
        subColor: const Color(0xFF22C55E),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _KpiTile(data: tiles[i])),
        ],
      ],
    );
  }
}

class _KpiTileData {
  const _KpiTileData({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    required this.sub,
    required this.subColor,
  });
  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final String sub;
  final Color subColor;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});
  final _KpiTileData data;

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
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 14, color: data.accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              data.value,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 22,
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
              color: data.subColor,
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

// ============================ Tools Section ============================
class _ToolsSection extends StatelessWidget {
  const _ToolsSection({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l.t('so_tools_title')),
        _ToolsRow(l: l),
      ],
    );
  }
}

// Children in natural LTR order — Directionality mirrors them so the
// first item in this list ends up on the RIGHT in RTL.
class _ToolsRow extends StatelessWidget {
  const _ToolsRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final tools = <_ToolItem>[
      _ToolItem(
        icon: Icons.settings_outlined,
        color: const Color(0xFF3B82F6),
        label: l.t('so_tool1'),
        onTap: () => _showToast(context, l.t('so_tool1')),
      ),
      _ToolItem(
        icon: Icons.delete_outline,
        color: const Color(0xFFEF4444),
        label: l.t('so_tool2'),
        onTap: () => _showToast(context, l.t('so_tool2')),
      ),
      _ToolItem(
        icon: Icons.balance,
        color: const Color(0xFFF59E0B),
        label: l.t('so_tool3'),
        onTap: () => _showToast(context, l.t('so_tool3')),
      ),
      _ToolItem(
        icon: Icons.description_outlined,
        color: const Color(0xFF22C55E),
        label: l.t('so_tool4'),
        onTap: () => _showToast(context, l.t('so_tool4')),
      ),
      _ToolItem(
        icon: Icons.add_circle_outline,
        color: const Color(0xFF8B5CF6),
        label: l.t('so_tool5'),
        onTap: () => _showToast(context, l.t('so_tool5')),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 32,
                color: KashfPalette.active.cardBorder,
              ),
            Expanded(child: _ToolButton(item: tools[i])),
          ],
        ],
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.item});
  final _ToolItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 18, color: item.color),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.2,
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

// ============================ Studio Section ============================
class _StudioSection extends StatelessWidget {
  const _StudioSection({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l.t('so_studio_title')),
        Row(
          children: [
            Expanded(
              child: _StudioCard(
                color: const Color(0xFF8B5CF6),
                title: l.t('so_studio1_title'),
                description: l.t('so_studio1_desc'),
                cta: l.t('so_studio1_cta'),
                lastTitle: l.t('so_studio1_last_title'),
                lastSub: l.t('so_studio1_last_sub'),
                icon: Icons.mic_none_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StudioCard(
                color: const Color(0xFFEF4444),
                title: l.t('so_studio2_title'),
                description: l.t('so_studio2_desc'),
                cta: l.t('so_studio2_cta'),
                lastTitle: l.t('so_studio2_last_title'),
                lastSub: l.t('so_studio2_last_sub'),
                icon: Icons.movie_creation_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.color,
    required this.title,
    required this.description,
    required this.cta,
    required this.lastTitle,
    required this.lastSub,
    required this.icon,
  });
  final Color color;
  final String title;
  final String description;
  final String cta;
  final String lastTitle;
  final String lastSub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              onPressed: () => _showToast(context, cta),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lastTitle,
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
            children: [
              Icon(Icons.description_outlined,
                  size: 11, color: KashfPalette.active.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lastSub,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 9,
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
    );
  }
}

// ============================ Investigations Section ============================
class _InvestigationsSection extends StatelessWidget {
  const _InvestigationsSection({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.t('so_investigations_title'),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              l.t('so_show_all'),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InvestigationsTable(l: l),
      ],
    );
  }
}

class _InvestigationsTable extends StatelessWidget {
  const _InvestigationsTable({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final rows = <_InvestigationRowData>[
      _InvestigationRowData(
        title: l.t('so_inv1_title'),
        subject: l.t('so_inv1_subject'),
        status: l.t('so_inv1_status'),
        statusColor: const Color(0xFF22C55E),
        score: 0.92,
      ),
      _InvestigationRowData(
        title: l.t('so_inv2_title'),
        subject: l.t('so_inv2_subject'),
        status: l.t('so_inv2_status'),
        statusColor: const Color(0xFF3B82F6),
        score: 0.89,
      ),
      _InvestigationRowData(
        title: l.t('so_inv3_title'),
        subject: l.t('so_inv3_subject'),
        status: l.t('so_inv3_status'),
        statusColor: const Color(0xFFF59E0B),
        score: 0.65,
      ),
      _InvestigationRowData(
        title: l.t('so_inv4_title'),
        subject: l.t('so_inv4_subject'),
        status: l.t('so_inv4_status'),
        statusColor: const Color(0xFF8B5CF6),
        score: 0.78,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          // Header row.
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: KashfPalette.active.cardBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    l.t('so_inv_col_title'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l.t('so_inv_col_status'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l.t('so_inv_col_score'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _InvestigationRow(
              data: rows[i],
              showDivider: i != rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _InvestigationRowData {
  const _InvestigationRowData({
    required this.title,
    required this.subject,
    required this.status,
    required this.statusColor,
    required this.score,
  });
  final String title;
  final String subject;
  final String status;
  final Color statusColor;
  final double score;
}

class _InvestigationRow extends StatelessWidget {
  const _InvestigationRow({required this.data, required this.showDivider});
  final _InvestigationRowData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: KashfPalette.active.cardBorder),
              )
            : null,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      child: Row(
        children: [
          // Title + subject column.
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.subject,
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
          ),
          // Status pill.
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: data.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: data.statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // Score progress.
          Expanded(
            flex: 2,
            child: _ScoreBar(pct: data.score),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 4,
                backgroundColor: KashfPalette.active.cardBorder,
                valueColor: const AlwaysStoppedAnimation(KashfColors.gold),
              ),
            ),
            Text(
              '${(pct * 100).round()}%',
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ Quick Actions Section ============================
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l.t('so_quick_actions_title')),
        _QuickActionsRow(l: l),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.share_outlined,
        label: l.t('so_action1'),
        onTap: () => _showToast(context, l.t('so_action1')),
      ),
      _QuickActionItem(
        icon: Icons.download_outlined,
        label: l.t('so_action2'),
        onTap: () => _showToast(context, l.t('so_action2')),
      ),
      _QuickActionItem(
        icon: Icons.notifications_active_outlined,
        label: l.t('so_action3'),
        onTap: () => _showToast(context, l.t('so_action3')),
      ),
      _QuickActionItem(
        icon: Icons.delete_outline,
        label: l.t('so_action4'),
        onTap: () => _showToast(context, l.t('so_action4')),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 32,
                color: KashfPalette.active.cardBorder,
              ),
            Expanded(child: _QuickActionButton(item: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.item});
  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon,
                size: 18, color: KashfPalette.active.textPrimary),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.2,
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

// ============================ Toast ============================
void _showToast(BuildContext context, String label) {
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${l.t('settings_coming_soon')}: $label'),
      backgroundColor: KashfColors.gold,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 900),
    ),
  );
}
