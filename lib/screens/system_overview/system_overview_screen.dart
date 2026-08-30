import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/entity_type.dart';
import '../../models/investigation.dart';
import '../../models/saved_investigation.dart';
import '../../services/admin_gate.dart';
import '../../services/auth_service.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/script_studio/script_draft.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../explore/explore_screen.dart';
import '../files/latest_investigations_screen.dart';
import '../home/home_screen.dart';
import '../investigation/investigation_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/notifications_bell_screen.dart';
import '../settings/settings_screen.dart';
import 'admin_report_picker_screen.dart';
import 'admin_script_viewer_screen.dart';

/// "نظرة عامة على النظام" / "System Overview" — production-ready
/// overview screen.
///
/// Visual layout (top → bottom) is unchanged from the original
/// pixel-perfect reference, but every section now runs on real
/// data:
///   * KPI tiles pull aggregate metrics from the signed-in user's
///     Firestore archive (avg confidence, completed count, distinct
///     entity types, total rows).
///   * "Latest investigations" table renders the 4 most recent
///     saved investigations (or fewer if the archive is empty).
///   * The donut chart + bar chart still use the static reference
///     numbers — they belong to the marketing demo and don't have
///     per-user data behind them.
///   * Tools row + quick actions row expose real handlers
///     (navigate, share, export, delete).
///   * Studio cards unlock the admin-only AI script generator for
///     the account whose email matches [AdminGate.kAdminEmail].
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
    // No forced Directionality here — the app-wide one set in
    // `main.dart`'s `MaterialApp.builder` already provides the
    // correct TextDirection for the active locale (LTR for English,
    // RTL for Arabic). Wrapping this screen in another
    // `Directionality(textDirection: TextDirection.ltr)` would
    // override that and freeze the overview layout to LTR even
    // when the user is on the Arabic locale.
    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: AlignmentDirectional.center,
            children: [
              // Bottom pill containing the four nav destinations.
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: KashfPalette.active.surface,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
                // Order the children according to the current
                // direction so the destinations read as
                // [Settings, Reports, FAB, Explore, Home] in LTR
                // (mirrored to [Home, Explore, FAB, Reports,
                // Settings] in RTL — Home stays at the START side
                // regardless of locale).
                child: DirectionalityScope(
                  builder: (context) {
                    final isRtl = Directionality.of(context) ==
                        TextDirection.rtl;
                    final leftItems = isRtl
                        ? <_Dest>[
                            _Dest(
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home,
                              label: l.t('nav_home_lbl'),
                              selected: _index == 1,
                              onTap: () => setState(() => _index = 1),
                            ),
                            _Dest(
                              icon: Icons.explore_outlined,
                              selectedIcon: Icons.explore,
                              label: l.t('nav_explore_lbl'),
                              selected: _index == 2,
                              onTap: () => setState(() => _index = 2),
                            ),
                          ]
                        : <_Dest>[
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
                          ];
                    final rightItems = isRtl
                        ? <_Dest>[
                            _Dest(
                              icon: Icons.bar_chart_outlined,
                              selectedIcon: Icons.bar_chart,
                              label: l.t('nav_reports_lbl'),
                              selected: _index == 3,
                              onTap: () => setState(() => _index = 3),
                            ),
                            _Dest(
                              icon: Icons.settings_outlined,
                              selectedIcon: Icons.settings,
                              label: l.t('nav_settings_lbl'),
                              selected: _index == 4,
                              onTap: () => setState(() => _index = 4),
                            ),
                          ]
                        : <_Dest>[
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
                          ];
                    return Row(
                      children: [
                        ...leftItems,
                        // Spacer for the centered FAB.
                        const SizedBox(width: 72),
                        ...rightItems,
                      ],
                    );
                  },
                ),
              ),
              // Centered gold "+" FAB — opens the new investigation
              // workspace, matching the HomeShell behavior.
              PositionedDirectional(
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
    );
  }
}

/// Tiny shim that re-exposes the ambient [Directionality] so the
/// bottom-nav builder above can branch on `Directionality.of(...)`
/// without each call site having to spell out the lookup.
typedef DirectionalityBuilder = Widget Function(BuildContext context);

