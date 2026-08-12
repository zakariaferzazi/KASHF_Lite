import 'package:flutter/material.dart';
import 'package:kashf_lite/screens/settings/settings_scaffold.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/theme_controller.dart';
import '../../l10n/theme_scope.dart';
import '../../main.dart';
import '../../services/ai/ai_model_options.dart';
import '../../services/auth_service.dart';
import '../../services/news/news_models.dart';
import '../../services/settings_preferences.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import '../system_overview/system_overview_screen.dart';
import 'backup_screen.dart';
import 'contact_support_screen.dart';
import 'feedback_screen.dart';
import 'help_center_screen.dart';
import 'legal_document_dialog.dart';
import 'notifications_bell_screen.dart';
import 'notifications_screen.dart';
import 'personal_profile_screen.dart';
import 'security_screen.dart';

/// Settings hub. Every tile is wired up to a working screen or
/// dialog — nothing in this file is a demo placeholder.
///
/// The screen is fully theme-aware: it reads colors from the active
/// [KashfPalette] so the UI flips correctly between Dark, Light and
/// the brand Main theme without needing a rebuild at this level.
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
    final prefs = SettingsScope.of(context);
    final palette = KashfPalette.active;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([themeCtrl, prefs]),
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
                sliver: SliverToBoxAdapter(child: _buildHeader(l, palette)),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                sliver:
                    SliverToBoxAdapter(child: _buildProfileCard(l, palette)),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle(
                      l.t('settings_section_account'), palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: _buildAccountSection(l, palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle(
                      l.t('settings_section_personalize'), palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: _buildPersonalizationSection(
                      l, localeCtrl, themeCtrl, palette, prefs),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle(
                      l.t('settings_section_support'), palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: _buildSupportSection(l, palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildLegalTile(l, palette),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildLogoutTile(l, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Header =====================
  Widget _buildHeader(AppLocalizations l, KashfPalette palette) {
    final prefs = SettingsScope.of(context);
    final hasUnread =
        prefs.lastBellReadAt.isBefore(DateTime.now().subtract(
              const Duration(seconds: 30),
            ));
    final isRtl = l.isRtl;
    // For RTL: title on left, bell on right
    // For LTR: bell on left, title on right
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isRtl) ...[
          Expanded(
            child: Text(
              l.t('settings_title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildNotificationBell(palette, hasUnread),
        ] else ...[
          _buildNotificationBell(palette, hasUnread),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.t('settings_title'),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationBell(KashfPalette palette, bool hasUnread) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsBellScreen(),
                ),
              ),
              icon: Icon(
                Icons.notifications_none_outlined,
                color: KashfColors.gold,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          if (hasUnread)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: KashfColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===================== Profile Card =====================
  Widget _buildProfileCard(AppLocalizations l, KashfPalette palette) {
    final user = AuthService().currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? l.t('app_title_root'));
    final initial = name.characters.first.toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PersonalProfileScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceLight,
                  border: Border.all(color: palette.cardBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 12,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.t('settings_trusted_account'),
                            style: const TextStyle(
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
                color: palette.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Section Title =====================
  Widget _buildSectionTitle(String title, KashfPalette palette) {
    return Text(
      title,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ===================== Account Section =====================
  Widget _buildAccountSection(AppLocalizations l, KashfPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            palette: palette,
            icon: Icons.person_outline,
            iconColor: KashfColors.gold,
            title: l.t('settings_account_personal'),
            subtitle: l.t('settings_account_personal_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PersonalProfileScreen(),
              ),
            ),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.shield_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_security'),
            subtitle: l.t('settings_security_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SecurityScreen(),
              ),
            ),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.cloud_upload_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_backup'),
            subtitle: l.t('settings_backup_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BackupScreen(),
              ),
            ),
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
    KashfPalette palette,
    SettingsPreferences prefs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            palette: palette,
            icon: Icons.dashboard_customize_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_system_overview'),
            subtitle: l.t('settings_system_overview_sub'),
            onTap: () => Navigator.of(context).push(
              kashfRoute(const SystemOverviewScreen()),
            ),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.dark_mode_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_appearance'),
            subtitle: l.t('settings_appearance_sub'),
            onTap: () => _showThemeSheet(context),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.language_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_language'),
            subtitle: l.t('settings_language_sub'),
            trailing: _buildBadge(
              localeCtrl.language.nativeName,
              KashfColors.gold,
            ),
            onTap: () => _showLanguageSheet(context),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.tune,
            iconColor: const Color(0xFF4CAF50),
            title: l.t('settings_search_prefs'),
            subtitle: l.t('settings_search_prefs_sub'),
            trailing: _buildBadge(
              '${NewsTopic.values.length + prefs.customTopics.length}',
              KashfColors.gold,
            ),
            onTap: () => _showSearchPrefsSheet(context),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.auto_awesome,
            iconColor: KashfColors.gold,
            title: l.t('settings_ai_model_picker'),
            subtitle: l.t('settings_ai_model_picker_sub'),
            trailing: _buildBadge(
              prefs.aiModel.label,
              KashfColors.gold,
            ),
            onTap: () => _showAiModelSheet(context),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.notifications_none_outlined,
            iconColor: const Color(0xFF8E44AD),
            title: l.t('settings_notifications'),
            subtitle: l.t('settings_notifications_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ===================== AI Model Picker Sheet =====================
  // Bottom sheet that lets the user pick which OpenRouter model should
  // back every AI request in the app. The selected model is stored
  // via [SettingsPreferences.setAiModelId] and read at request time by
  // [OpenRouterConfig.model].
  void _showAiModelSheet(BuildContext context) {
    final prefs = SettingsScope.of(context);
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: AnimatedBuilder(
            animation: prefs,
            builder: (context, _) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('ai_model_picker_title'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.t('ai_model_picker_sub'),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final option in kAiModelOptions) ...[
                      _AiModelOptionTile(
                        option: option,
                        selected: prefs.aiModelId == option.id,
                        onTap: () async {
                          await prefs.setAiModelId(option.id);
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===================== News Topics Picker Sheet =====================
  // Bottom sheet that lists every news topic the app fetches from.
  // Built-in topics (Fashion / Beauty / Influencers / Fragrances) are
  // read-only; user-added topics get a delete affordance. An "Add
  // custom topic" tile at the bottom opens a small dialog.
  void _showSearchPrefsSheet(BuildContext context) {
    final prefs = SettingsScope.of(context);
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final isRtl = l.isRtl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: AnimatedBuilder(
            animation: prefs,
            builder: (context, _) {
              final builtIn = NewsTopic.values;
              final custom = prefs.customTopics;
              return Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('search_prefs_topics_header'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.t('search_prefs_topics_sub'),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final topic in builtIn) ...[
                              _TopicSheetTile(
                                label: isRtl ? topic.labelAr : topic.label,
                                subtitle: isRtl
                                    ? topic.queryAr
                                    : topic.queryEn,
                                removable: false,
                                palette: palette,
                                onRemove: null,
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (custom.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                l.t('search_prefs_topics_custom'),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (var i = 0; i < custom.length; i++) ...[
                                _TopicSheetTile(
                                  label: custom[i].label,
                                  subtitle: isRtl
                                      ? custom[i].queryAr
                                      : custom[i].queryEn,
                                  removable: true,
                                  palette: palette,
                                  onRemove: () =>
                                      prefs.removeCustomTopicAt(i),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddTopicDialog(context),
                        icon: const Icon(Icons.add,
                            color: KashfColors.gold, size: 18),
                        label: Text(
                          l.t('search_prefs_add_topic'),
                          style: const TextStyle(
                            color: KashfColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: KashfColors.gold),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===================== Add Topic Dialog =====================
  Future<void> _showAddTopicDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final result = await showDialog<_NewTopicFields>(
      context: context,
      builder: (ctx) => _AddTopicDialog(
        palette: palette,
        title: l.t('search_prefs_add_topic'),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final prefs = SettingsScope.of(context);
    await prefs.addCustomTopic(
      label: result.label,
      queryEn: result.queryEn,
      queryAr: result.queryAr,
    );
    if (!mounted) return;
    showKashfSnackBar(context, l.t('search_prefs_topic_added'));
  }

  // ===================== Support Section =====================
  Widget _buildSupportSection(AppLocalizations l, KashfPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            palette: palette,
            icon: Icons.help_outline,
            iconColor: const Color(0xFF42A5F5),
            title: l.t('settings_help'),
            subtitle: l.t('settings_help_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HelpCenterScreen(),
              ),
            ),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFF4CAF50),
            title: l.t('settings_support'),
            subtitle: l.t('settings_support_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ContactSupportScreen(),
              ),
            ),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.description_outlined,
            iconColor: const Color(0xFFF5A623),
            title: l.t('settings_feedback'),
            subtitle: l.t('settings_feedback_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FeedbackScreen(),
              ),
            ),
          ),
          _buildDivider(palette),
        ],
      ),
    );
  }

  // ===================== Privacy & Terms (separate group) =====================
  Widget _buildLegalTile(AppLocalizations l, KashfPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _buildTile(
            palette: palette,
            icon: Icons.privacy_tip_outlined,
            iconColor: KashfColors.gold,
            title: l.t('settings_privacy_action_privacy'),
            subtitle: l.t('settings_privacy_legal_sub'),
            onTap: () => LegalDocumentDialog.showPrivacy(context),
          ),
          _buildDivider(palette),
          _buildTile(
            palette: palette,
            icon: Icons.gavel_rounded,
            iconColor: KashfColors.gold,
            title: l.t('settings_privacy_action_terms'),
            subtitle: l.t('settings_privacy_legal_sub'),
            onTap: () => LegalDocumentDialog.showTerms(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ===================== Logout Tile =====================
  Widget _buildLogoutTile(AppLocalizations l, KashfPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935)),
      ),
      child: _buildTile(
        palette: palette,
        icon: Icons.logout,
        iconColor: const Color(0xFFE53935),
        title: l.t('settings_signout'),
        subtitle: l.t('settings_signout_sub'),
        onTap: _handleSignOut,
        showDivider: false,
        titleColor: const Color(0xFFE53935),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    if (_isSigningOut) return;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('settings_signout_confirm_title'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          l.t('settings_signout_confirm_message'),
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
    if (shouldSignOut != true) return;
    if (!mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      // Show the success popup on the root overlay (it survives the
      // navigation swap) so the user gets the same visual feedback as
      // sign-in / sign-up.
      // ignore: discarded_futures
      SuccessPopup.show(
        context,
        title: l.t('settings_signout_success'),
        message: l.t('settings_signout_success_message'),
      );
      // Safety net: explicitly push WelcomeScreen so the redirect is
      // guaranteed even if the auth gate's stream listener is slow.
      if (!mounted) return;
      navigateToWelcome(context);
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
    required KashfPalette palette,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: palette.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Divider =====================
  Widget _buildDivider(KashfPalette palette) {
    return Container(
      height: 1,
      color: palette.divider,
      margin: const EdgeInsets.only(left: 62),
    );
  }

  // ===================== Badge =====================
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  void _showLanguageSheet(BuildContext context) {
    final localeCtrl = LocaleScope.of(context);
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('settings_language'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final lang in AppLanguage.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.translate, color: KashfColors.gold),
                    title: Text(
                      lang.nativeName,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      lang.englishName,
                      style: TextStyle(
                        color: palette.textSecondary,
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

  void _showThemeSheet(BuildContext context) {
    final themeCtrl = ThemeScope.of(context);
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final themes = <_ThemeOption>[
      _ThemeOption(
        AppThemeMode.dark,
        Icons.dark_mode_outlined,
        l.t('settings_theme_dark'),
        l.t('settings_theme_dark_sub'),
        const Color(0xFF14151A),
      ),
      _ThemeOption(
        AppThemeMode.light,
        Icons.light_mode_outlined,
        l.t('settings_theme_light'),
        l.t('settings_theme_light_sub'),
        const Color(0xFFFFFFFF),
      ),
      _ThemeOption(
        AppThemeMode.main,
        Icons.palette_outlined,
        l.t('settings_theme_main'),
        l.t('settings_theme_main_sub'),
        const Color(0xFF0C0D14),
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('settings_theme_picker'),
                  style: TextStyle(
                    color: palette.textPrimary,
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
    final palette = KashfPalette.active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? KashfColors.gold : palette.cardBorder,
              width: selected ? 1.4 : 1,
            ),
            color: palette.surfaceLight,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.previewColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Icon(
                  option.icon,
                  color: option.mode == AppThemeMode.light
                      ? Colors.black
                      : palette.textPrimary,
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
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: KashfColors.gold,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}



// ===================== Topic Sheet Tile =====================
class _TopicSheetTile extends StatelessWidget {
  const _TopicSheetTile({
    required this.label,
    required this.subtitle,
    required this.removable,
    required this.palette,
    required this.onRemove,
  });
  final String label;
  final String subtitle;
  final bool removable;
  final KashfPalette palette;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.cardBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.tag_outlined,
              size: 16,
              color: KashfColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (removable && onRemove != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 18),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ===================== Add Topic Dialog =====================
class _NewTopicFields {
  const _NewTopicFields({
    required this.label,
    required this.queryEn,
    required this.queryAr,
  });
  final String label;
  final String queryEn;
  final String queryAr;
}

class _AddTopicDialog extends StatefulWidget {
  const _AddTopicDialog({required this.palette, required this.title});
  final KashfPalette palette;
  final String title;

  @override
  State<_AddTopicDialog> createState() => _AddTopicDialogState();
}

class _AddTopicDialogState extends State<_AddTopicDialog> {
  final _labelCtrl = TextEditingController();
  final _enCtrl = TextEditingController();
  final _arCtrl = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _labelCtrl.dispose();
    _enCtrl.dispose();
    _arCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    final en = _enCtrl.text.trim();
    final ar = _arCtrl.text.trim();
    if (label.isEmpty || en.isEmpty || ar.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    Navigator.pop(
      context,
      _NewTopicFields(label: label, queryEn: en, queryAr: ar),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _DialogField(
              controller: _labelCtrl,
              hint: 'Label (e.g. Sneakers)',
              palette: palette,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: _enCtrl,
              hint: 'English query (sneakers OR trainers)',
              palette: palette,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: _arCtrl,
              hint: 'Arabic query (أحذية_رياضية OR سنيكرز)',
              palette: palette,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KashfColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.hint,
    required this.palette,
  });
  final TextEditingController controller;
  final String hint;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.fieldBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Row in the AI model picker sheet. Visually mirrors
/// [_ThemeOptionTile] so both selection sheets feel like part of
/// the same family.
class _AiModelOptionTile extends StatelessWidget {
  const _AiModelOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final AiModelOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? KashfColors.gold : palette.cardBorder,
              width: selected ? 1.4 : 1,
            ),
            color: palette.surfaceLight,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? KashfColors.gold.withValues(alpha: 0.15)
                      : palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(
                  option.icon,
                  color: selected
                      ? KashfColors.gold
                      : palette.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.label,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: Text(
                            option.provider,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.t(option.subtitleL10nKey),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: KashfColors.gold,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
