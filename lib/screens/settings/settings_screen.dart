import 'package:flutter/material.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/theme_controller.dart';
import '../../l10n/theme_scope.dart';
import '../../theme.dart';

/// MVP settings — profile card, two grouped sections (General / More),
/// AI provider config, language, and a sign-out action. Mirrors the
/// marketing reference layout.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeCtrl = LocaleScope.of(context);
    final themeCtrl = ThemeScope.of(context);

    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(child: _Header(l: l)),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              sliver: SliverToBoxAdapter(child: _ProfileCard(l: l)),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: l.t('settings_section_general'),
                  alignStart: false,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _SectionGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_account'),
                      subtitle: l.t('settings_account_sub'),
                      onTap: () => _showComingSoon(context),
                    ),
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: Color(0xFF22C55E),
                      title: l.t('settings_security'),
                      subtitle: l.t('settings_security_sub'),
                      onTap: () => _showComingSoon(context),
                    ),
                    _SettingsTile(
                      icon: Icons.language_outlined,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_language'),
                      subtitle: l.t('settings_language_sub'),
                      trailing: _GoldBadge(
                        text: localeCtrl.language.nativeName,
                      ),
                      onTap: () => _showLanguageSheet(context),
                    ),
                    _SettingsTile(
                      icon: Icons.brightness_6_outlined,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_theme'),
                      subtitle: l.t('settings_theme_sub'),
                      trailing: _GoldBadge(
                        text: _themeLabel(l, themeCtrl.mode),
                      ),
                      onTap: () => _showThemeSheet(context),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: l.t('settings_section_more'),
                  alignStart: false,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                child: _SectionGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_help'),
                      subtitle: l.t('settings_help_sub'),
                      onTap: () => _showComingSoon(context),
                    ),
                    _SettingsTile(
                      icon: Icons.menu_book_outlined,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_privacy'),
                      subtitle: l.t('settings_privacy_sub'),
                      onTap: () => _showComingSoon(context),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      iconColor: KashfColors.gold,
                      title: l.t('settings_about'),
                      subtitle: l.t('settings_about_sub'),
                      onTap: () => _showComingSoon(context),
                    ),
                    _SettingsTile(
                      icon: Icons.logout,
                      iconColor: Color(0xFFEF4444),
                      title: l.t('settings_signout'),
                      subtitle: l.t('settings_about_version'),
                      onTap: () => _showComingSoon(context),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('settings_coming_soon')),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final localeCtrl = LocaleScope.of(context);
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('settings_language'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                for (final lang in AppLanguage.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.translate, color: KashfColors.gold),
                    title: Text(
                      lang.nativeName,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      lang.englishName,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    trailing: localeCtrl.language == lang
                        ? Icon(Icons.check_circle, color: KashfColors.gold)
                        : null,
                    onTap: () {
                      localeCtrl.setLanguage(lang);
                      Navigator.pop(sheetCtx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeLabel(AppLocalizations l, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return l.t('settings_theme_dark');
      case AppThemeMode.light:
        return l.t('settings_theme_light');
      case AppThemeMode.main:
        return l.t('settings_theme_main');
    }
  }

  void _showThemeSheet(BuildContext context) {
    final themeCtrl = ThemeScope.of(context);
    final l = AppLocalizations.of(context);
    final themes = <_ThemeOption>[
      _ThemeOption(
        AppThemeMode.dark,
        Icons.dark_mode_outlined,
        l.t('settings_theme_dark'),
        l.t('settings_theme_dark_sub'),
        KashfPalette.dark,
      ),
      _ThemeOption(
        AppThemeMode.light,
        Icons.light_mode_outlined,
        l.t('settings_theme_light'),
        l.t('settings_theme_light_sub'),
        KashfPalette.light,
      ),
      _ThemeOption(
        AppThemeMode.main,
        Icons.palette_outlined,
        l.t('settings_theme_main'),
        l.t('settings_theme_main_sub'),
        KashfPalette.main,
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('settings_theme_picker'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                for (final t in themes) ...[
                  _ThemeOptionTile(
                    option: t,
                    selected: themeCtrl.mode == t.mode,
                    onTap: () {
                      themeCtrl.setMode(t.mode);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeOption {
  const _ThemeOption(
    this.mode,
    this.icon,
    this.label,
    this.subtitle,
    this.palette,
  );
  final AppThemeMode mode;
  final IconData icon;
  final String label;
  final String subtitle;
  final KashfPalette palette;
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? KashfColors.gold
                  : KashfPalette.active.cardBorder,
              width: selected ? 1.4 : 1,
            ),
            color: KashfPalette.active.fieldFill,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: option.palette.cardBorder),
                ),
                child: Icon(
                  option.icon,
                  color: option.palette.textPrimary,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: KashfColors.gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Header =====================
class _Header extends StatelessWidget {
  const _Header({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: l.isRtl
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          l.t('settings_title'),
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          l.t('settings_subtitle'),
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ===================== Profile Card =====================
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KashfColors.gold.withValues(alpha: 0.18),
                  border: Border.all(color: KashfColors.gold, width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logoprofile.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person,
                    color: KashfColors.gold,
                    size: 30,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: KashfColors.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.business_center,
                    color: Colors.black,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: l.isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('home_user_name'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  l.t('settings_profile_email'),
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          DirectionalChevron(
            color: KashfPalette.active.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ===================== Section Header =====================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.alignStart});
  final String title;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: alignStart ? TextAlign.start : TextAlign.end,
      style: TextStyle(
        color: KashfPalette.active.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ===================== Section Group =====================
class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                color: KashfPalette.active.divider,
                indent: 56,
              ),
          ],
        ],
      ),
    );
  }
}

// ===================== Settings Tile =====================
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: 8), trailing!],
              SizedBox(width: 8),
              DirectionalChevron(
                color: KashfPalette.active.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Gold Badge =====================
class _GoldBadge extends StatelessWidget {
  const _GoldBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: KashfColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: KashfColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
