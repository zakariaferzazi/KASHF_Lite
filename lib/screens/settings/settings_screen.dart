import 'package:flutter/material.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/theme_controller.dart';
import '../../l10n/theme_scope.dart';

/// Settings screen replicated exactly from the reference image.
/// All colors, spacing, typography, and icons match the design spec.
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
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Header: bell icon + title/subtitle
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
              sliver: SliverToBoxAdapter(child: _buildHeader(l)),
            ),
            // Profile Card
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(child: _buildProfileCard(l)),
            ),
            // Account Section
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _buildSectionTitle(l.t('settings_section_account')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(child: _buildAccountSection(l)),
            ),
            // Personalization Section
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _buildSectionTitle(l.t('settings_section_personalize')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: _buildPersonalizationSection(l, localeCtrl, themeCtrl),
              ),
            ),
            // Support Section
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _buildSectionTitle(l.t('settings_section_support')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(child: _buildSupportSection(l)),
            ),
            // Logout
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(child: _buildLogoutTile(l)),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== Header =====================
  Widget _buildHeader(AppLocalizations l) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Bell icon with badge
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: IconButton(
                  onPressed: () => _showComingSoon(context),
                  icon: Icon(
                    Icons.notifications_none_outlined,
                    color: Color(0xFFD4A33A),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(0xFFD4A33A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l.t('settings_title'),
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.t('settings_subtitle'),
              style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // ===================== Profile Card =====================
  Widget _buildProfileCard(AppLocalizations l) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF262626)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1A1A1F),
            ),
            alignment: Alignment.center,
            child: Text(
              'K',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.t('app_title_root'),
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFD4A33A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lite',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'kashf+user@kashf.com',
                  style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 12,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.t('settings_trusted_account'),
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Color(0xFF7A7A7A), size: 20),
        ],
      ),
    );
  }

  // ===================== Section Title =====================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ===================== Account Section =====================
  Widget _buildAccountSection(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.person_outline,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_account_personal'),
            subtitle: l.t('settings_account_personal_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.shield_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_security'),
            subtitle: l.t('settings_security_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.cloud_upload_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_backup'),
            subtitle: l.t('settings_backup_sub'),
            onTap: () => _showComingSoon(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ===================== Personalization Section =====================
  Widget _buildPersonalizationSection(
    AppLocalizations l,
    LocaleController localeCtrl,
    ThemeController themeCtrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.dark_mode_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_appearance'),
            subtitle: l.t('settings_appearance_sub'),
            onTap: () => _showThemeSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.language_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_language'),
            subtitle: l.t('settings_language_sub'),
            trailing: _buildBadge(
              localeCtrl.language.nativeName,
              Color(0xFF22C55E),
            ),
            onTap: () => _showLanguageSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.tune,
            iconColor: Color(0xFF4CAF50),
            title: l.t('settings_search_prefs'),
            subtitle: l.t('settings_search_prefs_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.notifications_none_outlined,
            iconColor: Color(0xFF8E44AD),
            title: l.t('settings_notifications'),
            subtitle: l.t('settings_notifications_sub'),
            trailing: _buildBadge(
              _themeLabel(l, themeCtrl.mode),
              Color(0xFFD4A33A),
            ),
            onTap: () => _showComingSoon(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ===================== Support Section =====================
  Widget _buildSupportSection(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.help_outline,
            iconColor: Color(0xFF42A5F5),
            title: l.t('settings_help'),
            subtitle: l.t('settings_help_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.chat_bubble_outline,
            iconColor: Color(0xFF4CAF50),
            title: l.t('settings_support'),
            subtitle: l.t('settings_support_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.description_outlined,
            iconColor: Color(0xFFF5A623),
            title: l.t('settings_feedback'),
            subtitle: l.t('settings_feedback_sub'),
            onTap: () => _showComingSoon(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.info_outline,
            iconColor: Color(0xFF9E9E9E),
            title: l.t('settings_about'),
            subtitle: l.t('settings_about_version'),
            onTap: () => _showComingSoon(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ===================== Logout Tile =====================
  Widget _buildLogoutTile(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF262626)),
      ),
      child: _buildTile(
        icon: Icons.logout,
        iconColor: Color(0xFFE53935),
        title: l.t('settings_signout'),
        subtitle: l.t('settings_signout_sub'),
        onTap: () => _showComingSoon(context),
        showDivider: false,
        titleColor: Color(0xFFE53935),
      ),
    );
  }

  // ===================== Tile Widget =====================
  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool showDivider = true,
    Color? titleColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1F),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Color(0xFF7A7A7A), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Divider =====================
  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Color(0xFF262626),
      margin: EdgeInsets.only(left: 62),
    );
  }

  // ===================== Badge =====================
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ===================== Dialogs =====================
  void _showComingSoon(BuildContext context) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('settings_coming_soon')),
        backgroundColor: Color(0xFFD4A33A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final localeCtrl = LocaleScope.of(context);
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Color(0xFF15151C),
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
                    color: Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final lang in AppLanguage.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.translate, color: Color(0xFFD4A33A)),
                    title: Text(
                      lang.nativeName,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      lang.englishName,
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 11),
                    ),
                    trailing: localeCtrl.language == lang
                        ? Icon(Icons.check_circle, color: Color(0xFFD4A33A))
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
        Color(0xFF1A1A2E),
      ),
      _ThemeOption(
        AppThemeMode.light,
        Icons.light_mode_outlined,
        l.t('settings_theme_light'),
        l.t('settings_theme_light_sub'),
        Color(0xFFFFFFFF),
      ),
      _ThemeOption(
        AppThemeMode.main,
        Icons.palette_outlined,
        l.t('settings_theme_main'),
        l.t('settings_theme_main_sub'),
        Color(0xFF0C0D14),
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Color(0xFF15151C),
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
                    color: Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final t in themes) ...[
                  _ThemeOptionTile(
                    option: t,
                    selected: themeCtrl.mode == t.mode,
                    onTap: () {
                      themeCtrl.setMode(t.mode);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  const SizedBox(height: 8),
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
    this.previewColor,
  );
  final AppThemeMode mode;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color previewColor;
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
              color: selected ? Color(0xFFD4A33A) : Color(0xFF262626),
              width: selected ? 1.4 : 1,
            ),
            color: Color(0xFF1A1A1F),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.previewColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFF262626)),
                ),
                child: Icon(
                  option.icon,
                  color: option.mode == AppThemeMode.light
                      ? Colors.black
                      : Color(0xFFFFFFFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(color: Color(0xFF8B8B8B), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: Color(0xFFD4A33A), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
