import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../investigation/investigation_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

/// "نظرة عامة على النظام" / "System Overview" — a strict, pixel-perfect
/// recreation of the provided reference screenshot, with the same
/// bottom navigation bar as the home screen so the user can move
/// between sections directly from here.
///
/// Layout (top → bottom), mirroring the reference screenshot:
///   1. Top bar: KASHF Lite logo (start) + bell-with-badge + avatar
///      with name/role (end) — same pattern as HomeScreen
///   2. Greeting line: "نظرة عامة على النظام" (start aligned)
///   3. KPI strip: 4 cards (مسح النزاهة 92% | مقياس البيانات 78 |
///      التصنيفات النشطة 24 | إجمالي الملفات 142)
///   4. "أدوات الملفات" section: 5 tool buttons
///   5. "استوديو المحتوى": 2 studio cards
///   6. "آخر التحقيقات": 4-row table
///   7. "إجراءات سريعة": 4 action buttons
///   8. Bottom nav bar (mirrors HomeShell) — Settings | Reports | (+)
///      | Explore | Home, with the standard gold "+" FAB.
class SystemOverviewScreen extends StatefulWidget {
  const SystemOverviewScreen({super.key});

  @override
  State<SystemOverviewScreen> createState() => _SystemOverviewScreenState();
}

class _SystemOverviewScreenState extends State<SystemOverviewScreen> {
  // The bottom nav stack mirrors HomeShell so the user can navigate
  // between the same four sections without losing context.
  int _index = 0;

  late final List<Widget> _pages = const [
    // Index 0 — current screen (the system overview content).
    _SystemOverviewContent(),
    HomeScreen(),
    ExploreScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Bottom pill containing the four nav destinations.
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: KashfPalette.active.surface,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: KashfPalette.active.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _Dest(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: l.t('nav_settings_lbl'),
                        selected: _index == 4,
                        onTap: () => setState(() => _index = 4),
                      ),
                      _Dest(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart,
                        label: l.t('nav_reports_lbl'),
                        selected: _index == 3,
                        onTap: () => setState(() => _index = 3),
                      ),
                      // Spacer for the centered FAB.
                      const SizedBox(width: 72),
                      _Dest(
                        icon: Icons.explore_outlined,
                        selectedIcon: Icons.explore,
                        label: l.t('nav_explore_lbl'),
                        selected: _index == 2,
                        onTap: () => setState(() => _index = 2),
                      ),
                      _Dest(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: l.t('nav_home_lbl'),
                        selected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                    ],
                  ),
                ),
                // Centered gold "+" FAB — opens the new investigation
                // workspace, matching the HomeShell behavior.
                Positioned(
                  top: -14,
                  child: GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).push(kashfRoute(const InvestigationScreen())),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: KashfColors.gold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: KashfColors.gold.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The actual content of the system overview, extracted so it can
/// live inside the IndexedStack as the "current" tab.
class _SystemOverviewContent extends StatelessWidget {
  const _SystemOverviewContent();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
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
          // 1. استوديو المحتوى (سكربت بودكاست + سكربت ريلز)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: _StudioSection(l: l)),
          ),
          // 2. آخر التحقيقات
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: _InvestigationsSection(l: l)),
          ),
          // 3. نظرة عامة على التوقعات + نشاط المصادر
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: _AnalyticsActivityRow(l: l)),
          ),
          // 4. إجراءات سريعة
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(child: _QuickActionsSection(l: l)),
          ),
        ],
      ),
    );
  }
}