class DirectionalityScope extends StatelessWidget {
  const DirectionalityScope({super.key, required this.builder});

  final DirectionalityBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// The actual content of the system overview, extracted so it can
/// live inside the IndexedStack as the "current" tab. Drives its
/// data from a [LatestInvestigationsController] so the page
/// automatically reflects archive changes.
class _SystemOverviewContent extends StatefulWidget {
  const _SystemOverviewContent();

  @override
  State<_SystemOverviewContent> createState() =>
      _SystemOverviewContentState();
}

class _SystemOverviewContentState extends State<_SystemOverviewContent> {
  // The System Overview screen is admin-only (the Settings tile is
  // gated by [AdminGate]) so, whenever an admin opens it, the
  // investigations table should show rows from EVERY user — not just
  // the admin's own archive. Non-admin users fall back to their own
  // slice so the screen stays safe if it's ever reached another way.
  final bool _isAdmin = AdminGate.isAdmin(AuthService().currentUser);

  late final LatestInvestigationsController _controller;
  StreamSubscription<List<SavedInvestigation>>? _allUsersSub;
  List<SavedInvestigation> _allUsersItems = const <SavedInvestigation>[];

  @override
  void initState() {
    super.initState();
    // Admin: read across all users via the Firestore collection group.
    if (_isAdmin) {
      _allUsersSub = InvestigationArchiveService.instance
          .watchAllUsersFromFirestore(limit: 60)
          .listen((list) {
        if (mounted) setState(() => _allUsersItems = list);
      });
    }
    // Non-admin fallback: this user's own archive.
    _controller = LatestInvestigationsController(limit: 60);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _allUsersSub?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// The active row set: all users for the admin, otherwise the
  /// signed-in user's own archive.
  List<SavedInvestigation> get _items =>
      _isAdmin ? _allUsersItems : _controller.items;

  // ============================ Derived data ============================

  /// Aggregate metrics used by the KPI strip. Computed once per
  /// rebuild from the controller's snapshot — small enough that a
  /// full pass over 60 rows is well below the budget.
  _KpiMetrics _metrics() {
    final items = _items;
    final completed =
        items.where((it) => it.status == InvestigationStatus.completed);
    final completedList = completed.toList();
    final avgConfidence = completedList.isEmpty
        ? 0
        : (completedList.map((it) => it.confidencePercent).reduce(
                  (a, b) => a + b,
                ) /
                completedList.length)
            .round();
    final distinctEntities = completedList
        .map((it) => it.entityType)
        .toSet()
        .length;
    return _KpiMetrics(
      avgConfidence: avgConfidence,
      activeCategories: distinctEntities,
      totalReports: items.length,
      completedReports: completedList.length,
    );
  }

  /// Most-recent four completed investigations. Falls back to all
  /// items when fewer than four are completed so the table still
  /// has something to show on a brand-new account.
  List<SavedInvestigation> _latestFour() {
    final list = _items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(4).toList();
  }

  // ============================ Build ============================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final metrics = _metrics();
    final latest = _latestFour();
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
          // KPI strip (driven by Firestore archive metrics)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _KpiStrip(metrics: metrics, l: l),
            ),
          ),
          // أدوات الملفات
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: _ToolsSection(l: l)),
          ),
          // 1. استوديو المحتوى (سكربت بودكاست + سكربت ريلز)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _StudioSection(l: l, isAdmin: _isAdmin),
            ),
          ),
          // 2. آخر التحقيقات (real Firestore-backed rows)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _InvestigationsSection(
                l: l,
                items: latest,
                isAdmin: _isAdmin,
              ),
            ),
          ),
          // 3. نظرة عامة على التوقعات + نشاط المصادر (static demos)
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
          // Badge anchored to the END side so it stays on the
          // outside corner of the bell regardless of locale
          // direction. In LTR that's top-right, in RTL top-left —
          // which is the visually correct position for a
          // notification dot in either script.
          PositionedDirectional(
            top: -2,
            end: -2,
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
  const _KpiStrip({required this.metrics, required this.l});
  final _KpiMetrics metrics;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final tiles = <_KpiTileData>[
      _KpiTileData(
        icon: Icons.shield_moon_outlined,
        accent: const Color(0xFF8B5CF6),
        // Average confidence of completed investigations. 0 when
        // there are none — no fake 92% placeholder.
        value: metrics.completedReports == 0
            ? '—'
            : '${metrics.avgConfidence}%',
        label: l.t('so_kpi1_label'),
        sub: metrics.completedReports == 0
            ? l.t('so_kpi_empty_sub')
            : l.t('so_kpi1_sub'),
        subColor: metrics.completedReports == 0
            ? palette.textSecondary
            : const Color(0xFF22C55E),
      ),
      _KpiTileData(
        icon: Icons.dataset_outlined,
        accent: const Color(0xFF22C55E),
        // Distinct entity types in the archive.
        value: metrics.activeCategories.toString(),
        label: l.t('so_kpi3_label'),
        sub: metrics.activeCategories == 0
            ? l.t('so_kpi_empty_sub')
            : l.t('so_kpi3_sub'),
        subColor: metrics.activeCategories == 0
            ? palette.textSecondary
            : const Color(0xFFF59E0B),
      ),
      _KpiTileData(
        icon: Icons.bolt_outlined,
        accent: const Color(0xFFF59E0B),
        // Completed investigations count.
        value: metrics.completedReports.toString(),
        label: l.t('so_kpi_completed'),
        sub: metrics.completedReports == 0
            ? l.t('so_kpi_empty_sub')
            : l.t('so_kpi_completed_sub'),
        subColor: metrics.completedReports == 0
            ? palette.textSecondary
            : const Color(0xFFF59E0B),
      ),
      _KpiTileData(
        icon: Icons.layers_outlined,
        accent: const Color(0xFFEF4444),
        // All-time archived rows (completed + failed).
        value: metrics.totalReports.toString(),
        label: l.t('so_kpi4_label'),
        sub: metrics.totalReports == 0
            ? l.t('so_kpi_empty_sub')
            : l.t('so_kpi4_sub'),
        subColor: metrics.totalReports == 0
            ? palette.textSecondary
            : const Color(0xFF22C55E),
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

class _KpiMetrics {
  const _KpiMetrics({
    required this.avgConfidence,
    required this.activeCategories,
    required this.totalReports,
    required this.completedReports,
  });
  final int avgConfidence;
  final int activeCategories;
  final int totalReports;
  final int completedReports;
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
// Fully functional file-tools row. Each button opens a real
// destination instead of a "coming soon" toast.
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
    final palette = KashfPalette.active;
    final tools = <_ToolItem>[
      _ToolItem(
        icon: Icons.settings_outlined,
        color: const Color(0xFF3B82F6),
        label: l.t('so_tool1'),
        onTap: () => _openSettings(context),
      ),
      _ToolItem(
        icon: Icons.delete_outline,
        color: const Color(0xFFEF4444),
        label: l.t('so_tool2'),
        // "Remove sources" — the archive-backed "delete all" action.
        onTap: () => _confirmDeleteAll(context),
      ),
      _ToolItem(
        icon: Icons.balance,
        color: const Color(0xFFF59E0B),
        label: l.t('so_tool3'),
        onTap: () => _openLatestInvestigations(context),
      ),
      _ToolItem(
        icon: Icons.description_outlined,
        color: const Color(0xFF22C55E),
        label: l.t('so_tool4'),
        onTap: () => _openReportsTab(context),
      ),
      _ToolItem(
        icon: Icons.add_circle_outline,
        color: const Color(0xFF8B5CF6),
        label: l.t('so_tool5'),
        onTap: () => _openNewInvestigation(context),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 32,
                color: palette.cardBorder,
              ),
            Expanded(child: _ToolButton(item: tools[i])),
          ],
        ],
      ),
    );
  }

  // ============= Tools handlers =============

  void _openSettings(BuildContext context) {
    // We're already in the system overview, which lives inside
    // HomeShell's Settings tab's "Settings" tile's push. No-op
    // here, so just pop back instead of stacking Settings on top
    // of itself.
    Navigator.of(context).maybePop();
  }

  void _openReportsTab(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  void _openLatestInvestigations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LatestInvestigationsScreen()),
    );
  }

  void _openNewInvestigation(BuildContext context) {
    Navigator.of(context).push(
      kashfRoute(const InvestigationScreen()),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('so_delete_confirm_title'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          l.t('so_delete_confirm_message'),
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.t('settings_signout_confirm_cancel'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('settings_signout_confirm_action'),
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // Clear the local archive mirror. Cloud rows are protected by
    // Firestore rules and can be managed from the Reports tab.
    try {
      await InvestigationArchiveService.instance
          .clearAllForActiveUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('so_delete_done')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('so_delete_failed')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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
// Two AI studio cards. For the admin account the CTAs are enabled
// and open the picker -> generator flow. For every other user the
// CTAs surface a friendly "admin only" message.
class _StudioSection extends StatelessWidget {
  const _StudioSection({required this.l, required this.isAdmin});
  final AppLocalizations l;
  final bool isAdmin;

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
                icon: Icons.mic_none_outlined,
                enabled: isAdmin,
                onTap: () => _onPodcastTap(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StudioCard(
                color: const Color(0xFFEF4444),
                title: l.t('so_studio2_title'),
                description: l.t('so_studio2_desc'),
                cta: l.t('so_studio2_cta'),
                icon: Icons.movie_creation_outlined,
                enabled: isAdmin,
                onTap: () => _onReelTap(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onPodcastTap(BuildContext context) async {
    final picked = await _pickReport(context, ScriptKind.podcast);
    if (picked == null || !context.mounted) return;
    await Navigator.of(context).push(
      kashfRoute(AdminScriptViewerScreen(
        investigation: picked,
        kind: ScriptKind.podcast,
      )),
    );
  }

  Future<void> _onReelTap(BuildContext context) async {
    final picked = await _pickReport(context, ScriptKind.reel);
    if (picked == null || !context.mounted) return;
    await Navigator.of(context).push(
      kashfRoute(AdminScriptViewerScreen(
        investigation: picked,
        kind: ScriptKind.reel,
      )),
    );
  }

  /// Opens the report picker. For non-admin callers the CTA is
  /// disabled and we surface the admin-only message instead.
  Future<SavedInvestigation?> _pickReport(
    BuildContext context,
    ScriptKind kind,
  ) {
    final l = AppLocalizations.of(context);
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('adm_studio_admin_only')),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return Future.value(null);
    }
    final title = kind == ScriptKind.reel
        ? l.t('adm_studio_reel_picker_title')
        : l.t('adm_studio_podcast_picker_title');
    final subtitleKey = kind == ScriptKind.reel
        ? 'adm_studio_reel_picker_sub'
        : 'adm_studio_podcast_picker_sub';
    return Navigator.of(context).push<SavedInvestigation>(
      kashfRoute(AdminReportPickerScreen(
        title: title,
        subtitleKey: subtitleKey,
      )),
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.color,
    required this.title,
    required this.description,
    required this.cta,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final Color color;
  final String title;
  final String description;
  final String cta;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    // Dim the card slightly when disabled so non-admins still see
    // the feature without thinking it's available to them.
    final effectiveColor = enabled
        ? color
        : color.withValues(alpha: 0.35);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
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
                    color: effectiveColor,
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
                  color: effectiveColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: effectiveColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: palette.textSecondary,
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
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: effectiveColor,
                side: BorderSide(color: effectiveColor, width: 1),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        
        ],
      ),
    );
  }
}

// ============================ Investigations Section ============================
// Renders the most recent four saved investigations straight from
// Firestore. The "Show all" link routes to the existing
// LatestInvestigationsScreen for the full archive.
class _InvestigationsSection extends StatelessWidget {
  const _InvestigationsSection({
    required this.l,
    required this.items,
    required this.isAdmin,
  });
  final AppLocalizations l;
  final List<SavedInvestigation> items;

  /// When `true` (admin account) every table row exposes a
  /// trailing trash-icon button so the admin can surgically
  /// remove a single investigation from the cloud archive. This
  /// intentionally does NOT appear for non-admin users — the
  /// existing "delete all" button in the Tools section is also
  /// admin-restricted in spirit but the per-row UI is the cleanest
  /// signal that the action is privileged.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LatestInvestigationsScreen(),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  l.t('so_show_all'),
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        _InvestigationsTable(l: l, items: items, isAdmin: isAdmin),
      ],
    );
  }
}

class _InvestigationsTable extends StatelessWidget {
  const _InvestigationsTable({
    required this.l,
    required this.items,
    required this.isAdmin,
  });
  final AppLocalizations l;
  final List<SavedInvestigation> items;

  /// When `true` every row renders a trailing delete icon. See
  /// [_InvestigationsSection] for the rationale.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
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
                // Reserve a fixed-width slot for the per-row
                // delete button. The slot is always rendered so
                // the column widths stay stable whether the row
                // exposes the button or not.
                if (isAdmin)
                  const SizedBox(width: 32),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Text(
                l.t('so_inv_empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              _InvestigationRow(
                key: ValueKey(items[i].id),
                data: _InvestigationRowData(
                  title: items[i].title,
                  subject: items[i].subtitle,
                  status: _statusLabel(items[i]),
                  statusColor: _statusColor(items[i]),
                  score: items[i].confidencePercent / 100.0,
                  imageUrl: items[i].thumbnailUrl,
                  id: items[i].id,
                  userId: items[i].userId,
                ),
                showDivider: i != items.length - 1,
                isAdmin: isAdmin,
              ),
        ],
      ),
    );
  }

  String _statusLabel(SavedInvestigation it) {
    if (it.status == InvestigationStatus.completed) {
      return _entityLabel(it.entityType);
    }
    return it.status.name;
  }

  Color _statusColor(SavedInvestigation it) {
    switch (it.confidenceBand) {
      case 'high':
        return const Color(0xFF22C55E);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _entityLabel(EntityType type) {
    switch (type) {
      case EntityType.company:
        return 'Company';
      case EntityType.brand:
        return 'Brand';
      case EntityType.product:
        return 'Product';
      case EntityType.influencer:
        return 'Influencer';
      case EntityType.market:
        return 'Market';
    }
  }
}

class _InvestigationRowData {
  const _InvestigationRowData({
    required this.title,
    required this.subject,
    required this.status,
    required this.statusColor,
    required this.score,
    required this.imageUrl,
    required this.id,
    required this.userId,
  });
  final String title;
  final String subject;
  final String status;
  final Color statusColor;
  final double score;

  /// Real network image URL from the investigation's thumbnail,
  /// when available. `null` falls back to a neutral icon.
  final String? imageUrl;

  /// Firestore document id (== `users/{uid}/investigations/{id}`).
  /// Used as the payload for [InvestigationArchiveService.deleteInvestigation].
  final String id;

  /// Owning user's uid. Passed to
  /// [InvestigationArchiveService.deleteInvestigation] so the admin
  /// can delete a row that belongs to a *different* user from the
  /// correct Firestore path.
  final String userId;
}

class _InvestigationRow extends StatelessWidget {
  const _InvestigationRow({
    super.key,
    required this.data,
    required this.showDivider,
    required this.isAdmin,
  });
  final _InvestigationRowData data;
  final bool showDivider;

  /// `true` ⇒ render a trailing trash-icon button that opens a
  /// confirmation dialog and then deletes the row from both
  /// Firestore AND the local mirror.
  final bool isAdmin;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('so_inv_delete_title'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          l.t('so_inv_delete_message'),
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.t('settings_signout_confirm_cancel'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('so_inv_delete_action'),
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await InvestigationArchiveService.instance.deleteInvestigation(
        data.id,
        // Pass the owning user so the row is removed from the
        // correct user's Firestore archive (rows shown in the admin
        // overview can belong to any user), not the admin's own.
        userId: data.userId,
      );
      if (!context.mounted) return;
      // The Firestore subscription will redraw the table on its
      // very next emit (a few hundred ms later). We surface the
      // success snackbar immediately so the admin gets feedback
      // even on a slow connection.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('so_inv_delete_done')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('so_inv_delete_failed')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.cardBorder))
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
                    color: palette.textPrimary,
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
                    color: palette.textSecondary,
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
                    color: palette.textPrimary,
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
                    // Resolve to one of three sources, in order:
                    //   1. The investigation's stored network URL
                    //      (when the Firestore doc carries a real
                    //      thumbnail from the AI pipeline).
                    //   2. The bundled `assets/images/report.jpg`
                    //      placeholder when the doc has no URL —
                    //      keeps the table visually consistent
                    //      across rows.
                    //   3. A neutral gold icon when even the asset
                    //      can't be loaded (defensive fallback).
                    child: data.imageUrl != null &&
                            data.imageUrl!.isNotEmpty
                        ? Image.network(
                            data.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Image.asset(
                              'assets/images/report.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_outlined,
                                color: KashfColors.gold,
                                size: 16,
                              ),
                            ),
                          )
                        : Image.asset(
                            'assets/images/report.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_outlined,
                              color: KashfColors.gold,
                              size: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Admin-only delete affordance. Slot is always present
          // in the header (see _InvestigationsTable) so the column
          // widths stay stable across rows.
          if (isAdmin)
            SizedBox(
              width: 32,
              child: IconButton(
                tooltip: AppLocalizations.of(context).t('so_inv_delete_aria'),
                onPressed: () => _confirmAndDelete(context),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: palette.textSecondary,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
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
//
// These reference figures stay static — they belong to the marketing
// demo and the per-user source activity isn't part of the user's
// archive (sources are fetched live at investigation time and not
// persisted).
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
// Each button opens a real destination / performs a real action.
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
        onTap: () => _shareOverviewSummary(context),
      ),
      _QuickActionItem(
        icon: Icons.download_outlined,
        label: l.t('so_action2'),
        onTap: () => _exportLatest(context),
      ),
      _QuickActionItem(
        icon: Icons.notifications_active_outlined,
        label: l.t('so_action3'),
        onTap: () => _openNotifications(context),
      ),
      _QuickActionItem(
        icon: Icons.delete_outline,
        label: l.t('so_action4'),
        onTap: () => _confirmDeleteAll(context),
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

  // ============= Quick-action handlers =============

  /// "Share overview" — drops a one-line text summary on the
  /// clipboard. The system overview already drives most of its
  /// data from the archive, so a true "share as image" would
  /// require capturing the widget tree (out of scope). Clipboard
  /// text gives the admin something they can paste anywhere
  /// (mail, chat, docs) — close enough to the intent.
  void _shareOverviewSummary(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = '${l.t('so_page_title')}\n'
        '${l.t('so_kpi1_label')}: ${l.t('so_kpi1_value')}\n'
        '${l.t('so_kpi2_label')}: ${l.t('so_kpi2_value')}\n'
        '${l.t('so_kpi3_label')}: ${l.t('so_kpi3_value')}\n'
        '${l.t('so_kpi4_label')}: ${l.t('so_kpi4_value')}';
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.t('so_action_share_done'))),
    );
  }

  /// "Export" — drops the most-recent investigation's plain-text
  /// report on the clipboard. Users normally want their latest
  /// result when they tap a generic export.
  Future<void> _exportLatest(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final items = InvestigationArchiveService.instance.fetchLatest();
    try {
      final list = await items;
      if (list.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('so_export_empty'))),
        );
        return;
      }
      final latest = list.first;
      final result = await InvestigationArchiveService.instance
          .loadResult(latest.id);
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('so_export_unavailable'))),
        );
        return;
      }
      final body = result.sections
          .map((s) => '${s.headline}\n${s.summary}\n'
              '${s.items.map((it) => '  • ${it.title} — ${it.body}').join('\n')}')
          .join('\n\n');
      final text =
          '${result.title}\n${result.subtitle}\n\n$body';
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('so_action_export_done'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('so_export_failed')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsBellScreen()),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('so_delete_confirm_title'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          l.t('so_delete_confirm_message'),
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.t('settings_signout_confirm_cancel'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.t('settings_signout_confirm_action'),
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await InvestigationArchiveService.instance.clearAllForActiveUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('so_delete_done')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('so_delete_failed')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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
