import 'package:flutter/material.dart';

import '../../l10n/theme_scope.dart';
import '../../theme.dart';

/// Lightweight scaffold used by every settings sub-screen so they
/// all share the same header, padding and surface treatment.
///
/// The scaffold renders a top app bar with a localised title and a
/// back chevron. The body is left to the caller via [child].
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final String title;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so the AppBar surface color flips
    // in lock-step with the rest of the screen when the user picks
    // a different palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A reusable tile used to render a single setting row inside a
/// settings screen. Renders an icon, title, optional subtitle,
/// optional trailing control (switch, chevron, badge...) and a
/// subtle border that follows the active palette.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  /// Material icon shown inside a tinted circle on the leading
  /// edge. Keep these small — `size: 22` reads best.
  final IconData icon;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// When true the tile uses a destructive accent (red icon +
  /// title) so the user knows it's a destructive action.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    final accent = danger ? const Color(0xFFEF4444) : palette.textPrimary;
    final iconColor =
        danger ? const Color(0xFFEF4444) : palette.textPrimary;
    final tileColor = palette.surface;
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small "section header" used inside settings screens to group
/// related tiles (Account, Security, About…).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) {
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Convenience: localised snackbar that respects the active palette.
void showKashfSnackBar(BuildContext context, String message) {
  final palette = KashfPalette.active;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
      ),
      backgroundColor: palette.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.cardBorder),
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Convenience: localised error snackbar.
void showKashfErrorSnackBar(BuildContext context, String message) {
  final palette = KashfPalette.active;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: palette.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEF4444)),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
