import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/theme_controller.dart';
import '../../l10n/theme_scope.dart';
import '../../l10n/user_profile_controller.dart';
import '../../l10n/user_profile_scope.dart';
import '../../theme.dart';
import '../../widgets/user_avatar.dart';
import '../system_overview/system_overview_screen.dart';
import 'info_sheet.dart';
import 'personal_info_screen.dart';

/// Settings screen replicated exactly from the reference image.
/// All colors, spacing, typography, and icons match the design spec.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeCtrl = LocaleScope.of(context);
    final themeCtrl = ThemeScope.of(context);

    return AnimatedBuilder(
      animation: themeCtrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: KashfPalette.active.background,
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
                    child: _buildSectionTitle(
                      l.t('settings_section_personalize'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: _buildPersonalizationSection(
                      l,
                      localeCtrl,
                      themeCtrl,
                    ),
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
      },
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
            color: KashfPalette.active.surfaceLight,
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
                color: KashfPalette.active.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.t('settings_subtitle'),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===================== Profile Card =====================
  Widget _buildProfileCard(AppLocalizations l) {
    final profile = UserProfileScope.of(context).profile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.of(context).push(kashfRoute(const PersonalInfoScreen())),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Row(
            children: [
              // Avatar (image / colored initial / default "K").
              UserAvatar(
                profile: profile,
                size: 52,
                borderColor: Color(0xFFD4A33A),
                borderWidth: 1.4,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name.isEmpty
                                ? l.t('app_title_root')
                                : profile.name,
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
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
                      profile.email.isEmpty
                          ? 'kashf+user@kashf.com'
                          : profile.email,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              Icon(
                Icons.chevron_right,
                color: KashfPalette.active.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Section Title =====================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: KashfPalette.active.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ===================== Account Section =====================
  Widget _buildAccountSection(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.person_outline,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_account_personal'),
            subtitle: l.t('settings_account_personal_sub'),
            onTap: () => Navigator.of(
              context,
            ).push(kashfRoute(const PersonalInfoScreen())),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.shield_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_security'),
            subtitle: l.t('settings_security_sub'),
            onTap: () => _showSecuritySheet(context),
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
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.dashboard_customize_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_system_overview'),
            subtitle: l.t('settings_system_overview_sub'),
            onTap: () => Navigator.of(
              context,
            ).push(kashfRoute(const SystemOverviewScreen())),
          ),
          _buildDivider(),
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
            onTap: () => _showSearchPrefsSheet(context),
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
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.help_outline,
            iconColor: Color(0xFF42A5F5),
            title: l.t('settings_help'),
            subtitle: l.t('settings_help_sub'),
            onTap: () => _showHelpSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.chat_bubble_outline,
            iconColor: Color(0xFF4CAF50),
            title: l.t('settings_support'),
            subtitle: l.t('settings_support_sub'),
            onTap: () => _showTechSupportSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.description_outlined,
            iconColor: Color(0xFFF5A623),
            title: l.t('settings_feedback'),
            subtitle: l.t('settings_feedback_sub'),
            onTap: () => _showFeedbackSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.info_outline,
            iconColor: Color(0xFF9E9E9E),
            title: l.t('settings_about'),
            subtitle: l.t('settings_about_version'),
            onTap: () => _showAboutSheet(context),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: Color(0xFFD4A33A),
            title: l.t('settings_privacy_policy'),
            subtitle: l.t('settings_privacy_policy_sub'),
            onTap: () => _showPrivacySheet(context),
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
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: _buildTile(
        icon: Icons.logout,
        iconColor: Color(0xFFE53935),
        title: l.t('settings_signout'),
        subtitle: l.t('settings_signout_sub'),
        onTap: _handleSignOut,
        showDivider: false,
        titleColor: Color(0xFFE53935),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final l = AppLocalizations.of(context);
    if (_isSigningOut) return;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: KashfPalette.active.surface,
        title: Text(
          l.t('settings_signout_confirm_title'),
          style: TextStyle(color: KashfPalette.active.textPrimary),
        ),
        content: Text(
          l.t('settings_signout_confirm_message'),
          style: TextStyle(color: KashfPalette.active.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.t('settings_signout_confirm_cancel'),
              style: TextStyle(color: KashfPalette.active.textSecondary),
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
    if (shouldSignOut != true) return;
    if (!mounted) return;

    setState(() => _isSigningOut = true);
    try {
      // We deliberately do NOT call `AuthService().signOut()` here.
      // The user wants this button to act as an "exit app" action
      // while keeping their account signed in — next launch should
      // resume straight into the home shell.
      // ignore: discarded_futures
      SuccessPopup.show(
        context,
        title: l.t('settings_signout_success'),
        message: l.t('settings_signout_success_message'),
      );
      // Slight delay so the user sees the success popup before the
      // app exits.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await SystemNavigator.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('settings_signout_failed')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
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
                  color: KashfPalette.active.surfaceLight,
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
                        color: titleColor ?? KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: KashfPalette.active.textSecondary,
                size: 20,
              ),
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
      color: KashfPalette.active.divider,
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

  // ===================== Help Center =====================
  void _showHelpSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    InfoSheet.show(
      context,
      title: l.t('settings_help_title'),
      subtitle: l.t('settings_help_subtitle'),
      updatedLabel: l.t('settings_help_updated'),
      sections: [
        InfoSheetSection(
          title: l.t('settings_faq_how_title'),
          body: l.t('settings_faq_how_body'),
          icon: Icons.search,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('settings_faq_sources_title'),
          body: l.t('settings_faq_sources_body'),
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFF22C55E),
        ),
        InfoSheetSection(
          title: l.t('settings_faq_privacy_title'),
          body: l.t('settings_faq_privacy_body'),
          icon: Icons.lock_outline,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('settings_faq_export_title'),
          body: l.t('settings_faq_export_body'),
          icon: Icons.ios_share,
          iconColor: const Color(0xFFF5A623),
        ),
        InfoSheetSection(
          title: l.t('settings_faq_support_title'),
          body: l.t('settings_faq_support_body'),
          icon: Icons.chat_bubble_outline,
          iconColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  // ===================== Tech Support =====================
  void _showTechSupportSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    InfoSheet.show(
      context,
      title: l.t('settings_support'),
      subtitle: l.t('settings_support_sub'),
      updatedLabel: l.t('settings_help_updated'),
      sections: [
        InfoSheetSection(
          title: l.t('settings_faq_support_title'),
          body: l.t('settings_faq_support_body'),
          icon: Icons.support_agent,
          iconColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  // ===================== About =====================
  void _showAboutSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    InfoSheet.show(
      context,
      title: l.t('settings_about_title'),
      subtitle: l.t('settings_about_subtitle'),
      updatedLabel: l.t('settings_about_updated'),
      sections: [
        InfoSheetSection(
          title: l.t('settings_about_version_full'),
          body: l.t('settings_about_description'),
          icon: Icons.info_outline,
          iconColor: const Color(0xFF9E9E9E),
        ),
        InfoSheetSection(
          title: 'Noureddine Mellasse',
          body: l.t('settings_about_role_principal_engineer'),
          icon: Icons.phone_iphone,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: 'Zakaria Ferzazi',
          body: l.t('settings_about_role_design_engineer'),
          icon: Icons.dns_outlined,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('settings_about_developer'),
          body: l.t('settings_about_team_body'),
          icon: Icons.handshake_outlined,
          iconColor: const Color(0xFF4CAF50),
        ),
        InfoSheetSection(
          title: l.t('settings_about_terms'),
          body: l.t('settings_about_terms_body'),
          icon: Icons.article_outlined,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('settings_about_licenses'),
          body: l.t('settings_about_licenses_body'),
          icon: Icons.gavel_outlined,
          iconColor: const Color(0xFFF5A623),
        ),
      ],
    );
  }

  // ===================== Feedback =====================
  void _showFeedbackSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FeedbackForm(ctx: ctx, l: l),
    );
  }

  // ===================== Security & Privacy Popups =====================
  // Both show as bottom-sheet popups (drag to dismiss) instead of full
  // screen routes — keeping the user anchored to Settings.
  void _showSecuritySheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    InfoSheet.show(
      context,
      title: l.t('security_sheet_title'),
      subtitle: l.t('security_sheet_subtitle'),
      updatedLabel: l.t('privacy_updated'),
      sections: [
        InfoSheetSection(
          title: l.t('security_password_title'),
          body: l.t('security_password_body'),
          icon: Icons.lock_outline,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('security_2fa_title'),
          body: l.t('security_2fa_body'),
          icon: Icons.verified_user_outlined,
          iconColor: const Color(0xFF22C55E),
        ),
        InfoSheetSection(
          title: l.t('security_history_title'),
          body: l.t('security_history_body'),
          icon: Icons.history,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('security_biometric_title'),
          body: l.t('security_biometric_body'),
          icon: Icons.fingerprint,
          iconColor: const Color(0xFF8B5CF6),
        ),
        InfoSheetSection(
          title: l.t('security_trusted_title'),
          body: l.t('security_trusted_body'),
          icon: Icons.devices_other,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('security_encryption_title'),
          body: l.t('security_encryption_body'),
          icon: Icons.enhanced_encryption_outlined,
          iconColor: const Color(0xFF22C55E),
        ),
        InfoSheetSection(
          title: l.t('security_alerts_title'),
          body: l.t('security_alerts_body'),
          icon: Icons.notifications_active_outlined,
          iconColor: const Color(0xFFEF4444),
        ),
        InfoSheetSection(
          title: l.t('security_report_title'),
          body: l.t('security_report_body'),
          icon: Icons.report_gmailerrorred_outlined,
          iconColor: const Color(0xFFF59E0B),
        ),
        InfoSheetSection(
          title: l.t('privacy_intro_title'),
          body: l.t('privacy_intro_body'),
          icon: Icons.privacy_tip_outlined,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('privacy_collect_title'),
          body: l.t('privacy_collect_body'),
          icon: Icons.dataset_outlined,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('privacy_use_title'),
          body: l.t('privacy_use_body'),
          icon: Icons.tune,
          iconColor: const Color(0xFF22C55E),
        ),
        InfoSheetSection(
          title: l.t('privacy_share_title'),
          body: l.t('privacy_share_body'),
          icon: Icons.share_outlined,
          iconColor: const Color(0xFF8B5CF6),
        ),
        InfoSheetSection(
          title: l.t('privacy_storage_title'),
          body: l.t('privacy_storage_body'),
          icon: Icons.storage_outlined,
          iconColor: const Color(0xFFF59E0B),
        ),
        InfoSheetSection(
          title: l.t('privacy_rights_title'),
          body: l.t('privacy_rights_body'),
          icon: Icons.gavel_outlined,
          iconColor: const Color(0xFFEC4899),
        ),
        InfoSheetSection(
          title: l.t('privacy_contact_title'),
          body: l.t('privacy_contact_body'),
          icon: Icons.mail_outline,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('privacy_children_title'),
          body: l.t('privacy_children_body'),
          icon: Icons.child_care_outlined,
          iconColor: const Color(0xFFEC4899),
        ),
        InfoSheetSection(
          title: l.t('privacy_cookies_title'),
          body: l.t('privacy_cookies_body'),
          icon: Icons.cookie_outlined,
          iconColor: const Color(0xFFF59E0B),
        ),
        InfoSheetSection(
          title: l.t('privacy_international_title'),
          body: l.t('privacy_international_body'),
          icon: Icons.public,
          iconColor: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  void _showPrivacySheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    InfoSheet.show(
      context,
      title: l.t('privacy_sheet_title'),
      subtitle: l.t('settings_privacy_policy_sub'),
      updatedLabel: l.t('privacy_updated'),
      sections: [
        InfoSheetSection(
          title: l.t('privacy_intro_title'),
          body: l.t('privacy_intro_body'),
          icon: Icons.privacy_tip_outlined,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('privacy_collect_title'),
          body: l.t('privacy_collect_body'),
          icon: Icons.dataset_outlined,
          iconColor: const Color(0xFF42A5F5),
        ),
        InfoSheetSection(
          title: l.t('privacy_use_title'),
          body: l.t('privacy_use_body'),
          icon: Icons.tune,
          iconColor: const Color(0xFF22C55E),
        ),
        InfoSheetSection(
          title: l.t('privacy_share_title'),
          body: l.t('privacy_share_body'),
          icon: Icons.share_outlined,
          iconColor: const Color(0xFF8B5CF6),
        ),
        InfoSheetSection(
          title: l.t('privacy_storage_title'),
          body: l.t('privacy_storage_body'),
          icon: Icons.storage_outlined,
          iconColor: const Color(0xFFF59E0B),
        ),
        InfoSheetSection(
          title: l.t('privacy_rights_title'),
          body: l.t('privacy_rights_body'),
          icon: Icons.gavel_outlined,
          iconColor: const Color(0xFFEC4899),
        ),
        InfoSheetSection(
          title: l.t('privacy_security_title'),
          body: l.t('privacy_security_body'),
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFFD4A33A),
        ),
        InfoSheetSection(
          title: l.t('privacy_changes_title'),
          body: l.t('privacy_changes_body'),
          icon: Icons.update,
          iconColor: const Color(0xFF6B7280),
        ),
        InfoSheetSection(
          title: l.t('privacy_contact_title'),
          body: l.t('privacy_contact_body'),
          icon: Icons.mail_outline,
          iconColor: const Color(0xFF42A5F5),
        ),
      ],
    );
  }

  // ===================== Search Preferences Sheet =====================
  // Lets the user pick which sources, filters, and limits KASHF
  // uses by default when running investigations. Choices are kept
  // locally via `_SearchPrefsState` — they live for the current
  // session; a real backend persistence layer would replace this.
  void _showSearchPrefsSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return _SearchPrefsSheet(sheetCtx: sheetCtx, l: l);
      },
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
                const SizedBox(height: 12),
                for (final lang in AppLanguage.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.translate, color: Color(0xFFD4A33A)),
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
        KashfPalette.light.surface,
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
                const SizedBox(height: 12),
                for (final t in themes) ...[
                  _ThemeOptionTile(
                    option: t,
                    selected: themeCtrl.mode == t.mode,
                    onTap: () {
                      // Pop the sheet *first* so the user sees the
                      // theme change on the underlying screens
                      // immediately, instead of waiting for the pop
                      // animation to finish before the rebuild happens.
                      Navigator.pop(sheetCtx);
                      themeCtrl.setMode(t.mode);
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
              color: selected
                  ? Color(0xFFD4A33A)
                  : KashfPalette.active.cardBorder,
              width: selected ? 1.4 : 1,
            ),
            color: KashfPalette.active.surfaceLight,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.previewColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(
                  option.icon,
                  // Always contrast against the swatch background:
                  // dark / main swatches are very dark → use a light
                  // icon; light swatch is white → use a dark icon.
                  color: option.mode == AppThemeMode.light
                      ? const Color(0xFF0F1116)
                      : const Color(0xFFF1E2B0),
                  size: 24,
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
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                Icon(Icons.check_circle, color: Color(0xFFD4A33A), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search preferences sheet. Lets the user toggle filters, safe
/// search, and language filtering, and pick how many results to
/// load per page. The choices live in this widget's local state
/// for now — wiring them to SharedPreferences / a backend is a
/// follow-up.
class _SearchPrefsSheet extends StatefulWidget {
  const _SearchPrefsSheet({required this.sheetCtx, required this.l});
  final BuildContext sheetCtx;
  final AppLocalizations l;

  @override
  State<_SearchPrefsSheet> createState() => _SearchPrefsSheetState();
}

class _SearchPrefsSheetState extends State<_SearchPrefsSheet> {
  bool _autoFilter = true;
  bool _safeSearch = true;
  bool _languageFilter = false;
  int _resultsCount = 20;

  void _bumpResults(int delta) {
    final next = (_resultsCount + delta).clamp(10, 50);
    setState(() => _resultsCount = next);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header.
                  Text(
                    l.t('settings_search_prefs_title'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.t('settings_search_prefs_subtitle'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Default sources.
                  _PrefsTile(
                    icon: Icons.source_outlined,
                    iconColor: const Color(0xFF4CAF50),
                    title: l.t('settings_search_sources'),
                    subtitle: l.t('settings_search_sources_sub'),
                    trailing: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF8B8B8B),
                      size: 22,
                    ),
                    onTap: () => _showSourcesSnack(),
                  ),
                  const Divider(color: Color(0xFF262626), height: 1),
                  // Auto-filter toggle.
                  _PrefsTile(
                    icon: Icons.filter_alt_outlined,
                    iconColor: const Color(0xFF42A5F5),
                    title: l.t('settings_search_filters'),
                    subtitle: l.t('settings_search_filters_sub'),
                    trailing: Switch(
                      value: _autoFilter,
                      onChanged: (v) => setState(() => _autoFilter = v),
                      activeColor: const Color(0xFFD4A33A),
                    ),
                  ),
                  const Divider(color: Color(0xFF262626), height: 1),
                  // Results per page stepper.
                  _PrefsTile(
                    icon: Icons.list_alt_outlined,
                    iconColor: const Color(0xFFF5A623),
                    title: l.t('settings_search_results_count'),
                    subtitle: l.t('settings_search_results_count_sub'),
                    trailing: _Stepper(
                      value: _resultsCount,
                      onMinus: _resultsCount > 10
                          ? () => _bumpResults(-5)
                          : null,
                      onPlus: _resultsCount < 50 ? () => _bumpResults(5) : null,
                    ),
                  ),
                  const Divider(color: Color(0xFF262626), height: 1),
                  // Safe search toggle.
                  _PrefsTile(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFFD4A33A),
                    title: l.t('settings_search_safe_search'),
                    subtitle: l.t('settings_search_safe_search_sub'),
                    trailing: Switch(
                      value: _safeSearch,
                      onChanged: (v) => setState(() => _safeSearch = v),
                      activeColor: const Color(0xFFD4A33A),
                    ),
                  ),
                  const Divider(color: Color(0xFF262626), height: 1),
                  // Language filter toggle.
                  _PrefsTile(
                    icon: Icons.translate_outlined,
                    iconColor: const Color(0xFF9C27B0),
                    title: l.t('settings_search_language_filter'),
                    subtitle: l.t('settings_search_language_filter_sub'),
                    trailing: Switch(
                      value: _languageFilter,
                      onChanged: (v) => setState(() => _languageFilter = v),
                      activeColor: const Color(0xFFD4A33A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save button.
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(widget.sheetCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.t('settings_search_saved')),
                            backgroundColor: const Color(0xFFD4A33A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A33A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l.t('settings_search_save'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSourcesSnack() {
    // Hook for a future "choose default sources" multi-select sheet.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.l.t('settings_search_sources')),
        backgroundColor: const Color(0xFF42A5F5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Row used inside [_SearchPrefsSheet]: icon + title/subtitle + a
/// trailing widget (switch, stepper, chevron).
class _PrefsTile extends StatelessWidget {
  const _PrefsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Small − / value / + stepper used for "Results per page".
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Color(0xFF8B8B8B)),
            onPressed: onMinus,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF8B8B8B)),
            onPressed: onPlus,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Feedback form sheet shown when the user taps "Send feedback" in
/// Settings. Has an optional email field and a required message field.
class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.ctx, required this.l});
  final BuildContext ctx;
  final AppLocalizations l;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_messageCtrl.text.trim().isEmpty) return;

    // TODO(developer): wire this to your backend / email service.
    // For now we just show the in-sheet confirmation and auto-close.
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _SentConfirmation(l: widget.l, ctx: widget.ctx);
    }

    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header.
                  Text(
                    widget.l.t('settings_feedback_title'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.l.t('settings_feedback_subtitle'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Prompt.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KashfPalette.active.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KashfPalette.active.cardBorder),
                    ),
                    child: Text(
                      widget.l.t('settings_feedback_prompt'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email field.
                  Text(
                    widget.l.t('settings_feedback_email_label'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.l.t('settings_feedback_email_hint'),
                      hintStyle: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: KashfPalette.active.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: KashfPalette.active.cardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: KashfPalette.active.cardBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD4A33A),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Message field.
                  Text(
                    widget.l.t('settings_feedback_message_label'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.l.t('settings_feedback_message_hint'),
                      hintStyle: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: KashfPalette.active.surface,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: KashfPalette.active.cardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: KashfPalette.active.cardBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD4A33A),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Send button.
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _send,
                      style: TextButton.styleFrom(
                        backgroundColor: Color(0xFFD4A33A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.l.t('settings_feedback_send'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown after the user taps send — a minimal confirmation that
/// auto-closes after 2 seconds.
class _SentConfirmation extends StatefulWidget {
  const _SentConfirmation({required this.l, required this.ctx});
  final AppLocalizations l;
  final BuildContext ctx;

  @override
  State<_SentConfirmation> createState() => _SentConfirmationState();
}

class _SentConfirmationState extends State<_SentConfirmation> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(widget.ctx).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 48, 20, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Color(0xFFD4A33A).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check,
                color: Color(0xFFD4A33A),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.l.t('settings_feedback_thanks'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