/// One of the four nav destinations inside the bottom pill, mirroring
/// the HomeShell design. The selected one shows the brand-gold icon +
/// label; the others show a softer icon and dimmed text.
class _Dest extends StatelessWidget {
  const _Dest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? KashfColors.gold
        : KashfPalette.active.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: accent, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
// Mirrors the home screen's top bar: avatar + bell on the START side,
// KASHF Lite logo image on the END side. Children are listed in
// natural LTR visual order so Directionality mirrors them for RTL:
//   LTR: [avatar] [bell] ... [logo]
//   RTL: [logo] ... [bell] [avatar]
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final logoMark = Image.asset(
      'assets/images/logo_appbar.png',
      height: 30,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, _, _) => KashfLogo(width: 90),
    );

    final bell = _NotificationBell();

    return Row(
      children: [
        logoMark,
        const Spacer(),
        bell,
        const SizedBox(width: 8),
        _AvatarChip(l: l),
      ],
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
              child: const Text(
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
      alignment: AlignmentDirectional.centerEnd,
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
        alignment: AlignmentDirectional.centerEnd,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(width: 110, child: _KpiTile(data: tiles[i])),
          ],
        ],
      ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: icon first, then label (text on the right in LTR).
          SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Big value centered.
          SizedBox(
            height: 24,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
            ),
          ),
          const SizedBox(height: 4),
          // Sub text with colored dot, centered.
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: data.subColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    data.sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: data.subColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton(
              onPressed: () => _showToast(context, cta),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lastTitle,
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
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lastSub,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.description_outlined,
                size: 14,
                color: KashfPalette.active.textSecondary,
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
              l.t('so_show_all'),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              l.t('so_investigations_title'),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
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
        imagePath: 'assets/images/lattafa.jpeg',
      ),
      _InvestigationRowData(
        title: l.t('so_inv2_title'),
        subject: l.t('so_inv2_subject'),
        status: l.t('so_inv2_status'),
        statusColor: const Color(0xFF3B82F6),
        score: 0.89,
        imagePath: 'assets/images/parfum.jpeg',
      ),
      _InvestigationRowData(
        title: l.t('so_inv3_title'),
        subject: l.t('so_inv3_subject'),
        status: l.t('so_inv3_status'),
        statusColor: const Color(0xFFF59E0B),
        score: 0.65,
        imagePath: 'assets/images/borge.jpeg',
      ),
      _InvestigationRowData(
        title: l.t('so_inv4_title'),
        subject: l.t('so_inv4_subject'),
        status: l.t('so_inv4_status'),
        statusColor: const Color(0xFF8B5CF6),
        score: 0.78,
        imagePath: 'assets/images/winner.jpeg',
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
                      fontSize: 10,
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
                      fontSize: 10,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _InvestigationRow(data: rows[i], showDivider: i != rows.length - 1),
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
    required this.imagePath,
  });
  final String title;
  final String subject;
  final String status;
  final Color statusColor;
  final double score;
  final String imagePath;
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
            ? Border(bottom: BorderSide(color: KashfPalette.active.cardBorder))
            : null,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    fontSize: 12,
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
                    fontSize: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: data.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: data.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // Score percentage + thumbnail image.
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${(data.score * 100).round()}%',
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    color: const Color(0xFF2D2418),
                    child: Image.asset(
                      data.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        alignment: Alignment.center,
                        color: const Color(0xFF2D2418),
                        child: const Icon(
                          Icons.image_outlined,
                          color: KashfColors.gold,
                          size: 16,
                        ),
                      ),
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

// ============================ Analytics + Activity Row ============================
// Two large cards placed side-by-side, mirroring the reference screenshot:
//   - Left:  "نظرة عامة على التوقعات" → big donut chart + legend
//   - Right: "نشاط المصادر"              → big number + bar chart for 7 days
class _AnalyticsActivityRow extends StatelessWidget {
  const _AnalyticsActivityRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _AnalyticsCard(l: l)),
          const SizedBox(width: 8),
          Expanded(child: _ActivityCard(l: l)),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: title + period chip.
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t('so_analytics_title'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 6, 3),
                decoration: BoxDecoration(
                  color: KashfPalette.active.cardBorder,
                  borderRadius: BorderRadius.circular(6),
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
                      l.t('so_analytics_subtitle'),
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
          const SizedBox(height: 10),
          // Donut chart on the left + legend on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut chart + center label.
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: _DonutPainter(
                          slices: const [
                            _DonutSlice(0.70, Color(0xFF22C55E)),
                            _DonutSlice(0.20, Color(0xFFF59E0B)),
                            _DonutSlice(0.10, Color(0xFFEF4444)),
                          ],
                          strokeWidth: 14,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '92%',
                          style: TextStyle(
                            color: KashfPalette.active.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.t('so_analytics_period'),
                          style: TextStyle(
                            color: KashfPalette.active.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Legend stacked vertically on the right side of the donut.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(
                      color: const Color(0xFF22C55E),
                      label: l.t('so_analytics_high'),
                      value: '70%',
                    ),
                    const SizedBox(height: 6),
                    _LegendDot(
                      color: const Color(0xFFF59E0B),
                      label: l.t('so_analytics_med'),
                      value: '20%',
                    ),
                    const SizedBox(height: 6),
                    _LegendDot(
                      color: const Color(0xFFEF4444),
                      label: l.t('so_analytics_low'),
                      value: '10%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSlice {
  const _DonutSlice(this.value, this.color);
  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.strokeWidth});

  final List<_DonutSlice> slices;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    var start = -3.14159 / 2; // top
    final bg = Paint()
      ..color = KashfPalette.active.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track ring underneath.
    canvas.drawCircle(center, radius, bg);

    for (final slice in slices) {
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweep = slice.value * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.strokeWidth != strokeWidth;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Bar heights for the last 7 days (0..1, normalized).
    const heights = <double>[0.45, 0.30, 0.55, 0.85, 0.40, 0.65, 0.95];
    const days = <String>['ج', 'خ', 'أ', 'ر', 'ث', 'ل', 'ح'];

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header.
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t('so_activity_title'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 6, 3),
                decoration: BoxDecoration(
                  color: KashfPalette.active.cardBorder,
                  borderRadius: BorderRadius.circular(6),
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
                      l.t('so_activity_subtitle'),
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
          const SizedBox(height: 8),
          // Big number.
          Text(
            l.t('so_activity_value'),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.t('so_activity_sub'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // Bar chart.
          SizedBox(
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < heights.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 6,
                              height: 62 * heights[i],
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          days[i],
                          style: TextStyle(
                            color: KashfPalette.active.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != heights.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
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
            Icon(item.icon, size: 18, color: KashfPalette.active.textPrimary),
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
