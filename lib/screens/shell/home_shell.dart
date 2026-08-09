import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/theme_controller.dart';
import '../../l10n/theme_scope.dart';
import '../../theme.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../investigation/investigation_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

/// The post-auth shell with bottom navigation. Layout mirrors the
/// marketing reference:
///   Settings | Reports |   (+) FAB   | Explore | Home
/// The center "+" is a rounded gold floating action button that
/// sits above the bar; the four corner items are regular nav
/// destinations.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = const [
    HomeScreen(),
    ExploreScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // The `Scaffold` body (IndexedStack of screens) does NOT need to
    // rebuild when the theme changes — each screen reads
    // `KashfPalette.active.*` directly and is rebuilt by the
    // `ThemeScope`'s `InheritedNotifier` when the controller notifies.
    // We only need to subscribe to the controller so the bottom-nav
    // bar updates instantly. We do that by wrapping just the
    // bottomNavigationBar in an `AnimatedBuilder` keyed to the
    // controller — this is cheap because the nav bar is a small
    // subtree, and avoids rebuilding the IndexedStack and all 4
    // screens.
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _ThemedBottomNav(
        controller: ThemeScope.of(context),
        index: _index,
        onIndexChanged: (i) => setState(() => _index = i),
        labels: _NavLabels(
          home: l.t('nav_home_lbl'),
          explore: l.t('nav_explore_lbl'),
          reports: l.t('nav_reports_lbl'),
          settings: l.t('nav_settings_lbl'),
        ),
      ),
    );
  }
}

class _NavLabels {
  const _NavLabels({
    required this.home,
    required this.explore,
    required this.reports,
    required this.settings,
  });
  final String home;
  final String explore;
  final String reports;
  final String settings;
}

/// Bottom navigation bar that listens to the theme controller and
/// rebuilds *only* itself — never the IndexedStack above it.
class _ThemedBottomNav extends StatelessWidget {
  const _ThemedBottomNav({
    required this.controller,
    required this.index,
    required this.onIndexChanged,
    required this.labels,
  });

  final ThemeController controller;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final _NavLabels labels;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SafeArea(
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
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: labels.home,
                        selected: index == 0,
                        onTap: () => onIndexChanged(0),
                      ),
                      _Dest(
                        icon: Icons.explore_outlined,
                        selectedIcon: Icons.explore,
                        label: labels.explore,
                        selected: index == 1,
                        onTap: () => onIndexChanged(1),
                      ),
                      // Spacer for the centered FAB.
                      const SizedBox(width: 72),
                      _Dest(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart,
                        label: labels.reports,
                        selected: index == 2,
                        onTap: () => onIndexChanged(2),
                      ),
                      _Dest(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: labels.settings,
                        selected: index == 3,
                        onTap: () => onIndexChanged(3),
                      ),
                    ],
                  ),
                ),
                // Centered gold "+" floating action button — opens the
                // "New Investigation" workspace so users can start a new
                // AI-powered investigation with smart search, evidence
                // upload, and quick actions.
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
        );
      },
    );
  }
}

/// One of the four nav destinations inside the pill. Visually the
/// selected item shows the brand-gold icon + label; the others
/// show a softer icon and dimmed text.
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
