import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
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

  void _openCreate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('home_fab_new')),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                      selected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                    ),
                    _Dest(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart,
                      label: l.t('nav_reports_lbl'),
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                    // Spacer for the centered FAB.
                    const SizedBox(width: 72),
                    _Dest(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore,
                      label: l.t('nav_explore_lbl'),
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    _Dest(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: l.t('nav_home_lbl'),
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                  ],
                ),
              ),
              // Centered gold "+" floating action button.
              Positioned(
                top: -14,
                child: GestureDetector(
                  onTap: () => _openCreate(context),
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
                    child: const Icon(Icons.add, color: Colors.black, size: 30),
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
